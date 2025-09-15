function R = analyze_ultra_dataset(matfile, varargin)
% ANALYZE_ULTRA_DATASET  Ultrasonic ranging analysis pipeline for DSP LAB 1
% Usage:
%   R = analyze_ultra_dataset('data_20cm_1.mat', 'Fs',160e3,'fc',40e3,'T',25,'d_true_cm',20);
%
% What it does:
%   - Load data (.mat), auto-detect Rx/Tx arrays & Fs if possible
%   - Show raw time signal & spectrum (pre-demod), demodulated spectrum
%   - Baseband demod (mix) + FIR low-pass to get envelope, or Hilbert fallback
%   - Find the dominant echo peak, estimate TOF and distance
%   - Compute absolute error if d_true_cm is provided
%   - Save figures to ./out/ and return a result struct R
%
% Key parameters (name-value):
%   'Fs'        : sampling rate [Hz] (default 160e3 if not found in file)
%   'fc'        : carrier [Hz], default 40e3
%   'T'         : temperature [C], for sound speed v = 331 + 0.6*T [m/s] (default 25)
%   'd_true_cm' : ground-truth distance in cm (optional)
%   'lp_fc'     : baseband LPF cutoff [Hz], default 10e3
%   'method'    : 'mix' (default) or 'hilbert'
%   'guard_us'  : ignore first guard_us microseconds when searching peaks (default 500)
%   'min_echo_us' : min echo time to consider (overrides guard_us if set)
%   'plot_zoom' : time-window [s] around detected peak for zoomed plot (default 2.5e-3)
%   'save_figs' : true/false (default true)
%
% Notes:
%   - If your .mat contains variables like Rx, rx, adc_rx, data_rx, it will try to pick them.
%   - Same for Tx. Tx is optional; we estimate TOF relative to acquisition start.
%   - If pre-emphasis, DC, or strong low-freq drift exists, a highpass could be added.

%% -------------------- Parse params --------------------
p = inputParser;
addParameter(p, 'Fs', 160e3, @(x)isnumeric(x)&&isscalar(x));
addParameter(p, 'fc', 40e3,  @(x)isnumeric(x)&&isscalar(x));
addParameter(p, 'T', 25,     @(x)isnumeric(x)&&isscalar(x));
addParameter(p, 'd_true_cm', [], @(x)isnumeric(x)&&isscalar(x));
addParameter(p, 'lp_fc', 10e3, @(x)isnumeric(x)&&isscalar(x)&&x>0);
addParameter(p, 'method', 'mix', @(s)ischar(s)||isstring(s));
addParameter(p, 'guard_us', 500, @(x)isnumeric(x)&&isscalar(x)&&x>=0);
addParameter(p, 'min_echo_us', [], @(x)isempty(x)||(isnumeric(x)&&isscalar(x)&&x>=0));
addParameter(p, 'plot_zoom', 2.5e-3, @(x)isnumeric(x)&&isscalar(x)&&x>0);
addParameter(p, 'save_figs', true, @(x)islogical(x)||ismember(x,[0 1]));
parse(p, varargin{:});
P = p.Results;

if ~isfile(matfile)
    error('File not found: %s', matfile);
end

%% -------------------- Load data & guess fields --------------------
S = load(matfile);
vars = fieldnames(S);

% Try to find sampling rate in file
candFs = {'Fs','fs','FS','sample_rate','sampling_rate'};
for k=1:numel(candFs)
    if isfield(S,candFs{k}) && isnumeric(S.(candFs{k})) && isscalar(S.(candFs{k}))
        P.Fs = double(S.(candFs{k}));
        break;
    end
end

% Find Rx vector
rxNames = {'Rx','rx','adc_rx','data_rx','y','adc','ch1','record','signal'};
rx = [];
for k=1:numel(rxNames)
    if isfield(S,rxNames{k}) && isnumeric(S.(rxNames{k})) && isvector(S.(rxNames{k}))
        rx = double(S.(rxNames{k})(:));
        break;
    end
end
if isempty(rx)
    % fallback: choose the longest numeric vector
    bestLen = 0; bestName = '';
    for k=1:numel(vars)
        v = S.(vars{k});
        if isnumeric(v) && isvector(v) && numel(v)>bestLen
            bestLen = numel(v); bestName = vars{k};
        end
    end
    if bestLen==0
        error('No numeric vector found for Rx in %s', matfile);
    end
    rx = double(S.(bestName)(:));
