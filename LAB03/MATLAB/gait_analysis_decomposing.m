%% analyze_imu_gait.m
% Body->Earth transform, gait phase detection, step length/height & trajectory.
% Input: CSV from parse_imu_hex.m (cols robustly mapped).
% Output: walk1.mat + figures.

%% ---------------- User params ----------------
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

% Complementary filter (roll,pitch)
alpha = 0.98;             % gyro weight per sample (0.95~0.995)
acc_tilt_lpf = 2.0;       % [Hz] pre-LPF accel for tilt
use_yaw = true; 

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


%% ================= Four-stage gait FSM (per the diagram) =================
% g_z(i): use angular rate about gravity axis in deg/s
gz = -gyrE(:,2) * 180/pi;     % [deg/s]

% Window size: diagram uses ±20 samples at 50 Hz → 0.4 s.
% If Fs differs, scale proportionally.
win = max(1, round(20 * (Fs/50)));     % half-window in samples

% Local extrema tests:  gz(i) >= gz(j) over j in [i-win, i+win], j≠i  (max)
%                       gz(i) <= gz(j) over j in [i-win, i+win], j≠i  (min)
gz_movmax = movmax(gz, [win win], 'Endpoints','shrink');
gz_movmin = movmin(gz, [win win], 'Endpoints','shrink');
isLocalMax = (gz >= gz_movmax);
isLocalMin = (gz <= gz_movmin);

% Thresholds from the slide
TH_UP   =  40;     % deg/s : Stage0 -> Stage1 when gz(i) > 40
TH_DOWN = -100;    % deg/s : Stage1 -> Stage2 when gz(i) < -100

% States: 0,1,2,3 as in the figure. 0/3 = Stance, 1/2 = Swing
N = size(gz,1);
stage = zeros(N,1,'int8');

% Pick a sensible start: if we begin near a minimum, call it Stage0; else Stage3.
stage(1) = isLocalMin(1) * 0 + (~isLocalMin(1)) * 3;

