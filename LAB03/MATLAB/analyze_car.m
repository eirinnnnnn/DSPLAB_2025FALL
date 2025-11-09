%% analyze_imu_fft_lpf.m
% Read decoded IMU data, auto-detect motion windows, LPF, FFTs,
% integrate to velocity (with segment-wise drift removal), integrate to displacement,
% and save all results to a .mat file.

%% ---------- User parameters ----------
in_csv = 'zp.csv';    % CSV created by parse_imu_hex.m
out_mat = 'zp.mat';

Fs = 50;                    % [Hz] sampling rate
fc = 5;                     % [Hz] LPF cutoff for accel (set [] to skip LPF)
ord = 4;                    % Butterworth order for LPF
nfft = [];                  % [] -> nextpow2(N)
detrend_type = 'constant';  % 'constant' | 'linear' | 'off'
win_type = 'hann';          % 'hann' | 'rectwin'
show_time_plots = true;

% Integration axis: 'acc_x' | 'acc_y' | 'acc_z' or 1|2|3
axis_for_integration = 'acc_x';

% Units conversion: if accel is in g, set to 9.80665. If already m/s^2, set 1.
g_to_mps2 = 1;

% ----- Motion window auto-detection parameters -----
detect_use_magnitude = true; % true: use ||acc|| magnitude; false: use chosen axis
acc_threshold = 0.2*16384;         % [m/s^2] threshold for activity (after preprocessing)
min_burst_duration = 0.05;    % [s] discard bursts shorter than this
min_silent_gap    = 0.60;     % [s] gaps smaller than this are merged
dilate_edges      = 0.05;     % [s] grow each window on both sides (tolerance)

%% ---------- Titles/labels ----------
titles = {'acc\_x','acc\_y','acc\_z','gyro\_x','gyro\_y','gyro\_z'};
ylabs  = {'acc','acc','acc','gyro','gyro','gyro'};

%% ---------- Load data (robust mapping) ----------
if ~isfile(in_csv), error('Input CSV "%s" not found.', in_csv); end
T = readtable(in_csv);

findCol = @(cands) local_find_col(T.Properties.VariableNames, cands);
ix_accx = findCol({'accx','acc_x','ax','accelx','acc-x'});
ix_accy = findCol({'accy','acc_y','ay','accely','acc-y'});
ix_accz = findCol({'accz','acc_z','az','accelz','acc-z'});
ix_gyrx = findCol({'gyrx','gyro_x','gx','gyrox','gyr-x'});
ix_gyry = findCol({'gyry','gyro_y','gy','gyroy','gyr-y'});
ix_gyrz = findCol({'gyrz','gyro_z','gz','gyroz','gyr-z'});

need = [ix_accx, ix_accy, ix_accz, ix_gyrx, ix_gyry, ix_gyrz];
if any(isnan(need))
    error('Missing required columns. Present: %s', strjoin(T.Properties.VariableNames, ', '));
end

X = double([T{:,ix_accx}, T{:,ix_accy}, T{:,ix_accz}, ...
            T{:,ix_gyrx}, T{:,ix_gyry}, T{:,ix_gyrz}]);
[N,C] = size(X);
t = (0:N-1)'/Fs;

%% ---------- Preprocess (detrend + optional LPF on accel only) ----------
X_pre = X;
switch lower(detrend_type)
    case 'constant', X_pre = detrend(X_pre, 0);
    case 'linear',   X_pre = detrend(X_pre);
    case 'off'
    otherwise, error('Unknown detrend_type.');
end

[b,a] = butter(ord, fc/(Fs/2), 'low');
    X_pre(:,1:3) = filtfilt(b,a,X_pre(:,1:3)); % filter accelerometer channels only

% Window for FFT
if isempty(nfft), nfft = 2^nextpow2(N); end
switch lower(win_type)
    case 'hann',    w = hann(N,'periodic');
    case 'rectwin', w = rectwin(N);
    otherwise, error('Unknown win_type.');
end
Wnorm = sum(w)/N;

%% ---------- FFTs ----------
Xw = X_pre .* w;
[Xmag_raw, f] = single_sided_fft_mag(Xw, Fs, nfft, Wnorm);
figure('Name','RAW FFT (single-sided)','NumberTitle','off');
tiledlayout(2,3,'Padding','compact','TileSpacing','compact');
for k=1:C
    nexttile; plot(f, Xmag_raw(:,k)); grid on; xlim([0, Fs/2]);
    xlabel('Frequency [Hz]'); ylabel('|X(f)|'); title(['RAW FFT: ',titles{k}]);
end

%% ---------- Auto-detect motion windows ----------
dt = 1/Fs;
ai = pick_axis(axis_for_integration);
acc_axis = X_pre(:,ai) * g_to_mps2;
if detect_use_magnitude
    am = sqrt(sum((X_pre(:,1:3)*g_to_mps2).^2,2)); % ||acc||
    sig_for_detect = am;
else
    sig_for_detect = abs(acc_axis);
end

active = sig_for_detect > acc_threshold;
[starts, stops] = logical_runs(active);

% To times
win_raw = [t(starts), t(stops)];

% Keep only sufficiently long bursts
dur = win_raw(:,2) - win_raw(:,1);
win = win_raw(dur >= min_burst_duration, :);

% Merge short gaps
win = merge_gaps(win, min_silent_gap);

% Dilate edges
win = [max(0, win(:,1)-dilate_edges), min(t(end), win(:,2)+dilate_edges)];

%% ---------- Integrate a->v (raw), segment-wise drift removal, integrate v->s ----------
v_r = cumtrapz(t, acc_axis); % raw integrated velocity on chosen axis

