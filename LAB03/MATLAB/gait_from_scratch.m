%% ---------------- IO & param ----------------
in_csv = 'walk1.csv';
out_mat = 'walk1.mat';

Fs  = 50;                 % [Hz]
fc_acc = 5;               % [Hz] LPF for accelerometer ([] to skip)
fc_gyr = 10;              % [Hz] LPF for gyroscope ([] to skip)
ord = 4;

% Units (raw int16 -> SI)
acc_lsb_to_ms2 = 9.80665 / 16384;     % m/s^2 per LSB  (±2 g range)
gyr_lsb_to_rps = (pi/180) / 131;      % rad/s per LSB  (±250 dps range)
g0 = 9.80665;                         % gravity


%% --------------- Load & map columns ---------------
if ~isfile(in_csv), error('File not found: %s', in_csv); end
T = readtable(in_csv);

findCol = @(cands) local_find_col(T.Properties.VariableNames, cands);
ix_ax = findCol({'accx','acc_x','ax'});
ix_ay = findCol({'accy','acc_y','ay'});
ix_az = findCol({'accz','acc_z','az'});
ix_gx = findCol({'gyrx','gyro_x','gx'});
ix_gy = findCol({'gyry','gyro_y','gy'});
ix_gz = findCol({'gyrz','gyro_z','gz'});
need = [ix_ax ix_ay ix_az ix_gx ix_gy ix_gz];
if any(isnan(need))
    error('Missing IMU columns. Present: %s', strjoin(T.Properties.VariableNames, ', '));
end

Xraw = double([T{:,ix_ax}, T{:,ix_ay}, T{:,ix_az}, T{:,ix_gx}, T{:,ix_gy}, T{:,ix_gz}]);
N = size(Xraw,1); t = (0:N-1)'/Fs;

% Scale to SI (body frame)
accB = Xraw(:,1:3) * acc_lsb_to_ms2;      % m/s^2
gyrB = Xraw(:,4:6) * gyr_lsb_to_rps;      % rad/s

%% --------------- Orientation (Mahony-like) ---------------
% Params
Kp = 2.0;              % proportional tilt gain
Ki = 0.05;             % integral gain for gyro bias (optional)
dt = 1/Fs;

% State
q = [1;0;0;0];         % unit quaternion, body->earth (earth Z-up)
bias = [0;0;0];        % gyro bias estimate
I3 = eye(3);

% Helpers
qmul = @(q1,q2)[ q1(1)*q2(1)-dot(q1(2:4),q2(2:4));
                 q1(1)*q2(2:4)+q2(1)*q1(2:4)+cross(q1(2:4),q2(2:4)) ];
q2R = @(q)[ 1-2*(q(3)^2+q(4)^2), 2*(q(2)*q(3)-q(1)*q(4)), 2*(q(2)*q(4)+q(1)*q(3));
            2*(q(2)*q(3)+q(1)*q(4)), 1-2*(q(2)^2+q(4)^2), 2*(q(3)*q(4)-q(1)*q(2));
            2*(q(2)*q(4)-q(1)*q(3)), 2*(q(3)*q(4)+q(1)*q(2)), 1-2*(q(2)^2+q(3)^2) ];
normalize = @(v) v./max(norm(v),1e-12);

Q = zeros(4,N);  Rbe_all = zeros(3,3,N);

% Initial tilt from accelerometer (align gravity to [0,0,-1]_e)
acc0 = normalize(accB(1,:))';
g_e  = [0;0;-1];                      % gravity direction in earth
v    = cross(acc0, -g_e);             % rotate acc0 to -g_e
s    = norm(v);
c    = dot(acc0, -g_e);
if s < 1e-8
    q = [1;0;0;0];
else
    axis = v/s;
    angle = atan2(s, c);
    q = [cos(angle/2); axis*sin(angle/2)];
end