end

% Optional Tx (not strictly needed)
tx = [];
txNames = {'Tx','tx','adc_tx','data_tx','x','ch0'};
for k=1:numel(txNames)
    if isfield(S,txNames{k}) && isnumeric(S.(txNames{k})) && isvector(S.(txNames{k}))
        tx = double(S.(txNames{k})(:));
        break;
    end
end

N  = numel(rx);
Fs = P.Fs;  Ts = 1/Fs;
t  = (0:N-1).' * Ts;

% Basic conditioning
rx = rx - median(rx);      % robust DC removal
rx = rx / (max(abs(rx))+eps); % normalize to [-1,1]

%% -------------------- FFT helper --------------------
fftplot = @(x,Fs,ttl) plot_fft_(x,Fs,ttl);

%% -------------------- Pre-demod spectrum --------------------
fig1 = figure('Name','Raw time & spectrum','Color','w');
tiledlayout(2,1,'Padding','compact','TileSpacing','compact');

nexttile;
plot(t*1e3, rx, 'LineWidth',1);
xlabel('Time [ms]'); ylabel('Amplitude'); grid on;
title('Raw Rx (time)');

nexttile;
[fx, Xmag] = fftplot(rx, Fs, 'Raw Rx (spectrum)');
plot(fx/1e3, Xmag, 'LineWidth',1);
xlabel('Frequency [kHz]'); ylabel('|X(f)|'); grid on;
title('Raw Rx (spectrum)');

%% -------------------- Demodulation --------------------
fc = P.fc;
method = lower(string(P.method));
switch method
    case "mix"
        % Mix to baseband (I/Q) then low-pass
        n = (0:N-1).';
        c = cos(2*pi*fc*n/Fs);
        s = -sin(2*pi*fc*n/Fs); % -sin for proper quadrature
        I = rx .* c;
        Q = rx .* s;

        % FIR lowpass design (Hamming, linear phase)
        lp_fc = min(P.lp_fc, 0.45*Fs);   % sanity
        Wn = lp_fc/(Fs/2);
        % Use odd order for linear-phase Type-I
        filt_ord = max(101, 2*ceil(5*Fs/lp_fc)+1); % heuristic: longer for sharper
        b = fir1(filt_ord, Wn, 'low', hamming(filt_ord+1), 'scale');

        If = filtfilt(b,1,I);
        Qf = filtfilt(b,1,Q);
        env = sqrt(If.^2 + Qf.^2);  % envelope

        demod_sig = If + 1j*Qf;

    case "hilbert"
        % Analytic signal + LPF envelope
        z = hilbert(rx);
        env0 = abs(z);

        % Smooth with same FIR LPF
        lp_fc = min(P.lp_fc, 0.45*Fs);
        Wn = lp_fc/(Fs/2);
        filt_ord = max(101, 2*ceil(5*Fs/lp_fc)+1);
        b = fir1(filt_ord, Wn, 'low', hamming(filt_ord+1), 'scale');

        env = filtfilt(b,1,env0);
        demod_sig = z;

    otherwise
        error('Unknown method: %s (use "mix" or "hilbert")', method);
end

%% -------------------- Demod spectrum (sanity) --------------------
fig2 = figure('Name','Demod spectrum','Color','w');
[fx2, Xmag2] = fftplot(demod_sig, Fs, 'Demod (complex) spectrum');
plot(fx2/1e3, Xmag2, 'LineWidth',1); grid on;
xlabel('Frequency [kHz]'); ylabel('|X(f)|'); title('Demodulated spectrum (complex)');

%% -------------------- Peak picking on envelope --------------------
% Search window: ignore early part to avoid Tx leakage/coupling
if ~isempty(P.min_echo_us)
    guard_s = P.min_echo_us*1e-6;
else
    guard_s = P.guard_us*1e-6;
end
start_idx = max(1, round(guard_s*Fs));
env_search = env; env_search(1:start_idx) = 0;

% Peak params (heuristics)
mph = 0.1*max(env);       % min peak height
mpd = round(0.2e-3*Fs);   % min peak distance: 0.2 ms
mprom = 0.05*max(env);    % min prominence

[pk, locs, w, p] = findpeaks(env_search, 'MinPeakHeight',mph, ...
    'MinPeakDistance',mpd, 'MinPeakProminence', mprom);