v_c = zeros(size(v_r));
mask = false(N,1);
for widx = 1:size(win,1)
    t_ss = win(widx,1);
    t_se = win(widx,2);
    n_ss = find(t>=t_ss,1,'first');
    n_se = find(t>=t_se,1,'first'); if isempty(n_se), n_se = N; end
    rr = n_ss:n_se;

    % linear drift between endpoints v_r(t_ss) and v_r(t_se)
    vd = linspace(v_r(n_ss), v_r(n_se), numel(rr))';
    v_c(rr) = v_r(rr) - vd;

    mask(rr) = true; % mark "in-motion" samples
end
v_c(~mask) = 0; % zero velocity outside motion windows

% Displacement from corrected velocity
s = cumtrapz(t, v_c);

%% ---------- Plots: time series, velocity, displacement ----------
if show_time_plots
    figure('Name','Time Series (raw vs preprocessed)','NumberTitle','off');
    tiledlayout(2,3,'Padding','compact','TileSpacing','compact');
    for k=1:C
        nexttile; plot(t, X(:,k)); hold on; plot(t, X_pre(:,k));
        grid on; xlabel('Time [s]'); ylabel([ylabs{k},' [raw units]']);
        title([titles{k},' (raw vs preprocessed)']); legend('raw','pre','Location','best');
    end
end

figure('Name','Velocity (raw vs drift-corrected)','NumberTitle','off');
plot(t, v_r, 'DisplayName','raw integ'); hold on;
plot(t, v_c, 'DisplayName','drift-corrected'); grid on;
plot(t, v_c, 'DisplayName','drift-corrected'); grid on;

for widx = 1:size(win,1)
    xline(win(widx,1),'k--','HandleVisibility','off');
    xline(win(widx,2),'k--','HandleVisibility','off');
end
xlabel('Time [s]'); ylabel('Velocity [m/s]');
title(sprintf('Velocity on %s (trapezoid integ, segment-wise drift removal)', titles{ai}));
legend('Location','best');

figure('Name','Displacement from corrected velocity','NumberTitle','off');
plot(t, s/16384*100*9.81); grid on;
for widx = 1:size(win,1)
    xline(win(widx,1),'k--'); xline(win(widx,2),'k--');
end
xlabel('Time [s]'); ylabel('Displacement [cm]');
title(sprintf('Displacement on %s', titles{ai}));

%% ---------- Save to .mat ----------
OUT = struct();
OUT.in_csv   = in_csv;
OUT.Fs       = Fs;
OUT.fc       = fc;
OUT.ord      = ord;
OUT.nfft     = nfft;
OUT.detrend_type = detrend_type;
OUT.win_type     = win_type;
OUT.axis_for_integration = axis_for_integration;
OUT.g_to_mps2 = g_to_mps2;

OUT.t = t;
OUT.X_raw = X;
OUT.X_pre = X_pre;

OUT.f = f;
OUT.Xmag_raw = Xmag_raw;

OUT.motion_windows = win;          % [t_ss, t_se] per row
OUT.acc_axis = acc_axis;
OUT.v_raw = v_r;
OUT.v_corr = v_c;
OUT.displacement = s;

% detection params
OUT.detect = struct('use_magnitude',detect_use_magnitude, ...
                    'threshold',acc_threshold, ...
                    'min_burst_duration',min_burst_duration, ...
                    'min_silent_gap',min_silent_gap, ...
                    'dilate_edges',dilate_edges);

save(out_mat, '-struct', 'OUT');
fprintf('Saved analysis to %s\n', out_mat);

%% ===================== Helpers =====================

function idx = local_find_col(varnames, candidates)
    vn = string(varnames);  vn_norm = lower(regexprep(vn, '[_\-]', ''));
    idx = NaN;
    for c = 1:numel(candidates)
        pat = lower(regexprep(string(candidates{c}), '[_\-]', ''));
        hit = find(vn_norm == pat, 1, 'first');
        if ~isempty(hit), idx = hit; return; end
    end
end

function [Xmag, f] = single_sided_fft_mag(Xt, Fs, nfft, Wnorm)
    [N, C] = size(Xt);
    Xf = fft(Xt, nfft, 1);
    P2 = abs(Xf / (N*Wnorm));
    K  = floor(nfft/2) + 1;
    P1 = P2(1:K, :);
    if rem(nfft,2)==0, P1(2:end-1,:) = 2*P1(2:end-1,:); else, P1(2:end,:) = 2*P1(2:end,:); end
    Xmag = P1;
    f = (0:K-1).' * (Fs/nfft);
end

function ai = pick_axis(axis_for_integration)
    if isnumeric(axis_for_integration)
        ai = axis_for_integration;
    else
        switch lower(string(axis_for_integration))
            case "acc_x", ai = 1;
            case "acc_y", ai = 2;
            case "acc_z", ai = 3;
            otherwise, error('axis_for_integration must be acc_x/acc_y/acc_z or 1..3');
        end
    end
    if ai<1 || ai>3, error('axis_for_integration must reference an accelerometer axis (1..3).'); end
end

function [starts, stops] = logical_runs(x)
% Return start/stop indices (inclusive) of true runs in logical vector x.
    x = x(:) ~= 0;
    dx = diff([false; x; false]);
    starts = find(dx==1);
    stops  = find(dx==-1) - 1;
end

function win2 = merge_gaps(win, min_gap)
% Merge windows whose gap is < min_gap (in seconds).
    if isempty(win), win2 = win; return; end
    win = sortrows(win,1);
    out = win(1,:);
    for i = 2:size(win,1)
        if win(i,1) - out(end,2) < min_gap
            out(end,2) = max(out(end,2), win(i,2)); % merge
        else
            out = [out; win(i,:)]; %#ok<AGROW>
        end
    end
    win2 = out;
end