for k = 1:N
    % --- Prediction: integrate gyro (body rates) ---
    omega_b = (gyrB(k,:)' - bias);                 % rad/s, body frame
    dq = [1; 0.5*omega_b*dt];                      % small-angle quaternion
    q  = normalize(qmul(q, dq));

    % --- Correction: keep gravity vertical (earth z-up) ---
    Rbe = q2R(q);
    g_b_est = Rbe.' * g_e;                         % expected gravity dir in body
    a_b_meas = normalize(accB(k,:))';              % measured dir (no units)
    e_tilt = cross(a_b_meas, g_b_est);             % error drives roll/pitch only

    % Apply correction to gyro (feedback)
    omega_corr = Kp * e_tilt;
    bias = bias - Ki * e_tilt * dt;                % slow bias adaptation

    % Re-integrate with correction (better accuracy)
    dq = [1; 0.5*(omega_b + omega_corr)*dt];
    q  = normalize(qmul(q, dq));

    % Save
    Q(:,k) = q;
    Rbe_all(:,:,k) = q2R(q);
end

%% --------------- Rotate to earth & remove gravity ---------------
accE = zeros(N,3);  gyrE = zeros(N,3);
for k = 1:N
    Rbe = Rbe_all(:,:,k);
    gyrE(k,:) = (Rbe * gyrB(k,:).').';                        % rad/s in earth
    accE(k,:) = (Rbe * accB(k,:).').';                        % m/s^2 in earth
end
accE = accE + [0 0 g0];                                       % remove gravity

%% --------------- Plot Body-frame IMU signals ---------------
t = (0:N-1)'/Fs;

figure('Name','Body-frame IMU');

subplot(3,2,1);
plot(t, accB(:,1)); ylabel('a_x [m/s^2]');
title('Acceleration X (Forward)'); grid on;

subplot(3,2,3);
plot(t, accB(:,2)); ylabel('a_y [m/s^2]');
title('Acceleration Y (Up)'); grid on;

subplot(3,2,5);
plot(t, accB(:,3)); ylabel('a_z [m/s^2]');
xlabel('Time [s]'); title('Acceleration Z (Right)'); grid on;

subplot(3,2,2);
plot(t, gyrB(:,1)); ylabel('\omega_x [rad/s]');
title('Gyro X'); grid on;

subplot(3,2,4);
plot(t, gyrB(:,2)); ylabel('\omega_y [rad/s]');
title('Gyro Y'); grid on;

subplot(3,2,6);
plot(t, gyrB(:,3)); ylabel('\omega_z [rad/s]');
xlabel('Time [s]'); title('Gyro Z'); grid on;


%% --------------- Plot Earth-frame IMU signals ---------------
figure('Name','Earth-frame IMU');

subplot(3,2,1);
plot(t, accE(:,1)); ylabel('a_x [m/s^2]');
title('Acceleration X_e'); grid on;

subplot(3,2,3);
plot(t, accE(:,2)); ylabel('a_y [m/s^2]');
title('Acceleration Y_e'); grid on;

subplot(3,2,5);
plot(t, accE(:,3)); ylabel('a_z [m/s^2]');
xlabel('Time [s]'); title('Acceleration Z_e'); grid on;

subplot(3,2,2);
plot(t, gyrE(:,1)); ylabel('\omega_x [rad/s]');
title('Gyro X_e'); grid on;

subplot(3,2,4);
plot(t, gyrE(:,2)); ylabel('\omega_y [rad/s]');
title('Gyro Y_e'); grid on;

subplot(3,2,6);
plot(t, gyrE(:,3)); ylabel('\omega_z [rad/s]');
xlabel('Time [s]'); title('Gyro Z_e'); grid on;


%% ====================== Helpers ======================
function idx = local_find_col(varnames, candidates)
    vn = string(varnames); vn = lower(regexprep(vn,'[_\-]',''));
    idx = NaN;
    for c = 1:numel(candidates)
        pat = lower(regexprep(string(candidates{c}),'[_\-]',''));
        k = find(vn==pat,1,'first');
        if ~isempty(k), idx = k; return; end
    end
end


