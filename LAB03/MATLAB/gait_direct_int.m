%% analyze_imu_gait.m
% Body->Earth transform, gait phase detection, step length/height & trajectory.
% Input: CSV from parse_imu_hex.m (cols robustly mapped).
% Output: walk1.mat + figures.

%% ---------------- User params ----------------
in_csv = 'walk1.csv';
out_mat = 'walk1.mat';
% in_csv = 'square3_3.csv';
% out_mat = 'square3_3.mat';
Fs  = 50;                 % [Hz]
fc_acc = 5;               % [Hz] LPF for accelerometer ([] to skip)
fc_gyr = 10;              % [Hz] LPF for gyroscope ([] to skip)
ord = 4;

% Units (raw int16 -> SI)
acc_lsb_to_ms2 = 9.80665 / 16384;     % m/s^2 per LSB  (±2 g range)
gyr_lsb_to_rps = (pi/180) / 131;      % rad/s per LSB  (±250 dps range)
g0 = 9.80665;                         % gravity

% Complementary filter (roll,pitch)
alpha = 0.98;             % gyro weight per sample (0.95~0.995)
acc_tilt_lpf = 2.0;       % [Hz] pre-LPF accel for tilt
use_yaw = false;          % yaw ignored (no magnetometer)

% ---------- Stance detection (MOD 1: deviation from 1g) ----------
% Hysteresis thresholds (tune these)
Omega_low  = 0.25;        % rad/s  (enter stance if |wz| < Omega_low)
Omega_high = 0.50;        % rad/s  (exit  stance if |wz| > Omega_high)
A_low      = 2.0;         % m/s^2  (enter stance if |aY - 1g| < A_low)
A_high     = 6.0;         % m/s^2  (exit  stance if |aY - 1g| > A_high)

% Dwell / clean-up
min_stance_dur = 0.15;    % s   (discard shorter stance islands)
min_gap        = 0.10;    % s   (merge stance islands with tiny gaps)
dilate_edges   = 0.05;    % s   (expand stance intervals a bit)

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

%% --------------- Detrend & LPF ---------------
accB = detrend(accB,0);
gyrB = detrend(gyrB,0);

if ~isempty(fc_acc)
    [bA,aA] = butter(ord, fc_acc/(Fs/2), 'low');
    accB = filtfilt(bA,aA,accB);
end
if ~isempty(fc_gyr)
    [bG,aG] = butter(ord, fc_gyr/(Fs/2), 'low');
    gyrB = filtfilt(bG,aG,gyrB);
end

%% --------------- Roll & pitch (complementary) ---------------
% Body axes: x=forward, y=up, z=right  (right-handed)
[bT,aT] = butter(2, min(0.49, acc_tilt_lpf/(Fs/2)), 'low');
accT = filtfilt(bT,aT,accB);
ax = accT(:,1); ay = accT(:,2); az = accT(:,3);

% Acc-derived tilt
pitch_acc = atan2(-ax, ay);              % forward tilt
roll_acc  = atan2( az, hypot(ax, ay) );  % side tilt

pitch = zeros(N,1); roll = zeros(N,1);
for n=2:N
    dt = t(n)-t(n-1);
    pitch_gyro = pitch(n-1) + gyrB(n,2)*dt;   % gyry ~ pitch rate
    roll_gyro  = roll(n-1)  + gyrB(n,1)*dt;   % gyrx ~ roll  rate
    pitch(n) = alpha*pitch_gyro + (1-alpha)*pitch_acc(n);
    roll(n)  = alpha*roll_gyro  + (1-alpha)*roll_acc(n);
end
yaw = zeros(N,1);
if use_yaw
    yaw = cumsum([0; gyrB(2:end,3)].*(1/Fs)); % crude, no mag
end