if isempty(locs)
    warning('No peak found. Try lowering guard_us or adjusting LPF cutoff.');
    t_peak = NaN; d_cm = NaN;
else
    % Choose the most prominent peak
    [~,imax] = max(p);
    loc = locs(imax);
    t_peak = (loc-1)*Ts;  % TOF estimate (relative to acquisition start)
end

%% -------------------- Distance & error --------------------
v_ms = 331 + 0.6*P.T;     % m/s
v_cm_us = v_ms*100/1e6;   % cm/us
if ~isnan(t_peak)
    d_cm = 0.5 * v_cm_us * (t_peak*1e6); % two-way
else
    d_cm = NaN;
end

abs_err_cm = NaN;
if ~isempty(P.d_true_cm) && ~isnan(d_cm)
    abs_err_cm = d_cm - P.d_true_cm;
end

%% -------------------- Plots: envelope + markers --------------------
fig3 = figure('Name','Envelope & peak','Color','w');
subplot(2,1,1);
plot(t*1e3, env, 'LineWidth',1.2); grid on;
xlabel('Time [ms]'); ylabel('Envelope');
title('Envelope (LPF after demod)');
hold on;
if ~isnan(t_peak)
    xline(t_peak*1e3, '--', sprintf('peak @ %.3f ms', t_peak*1e3), 'LineWidth',1);
end
hold off;

% Zoom around peak
subplot(2,1,2);
if ~isnan(t_peak)
    t0 = t_peak - P.plot_zoom; t1 = t_peak + P.plot_zoom;
    idx0 = max(1, floor(t0*Fs)); idx1 = min(N, ceil(t1*Fs));
else
    idx0 = 1; idx1 = N;
end
tz = t(idx0:idx1)*1e3;
plot(tz, env(idx0:idx1), 'LineWidth',1.2); grid on;
xlabel('Time [ms]'); ylabel('Envelope (zoom)');
title('Zoom around peak');
hold on;
if ~isnan(t_peak)
    xline(t_peak*1e3,'--r','LineWidth',1);
end
hold off;

%% -------------------- Console summary --------------------
fprintf('\n=== Analysis Result ===\n');
fprintf('File           : %s\n', matfile);
fprintf('Fs / fc        : %.0f Hz / %.0f Hz\n', Fs, fc);
fprintf('Temperature    : %.1f C  -> v = %.3f m/s\n', P.T, v_ms);
if ~isnan(t_peak)
    fprintf('TOF (peak)     : %.6f s (%.3f ms)\n', t_peak, t_peak*1e3);
    fprintf('Distance (est) : %.3f cm\n', d_cm);
else
    fprintf('TOF (peak)     : N/A\nDistance (est) : N/A\n');
end
if ~isempty(P.d_true_cm) && ~isnan(d_cm)
    fprintf('Ground truth   : %.3f cm\n', P.d_true_cm);
    fprintf('Abs error      : %.3f cm\n', abs_err_cm);
end
fprintf('LPF cutoff     : %.1f kHz, FIR order = %d\n', lp_fc/1e3, filt_ord);
fprintf('Method         : %s\n', method);

%% -------------------- Save figs & return struct --------------------
if P.save_figs
    outdir = fullfile(pwd,'out');
    if ~exist(outdir,'dir'), mkdir(outdir); end
    [~,bn,~] = fileparts(matfile);
    saveas(fig1, fullfile(outdir, sprintf('%s_raw.png',bn)));
    saveas(fig2, fullfile(outdir, sprintf('%s_demod_spectrum.png',bn)));
    saveas(fig3, fullfile(outdir, sprintf('%s_envelope_peak.png',bn)));
end

R = struct();
R.file = matfile;
R.Fs = Fs; R.fc = fc; R.T = P.T;
R.v_ms = v_ms; R.v_cm_us = v_cm_us;
R.t_peak = t_peak;
R.distance_cm = d_cm;
R.d_true_cm = P.d_true_cm;
R.abs_error_cm = abs_err_cm;
R.method = char(method);
R.lpf_cutoff = P.lp_fc;
R.fir_order = filt_ord;
R.guard_s = guard_s;

end % main function

%% -------------------- Helpers --------------------
function [f, mag] = plot_fft_(x, Fs, ~)
% One-sided magnitude spectrum
N = numel(x);
X = fft(x .* hann(N));
X = X(1:floor(N/2)+1);
mag = abs(X)/max(abs(X)+eps);
f = linspace(0, Fs/2, numel(X));
end
