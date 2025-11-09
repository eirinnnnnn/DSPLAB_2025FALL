%% ================== IMU gait analysis: drop-in block ==================
clear; close all;

%% ---------------- IO & param ----------------
in_csv = 'walk1.csv';
out_mat = 'walk1.mat';

Fs  = 50;                 % [Hz]
fc_acc = 5;               % [Hz] LPF for accelerometer ([] to skip)
fc_gyr = 10;              % [Hz] LPF for gyroscope ([] to skip)
ord = 4;

% Units (raw int16 -> SI)
acc_lsb_to_ms2 = 9.80665 / 16384;     % m/s^2 per LSB  (±2 g range)
gyr_lsb_to_rps = (pi/180) / 131;      % rad/s per LSB  (±250 dps range, 131 LSB/(deg/s))
g0 = 9.80665;                         % gravity

% Orientation filter (Mahony-like)
Kp = 2.0;              % proportional tilt gain
Ki = 0.05;             % integral gain for gyro bias (slow)

% Swing/stance detection (body z-axis for right foot)
th_swing_dps    = 40;                % deg/s threshold (tune 20–60)
th_swing        = deg2rad(th_swing_dps);
minSwingDur_s   = 0.15;              % ≥150 ms
minStanceDur_s  = 0.12;              % ≥120 ms

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

% Scale to SI (body frame, with your axes: x=forward, y=up, z=right)
accB = Xraw(:,1:3) * acc_lsb_to_ms2;      % m/s^2
gyrB = Xraw(:,4:6) * gyr_lsb_to_rps;      % rad/s

%% --------------- Low-pass filters (recommended) ---------------
if ~isempty(fc_acc)
    [bA,aA] = butter(ord, fc_acc/(Fs/2), 'low');
    accB_f  = filtfilt(bA, aA, accB);
else
    accB_f  = accB;
end

if ~isempty(fc_gyr)
    [bG,aG] = butter(ord, fc_gyr/(Fs/2), 'low');
    gyrB_f  = filtfilt(bG, aG, gyrB);
else
    gyrB_f  = gyrB;
end

%% --------------- Orientation (Mahony-like, body->earth) ---------------
dt = 1/Fs;
q = [1;0;0;0];                    % quaternion w,x,y,z (body->earth, earth Z-up)
bias = [0;0;0];

% helpers
qmul = @(q1,q2)[ q1(1)*q2(1)-dot(q1(2:4),q2(2:4));
                 q1(1)*q2(2:4)+q2(1)*q1(2:4)+cross(q1(2:4),q2(2:4)) ];
q2R = @(q)[ 1-2*(q(3)^2+q(4)^2), 2*(q(2)*q(3)-q(1)*q(4)),   2*(q(2)*q(4)+q(1)*q(3));
            2*(q(2)*q(3)+q(1)*q(4)),   1-2*(q(2)^2+q(4)^2), 2*(q(3)*q(4)-q(1)*q(2));
            2*(q(2)*q(4)-q(1)*q(3)),   2*(q(3)*q(4)+q(1)*q(2)), 1-2*(q(2)^2+q(3)^2) ];
normalize = @(v) v./max(norm(v),1e-12);

Q = zeros(4,N);  Rbe_all = zeros(3,3,N);

% ---- robust initial tilt from first 2 s (assumes brief stand) ----
n0   = min(N, round(2*Fs));

% make sure these are COLUMN vectors (3x1)
acc0 = mean(accB_f(1:n0,:)).';           % 3x1
acc0 = acc0 ./ max(norm(acc0), 1e-12);   % unit
g_e  = [0;0;-1];                          % 3x1, earth Z-up (gravity direction)

% rotate acc0 to -g_e
v    = cross(acc0, -g_e);                 % 3x1
s    = norm(v);
c    = dot(acc0, -g_e);
if s < 1e-8
    q = [1;0;0;0];
else
    axis = v / s;                         % 3x1
    angle = atan2(s, c);
    q = [cos(angle/2); axis * sin(angle/2)];  % 4x1: [w;x;y;z]
end