%% --------------- Rotate body -> earth ---------------
accE = zeros(N,3);
gyrE = zeros(N,3);
for n=1:N
    R = eul2rotm([yaw(n), pitch(n), roll(n)], 'ZYX'); % yaw-pitch-roll
    accE(n,:) = (R * accB(n,:).').';
    gyrE(n,:) = (R * gyrB(n,:).').';
end

% Remove gravity from earth vertical (so accE(:,2) is "net" vertical)
accE(:,2) = accE(:,2) - g0;

%% --------------- Gait phase: stance / swing  (MOD 1) ---------------
% Use |ωz| and deviation from 1g on vertical axis (earth frame).
wz   = abs(gyrE(:,3));                   % rad/s
ay_g = abs((accE(:,2) + g0));       % = |(aY_net + g) - g| = |aY_raw - g|  (m/s^2)

% Hysteresis + dwell
is_stance = false(N,1);
state = false; % false=swing, true=stance


for n = 1:N
    if ~state
        % Enter stance when BOTH quiet
        if wz(n) < Omega_low
            state = true;
        end
    else
        % Exit stance when EITHER becomes large
        if wz(n) > Omega_high
            state = false;
        end
    end
    is_stance(n) = state;
end


% Enforce minimum stance duration
[st_starts, st_stops] = logical_runs(is_stance);
dur = t(st_stops) - t(st_starts);
keep = dur >= min_stance_dur;
st_starts = st_starts(keep); st_stops = st_stops(keep);

% Merge tiny gaps and dilate edges
merged = [t(st_starts) t(st_stops)];
merged = merge_gaps(merged, min_gap);
merged = [max(0, merged(:,1)-dilate_edges), min(t(end), merged(:,2)+dilate_edges)];

% Rebuild stance mask
is_stance(:) = false;
for k = 1:size(merged,1)
    i1 = find(t >= merged(k,1), 1, 'first');
    i2 = find(t >= merged(k,2), 1, 'first');
    is_stance(i1:i2) = true;
end

% Final stance index list & step segmentation
[st_starts, st_stops] = logical_runs(is_stance);
num_steps = max(0, numel(st_starts)-1);  % stance[i] -> stance[i+1] is one step


%% --------------- Integrate with per-step drift removal (velocities only) ---------------
axE = accE(:,1); ayE = accE(:,2); azE = accE(:,3);

vx = zeros(N,1); vy = zeros(N,1); vz = zeros(N,1);
step_windows = cell(num_steps,1);
step_length  = zeros(num_steps,1);   % will be filled after s(t) is built
step_height  = zeros(num_steps,1);

for s = 1:num_steps
    i1 = st_stops(s);           % end of stance s  (start of swing)
    i2 = st_starts(s+1);        % start of stance s+1 (end of swing)
    if i2 <= i1, continue; end
    rr = i1:i2;

    % ---- (1) Remove DC accel bias from preceding stance s
    si = st_starts(s):st_stops(s);
    ax_bias = mean(axE(si));
    ay_bias = mean(ayE(si));
    az_bias = mean(azE(si));

    ax_seg = axE(rr) - ax_bias;
    ay_seg = ayE(rr) - ay_bias;
    az_seg = azE(rr) - az_bias;

    % ---- (2) acc -> vel, then enforce zero-velocity endpoints (ZUPT-V)
    vx_raw = cumtrapz(t(rr), ax_seg);
    vy_raw = cumtrapz(t(rr), ay_seg);
    vz_raw = cumtrapz(t(rr), az_seg);

    vx_corr = vx_raw - linspace(vx_raw(1), vx_raw(end), numel(rr))';
    vy_corr = vy_raw - linspace(vy_raw(1), vy_raw(end), numel(rr))';
    vz_corr = vz_raw - linspace(vz_raw(1), vz_raw(end), numel(rr))';

    % (Optional) avoid tiny backward slips in X
    % comment the next line if you want signed forward velocity
    vx_corr = max(vx_corr, 0);

    % ---- (3) write corrected velocities into the global arrays
    vx(rr) = vx_corr;
    vy(rr) = vy_corr;
    vz(rr) = vz_corr;

    % explicit zeros at the stance boundaries for neat plots
    vx(i1)=0; vx(i2)=0; vy(i1)=0; vy(i2)=0; vz(i1)=0; vz(i2)=0;

    step_windows{s} = [t(i1), t(i2)];
end

% Zero velocity outside swing windows (already true for most samples)
mask = false(N,1);
for s=1:num_steps
    rr = st_stops(s):st_starts(s+1);
    mask(rr) = true;
end
vx(~mask)=0; vy(~mask)=0; vz(~mask)=0;

%% --------------- Displacement from direct velocity integration ---------------
% single global integration; produces the staircase you expect
sx = cumtrapz(t, vx);
sy = cumtrapz(t, vy);
sz = cumtrapz(t, vz);



% Per-step metrics computed after s(t) is known
for s = 1:num_steps
    i1 = st_stops(s); i2 = st_starts(s+1);
    if i2 <= i1, continue; end
    rr = i1:i2;
    step_length(s) = sx(i2) - sx(i1);           % forward gain
    step_height(s) = max(sy(rr)) - min(sy(rr)); % vertical excursion
end

%% --------------- 步速分析 (Step speed analysis) ---------------
% Conventions:
% - Your 'step' = one swing of the instrumented foot: stance[s] -> stance[s+1].
% - 'Stride' here = time between consecutive stances of the SAME foot
%   (i.e., st_starts(i) -> st_starts(i+1)). Cadence (this foot) = 60 / stride_time [strides/min].
% - Approx overall step cadence (both feet) ≈ 2 * (this-foot cadence).

% --- Per-step duration & speed (forward)
step_time   = zeros(num_steps,1);
step_speed  = zeros(num_steps,1);   % forward avg speed per step [m/s]
for s = 1:num_steps
    i1 = st_stops(s);        % end of stance s (start of swing)
    i2 = st_starts(s+1);     % start of stance s+1 (end of swing)
    if i2 <= i1, continue; end
    step_time(s)  = t(i2) - t(i1);
    step_speed(s) = step_length(s) / max(step_time(s), eps);
end

% --- Stride times and foot-cadence (this foot only)
if numel(st_starts) >= 2
    stride_times = diff(t(st_starts));             % [s], between same-foot stances
    cadence_foot = 60 ./ stride_times;             % [strides/min] for this foot
    % Approx overall step cadence (both feet)
    cadence_steps_total = 2 * cadence_foot;        % [steps/min]
else
    stride_times = [];
    cadence_foot = [];
    cadence_steps_total = [];
end

% --- Overall average forward speed (only when moving)
moving = abs(vx) > 1e-3;                           % crude "moving" mask
if any(moving)
    t0 = t(find(moving,1,'first'));
    t1 = t(find(moving,1,'last'));
    sx0 = sx(find(moving,1,'first'));
    sx1 = sx(find(moving,1,'last'));
    avg_speed = (sx1 - sx0) / max(t1 - t0, eps);   % [m/s]
else
    avg_speed = 0;
end

% --- Optional: instantaneous speed (LPF) from vx
% (Signed forward speed; set abs(vx) if you prefer magnitude.)
win_sec = 0.20;                     % 200 ms moving-avg window
win     = max(1, round(win_sec * Fs));
vxf     = movmean(vx, win);         % simple smoother

% --- Report
fprintf('步速分析:\n');
fprintf('  平均前進速度: %.3f m/s\n', avg_speed);
if ~isempty(stride_times)
    fprintf('  中位單腳步頻(此腳): %.1f strides/min (IQR %.1f–%.1f)\n', ...
        median(cadence_foot), prctile(cadence_foot,25), prctile(cadence_foot,75));
    fprintf('  估計總步頻(雙腳):   %.1f steps/min\n', median(cadence_steps_total));
end
if any(step_time>0)
    fprintf('  中位步長: %.3f m, 中位步時: %.3f s, 中位步速: %.3f m/s\n', ...
        median(step_length(step_time>0)), median(step_time(step_time>0)), ...
        median(step_speed(step_time>0)));
end

% --- Plots
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



figure('Name','步速分析 / Step Speed','NumberTitle','off');
tiledlayout(3,1);

% (1) Per-step forward speed
nexttile;
bar(step_speed,'FaceAlpha',0.9); grid on;
ylabel('m/s'); title('Per-step forward speed (s_x increment / step time)');
xlabel('Step #');

% (2) Foot cadence timeline (this foot) and approximate total step cadence
nexttile;
if ~isempty(cadence_foot)
    tt_stride = t(st_starts(2:end));                          % time tags at second stance onward
    plot(tt_stride, cadence_foot, '-o'); hold on; grid on;
    plot(tt_stride, cadence_steps_total, '--'); 
    legend('This foot (strides/min)','Both feet (steps/min)','Location','best');
    ylabel('cadence'); title('Cadence timeline');
else
    text(0.1,0.5,'Not enough stances to compute cadence','Units','normalized');
    axis off;
end

% (3) Instantaneous forward speed (smoothed)
nexttile;
plot(t, vxf, 'LineWidth',1.0); grid on;
ylabel('m/s'); xlabel('Time [s]');
title(sprintf('Instantaneous forward speed (%.0f ms MA)', win_sec*1e3));

% Save into OUT
OUT.step_time  = step_time;
OUT.step_speed = step_speed;
OUT.stride_times = stride_times;
OUT.cadence_foot = cadence_foot;
OUT.cadence_steps_total = cadence_steps_total;
OUT.avg_speed = avg_speed;


%% --------------- Plots ---------------
figure('Name','Detection debug (stance windows)','NumberTitle','off');
subplot(3,1,1);
plot(t, gyrE(:,3)); hold on;
yline(Omega_low,'r--'); yline(-Omega_low,'r--');
yline(Omega_high,'r--'); yline(-Omega_high,'r--');
title('\omega_z (earth)'); ylabel('rad/s'); grid on;

subplot(3,1,2);
plot(t, ay_g); hold on;
yline(A_low,'r--'); yline(A_high,'r--');
title('|a_Y - 1g| (earth)'); ylabel('m/s^2'); grid on;

subplot(3,1,3);
plot(t, is_stance); ylim([-0.2 1.2]); grid on; title('stance mask');
for k=1:numel(st_starts)
    x1=t(st_starts(k)); x2=t(st_stops(k));
    subplot(3,1,1); xline(x1,'k--'); xline(x2,'k--');
    subplot(3,1,2); xline(x1,'k--'); xline(x2,'k--');
    subplot(3,1,3); xline(x1,'k--'); xline(x2,'k--');
end

figure('Name','Velocity (earth)','NumberTitle','off');
plot(t,vx,'b'); hold on; plot(t,vy,'r'); plot(t,vz,'g'); grid on;
% plot(t,vx_raw,'b-'); hold on; plot(t,vy_raw,'r-'); plot(t,vz_raw,'g-');
legend('v_X forward','v_Y vertical','v_Z lateral', 'v_X raw','v_Y raw','v_Z raw'); xlabel('s'); ylabel('m/s');
title('Drift-corrected velocity (per-step)');

figure('Name','Displacement (earth)','NumberTitle','off');
subplot(3,1,1); plot(t,sx); grid on; ylabel('X [m]'); title('Forward displacement');
subplot(3,1,2); plot(t,sy); grid on; ylabel('Y [m]'); title('Vertical displacement');
subplot(3,1,3); plot(t,sz); grid on; ylabel('Z [m]'); xlabel('Time [s]'); title('Lateral displacement');

figure('Name','3D Trajectory','NumberTitle','off');
plot3(sx, sz, sy, 'r', 'LineWidth', 1.5); grid on; axis equal;
xlabel('X forward [m]'); ylabel('Z right [m]'); zlabel('Y up [m]');
title('Earth-frame trajectory');

figure('Name','Per-step metrics','NumberTitle','off');
subplot(2,1,1); bar(step_length); grid on; ylabel('Length [m]'); title('Step length');
subplot(2,1,2); bar(step_height); grid on; ylabel('Height [m]'); xlabel('Step #'); title('Step height');

%% --------------- Save all results ---------------
OUT = struct();
OUT.file = in_csv; OUT.Fs = Fs;
OUT.params = struct('fc_acc',fc_acc,'fc_gyr',fc_gyr,'alpha',alpha, ...
    'Omega_low',Omega_low,'Omega_high',Omega_high,'A_low',A_low,'A_high',A_high, ...
    'min_stance_dur',min_stance_dur,'min_gap',min_gap,'dilate_edges',dilate_edges);
OUT.t = t;
OUT.acc_body = accB; OUT.gyr_body = gyrB;
OUT.roll = roll; OUT.pitch = pitch; OUT.yaw = yaw;
OUT.acc_earth = accE; OUT.gyr_earth = gyrE;
OUT.stance_idx = [st_starts, st_stops];
OUT.step_windows = step_windows;
OUT.vx = vx; OUT.vy = vy; OUT.vz = vz;
OUT.sx = sx; OUT.sy = sy; OUT.sz = sz;
OUT.step_length = step_length; OUT.step_height = step_height;
save(out_mat,'-struct','OUT');
fprintf('Saved %s\n', out_mat);

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

function [starts, stops] = logical_runs(x)
    x = x(:)~=0;
    d = diff([false; x; false]);
    starts = find(d==1);
    stops  = find(d==-1)-1;
end


function y = fill_forward_const(y, mask)
    if isempty(y), return; end
    y = y(:);
    m = logical(mask(:));
    last_val = 0;
    have_last = false;
    for i = 1:numel(y)
        if m(i)
            last_val = y(i);
            have_last = true;
        else
            if have_last
                y(i) = last_val;  % hold previous position through stance gaps
            end
        end
    end
end

% function y = fill_forward_const(y, mask)
% % Keep position constant outside masked regions (so it doesn't jump back).
%     if isempty(y), return; end
%     y = y(:);
%     idx = find(mask);
%     if isempty(idx), return; end
%     first = idx(1); last = idx(end);
%     y(1:first-1) = y(first);
%     y(last+1:end) = y(last);
% end

function win2 = merge_gaps(win, min_gap)
% Merge consecutive [t_start, t_end] rows whose gap < min_gap (seconds).
    if isempty(win), win2 = win; return; end
    win = sortrows(win,1);
    out = win(1,:);
    for i = 2:size(win,1)
        gap = win(i,1) - out(end,2);
        if gap < min_gap
            out(end,2) = max(out(end,2), win(i,2));
        else
            out = [out; win(i,:)]; %#ok<AGROW>
        end
    end
    win2 = out;
end