for i = 2:N
    s = stage(i-1);
    g = gz(i);

    switch s
        case 0  % Stage0 (stance)
            if g > TH_UP
                s = 1;                        % Stage0 -> Stage1
            elseif isLocalMin(i)
                s = 0;                        % stay 0 on local min
            elseif isLocalMax(i)
                s = 3;                        % allow 0 -> 3 on local max (diagram's vertical arrow)
            end

        case 1  % Stage1 (swing)
            if g < TH_DOWN
                s = 2;                        % Stage1 -> Stage2
            end
            % otherwise remain in Stage1

        case 2  % Stage2 (swing)
            if isLocalMax(i)
                s = 3;                        % Stage2 -> Stage3 on local max
            end

        case 3  % Stage3 (stance)
            if isLocalMin(i)
                s = 0;                        % Stage3 -> Stage0 on local min
            end
            % otherwise remain in Stage3
    end

    stage(i) = s;
end

% Optional: enforce minimal durations to reduce chattering
minDur = round(0.10*Fs);  % 100 ms
runStarts = [1; 1+find(diff(stage)~=0)];
runEnds   = [runStarts(2:end)-1; N];
for k = 1:numel(runStarts)
    if runEnds(k)-runStarts(k)+1 < minDur && runStarts(k)>1
        stage(runStarts(k):runEnds(k)) = stage(runStarts(k)-1); % absorb short run
    end
end

% Derive stance/swing masks and events for plotting
stance = (stage==0 | stage==3);
swing  = ~stance;
toe_off     = find( stance(1:end-1) & ~stance(2:end) ) + 1; % stance→swing
heel_strike = find(~stance(1:end-1) &  stance(2:end) ) + 1; % swing→stance

%% ------------------------ Visualization ------------------------
figure('Name','FSM phases from g_z logic','Color','w');
tiledlayout(3,1,'Padding','compact','TileSpacing','compact');

% g_z with phases
nexttile;
plot(t, gz, 'LineWidth',1.0); grid on; hold on;
yline(TH_UP,'k--','+40','HandleVisibility','off');
yline(TH_DOWN,'k--','-100','HandleVisibility','off');
yl = ylim;
% shade swing
[ms, me] = logical_runs(swing);
for k = 1:numel(ms)
    patch([t(ms(k)) t(me(k)) t(me(k)) t(ms(k))],[yl(1) yl(1) yl(2) yl(2)], ...
          [0.9 0.95 1.0],'EdgeColor','none','FaceAlpha',0.35);
end
plot(t(toe_off),     gz(toe_off),     'g^','MarkerFaceColor','g','DisplayName','Toe-off');
plot(t(heel_strike), gz(heel_strike), 'rv','MarkerFaceColor','r','DisplayName','Heel-strike');
xlabel('Time [s]'); ylabel('g_z (deg/s)');
title('Angular rate about gravity (deg/s) with FSM phases');
legend('g_z','swing','toe-off','heel-strike','Location','best');

% Stage index as stairs
nexttile;
stairs(t, double(stage), 'LineWidth',1.2); grid on;
ylim([-0.5 3.5]); yticks(0:3); yticklabels({'Stage0','Stage1','Stage2','Stage3'});
xlabel('Time [s]'); title('FSM stage');

% Vertical acceleration (incl. gravity) for reference
nexttile;
aV = -accE(:,2) - g0;
plot(t, aV, 'LineWidth',1.0); grid on; hold on;
yline(g0,'k:','g_0','HandleVisibility','off');
yl = ylim;
for k = 1:numel(ms)
    patch([t(ms(k)) t(me(k)) t(me(k)) t(ms(k))],[yl(1) yl(1) yl(2) yl(2)], ...
          [0.9 0.95 1.0],'EdgeColor','none','FaceAlpha',0.35);
end
xlabel('Time [s]'); ylabel('a_Y^E [m/s^2]');
title('Vertical acceleration (including gravity)');

%% ---------------- accE_x with swing/stance overlay ----------------
figure('Name','Forward acceleration (accE_x) with phases','Color','w');
plot(t, accE(:,1), 'LineWidth',1.2); hold on; grid on;
yline(0,'k:','HandleVisibility','off');
xlabel('Time [s]'); ylabel('a_X^E [m/s^2]');
title('Earth-frame forward acceleration with swing/stance');

% Shade swing regions (blue) and stance (light gray)
yl = ylim;
[ms, me] = logical_runs(swing);
for k = 1:numel(ms)
    patch([t(ms(k)) t(me(k)) t(me(k)) t(ms(k))], [yl(1) yl(1) yl(2) yl(2)], ...
          [0.80 0.90 1.00], 'EdgeColor','none', 'FaceAlpha',0.25);
end
[ms2, me2] = logical_runs(stance);
for k = 1:numel(ms2)
    patch([t(ms2(k)) t(me2(k)) t(me2(k)) t(ms2(k))], [yl(1) yl(1) yl(2) yl(2)], ...
          [0.92 0.92 0.92], 'EdgeColor','none', 'FaceAlpha',0.25);
end

% Events
if ~isempty(toe_off)
    plot(t(toe_off),     accE(toe_off,1), 'g^','MarkerFaceColor','g','DisplayName','Toe-off');
end
if ~isempty(heel_strike)
    plot(t(heel_strike), accE(heel_strike,1), 'rv','MarkerFaceColor','r','DisplayName','Heel-strike');
end

legend({'a_X^E','swing','stance','toe-off','heel-strike'},'Location','best');
uistack(findobj(gca,'Type','line','-and','-not','DisplayName',''), 'top'); % keep trace on top


%% --------------- Plot earth-frame signals: accE (m/s^2) & gyrE (rad/s) ---------------
lbl = {'X (earth-forward)','Y (earth-up)','Z (earth-right)'};
xyz = ["x", "y", "z"];
figure('Name','Earth-frame IMU (accE & gyrE)','Color','w');
tiledlayout(3,2,'Padding','compact','TileSpacing','compact');

for i = 1:3
    % Acceleration (earth frame)
    nexttile( (i-1)*2 + 1 );
    plot(t, accE(:,i), 'LineWidth', 1.2);
    grid on;
    ylabel(sprintf('a_{%s} [m/s^2]', xyz(i)));
    title(['accE\_', lower(lbl{i}(1)) ,': ' lbl{i}]);
    if i==3, xlabel('Time [s]'); end
    % optional zero line
    yline(0,'k:','HandleVisibility','off');

    % Angular rate (earth frame)
    nexttile( (i-1)*2 + 2 );
    plot(t, gyrE(:,i), 'LineWidth', 1.2);
    grid on;
    ylabel(sprintf('\omega_{%s} [rad/s]', xyz(i)));
    title(['gyrE\_', lower(lbl{i}(1)) ,': ' lbl{i}]);
    if i==3, xlabel('Time [s]'); end
    yline(0,'k:','HandleVisibility','off');
end



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
% Keep position constant outside masked regions (so it doesn't jump back).
    if isempty(y), return; end
    y = y(:);
    idx = find(mask);
    if isempty(idx), return; end
    first = idx(1); last = idx(end);
    y(1:first-1) = y(first);
    y(last+1:end) = y(last);
end

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