for k = 1:N
    % prediction with gyro (body frame)
    omega_b = (gyrB_f(k,:)' - bias);                 % rad/s
    dq = [1; 0.5*omega_b*dt];                        % small-angle quaternion
    q  = normalize(qmul(q, dq));

    % correction: keep gravity vertical (use accel only when near 1g)
    Rbe = q2R(q);
    a_meas = accB_f(k,:)';  a_norm = norm(a_meas);
    use_acc = (a_norm > 0.8*g0) && (a_norm < 1.2*g0);
    if use_acc
        a_b_meas_u = a_meas / a_norm;
        g_b_est    = Rbe.' * g_e;                    % expected gravity dir (body)
        e_tilt     = cross(a_b_meas_u, g_b_est);     % tilt error
    else
        e_tilt     = [0;0;0];
    end
    omega_corr = Kp * e_tilt;
    bias = bias - Ki * e_tilt * dt;

    % corrected re-integration
    dq = [1; 0.5*(omega_b + omega_corr)*dt];
    q  = normalize(qmul(q, dq));

    Q(:,k) = q;
    Rbe_all(:,:,k) = q2R(q);
end

%% --------------- Rotate to earth & remove gravity (correct sign) ---------------
accE = zeros(N,3);  gyrE = zeros(N,3);
for k = 1:N
    Rbe = Rbe_all(:,:,k);
    gyrE(k,:) = (Rbe * gyrB_f(k,:).').';             % rad/s in earth
    accE(k,:) = (Rbe * accB_f(k,:).').';             % m/s^2 in earth (includes +g)
end
accE = accE - [0 0 g0];                               % subtract gravity (linear acc)

%% --------------- Gait phase via body z-rate (right foot pitch) ---------------
wbz = gyrB_f(:,3);                                    % body z-rate [rad/s], right axis

isSwing = abs(wbz) > th_swing;
isSwing = enforce_min_duration(isSwing, round(minSwingDur_s*Fs));
isSwing = logical(imclose(uint8(isSwing), ones(1, max(1, round(0.05*Fs)))));

isStance = ~isSwing;
isStance = enforce_min_duration(isStance, round(minStanceDur_s*Fs));

% stance intervals
edges = diff([0; isStance; 0]);
stance_starts = find(edges== 1);
stance_ends   = find(edges==-1)-1;

%% --------------- Integrate ankle pitch (body z) with per-step drift control ---------------
ang_bz = zeros(N,1);
for s = 1:numel(stance_starts)-1
    i0 = stance_starts(s);    i1 = stance_ends(s);            % stance indices
    j0 = i1+1;                j1 = stance_starts(s+1)-1;      % swing between stances

    if s==1
        ang_bz(i0) = 0;                                       % reference
    else
        ang_bz(i0) = ang_bz(i0-1);
    end

    if j0 <= j1
        ang_bz(j0:j1) = ang_bz(i0) + cumsum(wbz(j0:j1))*dt;  % integrate ω_b,z
        % optional gentle pullback in final 10% of swing
        seg = j0:j1; L = numel(seg);
        if L >= 10
            kpb = seg(round(0.9*L):end);
            ang_bz(kpb) = ang_bz(kpb) .* linspace(1,0,numel(kpb))';
        end
    end

    if stance_starts(s+1) <= N
        ang_bz(stance_starts(s+1)) = 0;                       % clamp at stance
    end
end
ang_bz_deg = rad2deg(ang_bz);

%% --------------- Plots ---------------
figure('Name','Body-frame IMU');
subplot(3,2,1); plot(t, accB(:,1)); ylabel('a_x [m/s^2]'); title('Body Acc X (forward)'); grid on;
subplot(3,2,3); plot(t, accB(:,2)); ylabel('a_y [m/s^2]'); title('Body Acc Y (up)'); grid on;
subplot(3,2,5); plot(t, accB(:,3)); ylabel('a_z [m/s^2]'); xlabel('Time [s]'); title('Body Acc Z (right)'); grid on;
subplot(3,2,2); plot(t, gyrB(:,1)); ylabel('\omega_x [rad/s]'); title('Body Gyro X'); grid on;
subplot(3,2,4); plot(t, gyrB(:,2)); ylabel('\omega_y [rad/s]'); title('Body Gyro Y'); grid on;
subplot(3,2,6); plot(t, gyrB(:,3)); ylabel('\omega_z [rad/s]'); xlabel('Time [s]'); title('Body Gyro Z'); grid on;

figure('Name','Earth-frame IMU (gravity removed)');
subplot(3,2,1); plot(t, accE(:,1)); ylabel('a_{E,x} [m/s^2]'); title('Earth Acc X'); grid on;
subplot(3,2,3); plot(t, accE(:,2)); ylabel('a_{E,y} [m/s^2]'); title('Earth Acc Y'); grid on;
subplot(3,2,5); plot(t, accE(:,3)); ylabel('a_{E,z} [m/s^2]'); xlabel('Time [s]'); title('Earth Acc Z'); grid on;
subplot(3,2,2); plot(t, gyrE(:,1)); ylabel('\omega_{E,x} [rad/s]'); title('Earth Gyro X'); grid on;
subplot(3,2,4); plot(t, gyrE(:,2)); ylabel('\omega_{E,y} [rad/s]'); title('Earth Gyro Y'); grid on;
subplot(3,2,6); plot(t, gyrE(:,3)); ylabel('\omega_{E,z} [rad/s]'); xlabel('Time [s]'); title('Earth Gyro Z'); grid on;

figure('Name','Phase & Ankle pitch (body z)');
subplot(2,1,1);
plot(t, rad2deg(wbz)); hold on; yline(th_swing_dps,'--'); grid on;
ylabel('\omega_{b,z} [deg/s]'); title('Body z-rate (right axis) & swing threshold');
subplot(2,1,2);
plot(t, ang_bz_deg, 'LineWidth',1); hold on;
stairs(t, double(isSwing)*max(ang_bz_deg)*0.9, 'k:'); grid on;
ylabel('\theta_{b,z} [deg]'); xlabel('Time [s]');
title('Ankle pitch: integrated over swing, reset at stance (right foot)');

%% --------------- Save ---------------
save(out_mat, 'Fs','t','accB','gyrB','accB_f','gyrB_f','Q','Rbe_all','accE','gyrE', ...
              'wbz','isSwing','isStance','ang_bz','ang_bz_deg');

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

function y = enforce_min_duration(x, Lmin)
% Ensure binary run-lengths are at least Lmin; remove shorter runs.
% No toolbox needed.
    x = logical(x(:));
    if Lmin<=1 || numel(x)==0, y = x; return; end
    d = diff([false; x; false]);
    run_st = find(d==1);
    run_ed = find(d==-1)-1;
    y = false(size(x));
    for i = 1:numel(run_st)
        if run_ed(i)-run_st(i)+1 >= Lmin
            y(run_st(i):run_ed(i)) = true;
        end
    end
end
