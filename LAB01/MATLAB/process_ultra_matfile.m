function out = process_ultra_matfile(matfile, varargin)
% PROCESS_ULTRA_MATFILE  Process ultrasonic TX/RX saved as tx_received_data & received_data.
%   out = process_ultra_matfile('data_60cm_AC_ON.mat', 'Fs',160e3,'fc',40e3,'T',25, ...)
%
% Inputs (Name-Value):
%   'Fs'          : sampling rate [Hz], default 160e3
%   'fc'          : carrier [Hz], default 40e3
%   'T'           : temperature [°C] for speed of sound, default 25
%   'lp_fc'       : LPF cutoff for envelope [Hz], default 7e3 (≈ burst BW)
%   'burst_cycles': TX burst cycles, default 8
%   'search_cm'   : [min max] search window after TX (two-way distance) [cm], default [10 250]
%   'd_true_cm'   : ground-truth distance [cm], default []
%   'method'      : 'iq' | 'hilbert' | 'rect' for envelope, default 'iq'
%   'savefig'     : save figures as PNG next to matfile, default false
%
% Assumes MAT file contains:
%   tx_received_data : TX channel (Volts), length 8192
%   received_data    : RX channel (Volts), length 8192

%% ---- Parameters ----
p = inputParser;
addParameter(p,'Fs',160e3);
addParameter(p,'fc',40e3);
addParameter(p,'T',25);
addParameter(p,'lp_fc',7e3);
addParameter(p,'burst_cycles',8);
addParameter(p,'search_cm',[10 250]);
addParameter(p,'d_true_cm',[]);
addParameter(p,'method','iq');           % 'iq' (recommended), 'hilbert', 'rect'
addParameter(p,'savefig',false);
parse(p,varargin{:});
Fs=p.Results.Fs; fc=p.Results.fc; T=p.Results.T; lp_fc=p.Results.lp_fc;
burst_cycles=p.Results.burst_cycles; search_cm=p.Results.search_cm;
d_true_cm=p.Results.d_true_cm; method=lower(p.Results.method);
savefigs = p.Results.savefig;

assert(exist(matfile,'file')==2, 'MAT file not found: %s', matfile);
S = load(matfile);
% Robust variable access
if isfield(S,'tx_received_data'), tx = S.tx_received_data; elseif isfield(S,'tx'), tx = S.tx; else, error('No tx_received_data in MAT.'); end
if isfield(S,'received_data'),     rx = S.received_data;   elseif isfield(S,'rx'), rx = S.rx; else, error('No received_data in MAT.');   end

tx = tx(2:end); rx = rx(2:end);
N = min(length(tx), length(rx));
tx = tx(1:N); rx = rx(1:N);
n  = (0:N-1).';           % sample index
t  = n/Fs;                % time [s]

%% ---- Preprocess: de-mean & light band limiting for stability ----
tx0 = tx - mean(tx);
rx0 = rx - mean(rx);

% Optional pre-BP (very light) to stabilize demod; comment if not needed
[b_bp,a_bp] = butter(2, [max(100,fc-12e3) fc+12e3]/(Fs/2), 'bandpass');
tx_bp = filtfilt(b_bp,a_bp,tx0);
rx_bp = filtfilt(b_bp,a_bp,rx0);

%% ---- Envelope extraction helper ----
function e = envelope_of(x)
    switch method
        case 'iq'
            c = cos(2*pi*fc*t);
            s = sin(2*pi*fc*t);
            I = x .* c;
            Q = x .* s;
            e = sqrt(I.^2 + Q.^2);
        case 'hilbert'
            z = hilbert(x);
            e = abs(z);
        case 'rect'
            e = abs(x);
        otherwise
            error('Unknown method: %s', method);
    end
end

% LPF for envelope (zero-phase)
Wc = min(lp_fc, 0.45*Fs) / (Fs/2);
[b_lp,a_lp] = butter(4, Wc, 'low');

%% ---- TX envelope & burst start detection ----
e_tx  = envelope_of(tx_bp);
e_tx  = filtfilt(b_lp,a_lp,e_tx);

% Automatic threshold using robust MAD
madfun = @(x) median(abs(x - median(x))) / 0.6745;
tau_tx = median(e_tx) + 4*madfun(e_tx);     % conservative to avoid early noise
% Find first significant TX peak
[minpkdist_smpl] = round(0.2e-3*Fs);        % ~0.2 ms separation
[pks_tx,locs_tx] = findpeaks(real(e_tx), 'MinPeakHeight', tau_tx, 'MinPeakDistance', minpkdist_smpl);

if isempty(locs_tx)
    % fallback: take global max in first 2 ms
    locs_tx = find(e_tx == max(e_tx(1:min(N, round(2e-3*Fs)))), 1, 'first');
    pks_tx  = e_tx(locs_tx);
end

% Estimate "TX start" as the leading edge near the first strong peak.
% Use 50% rising crossing going backward from the first TX peak within burst length.
N_burst = round(burst_cycles * Fs / fc);    % ~ number of samples in 8 cycles
i_peak  = locs_tx(1);
halfAmp = 0.5 * pks_tx(1);
left    = max(1, i_peak - N_burst);
idxRise = left + find(e_tx(left:i_peak) >= halfAmp, 1, 'first') - 1;
if isempty(idxRise), idxRise = i_peak; end
n_tx0 = idxRise;          % TX time-reference (sample index)

%% ---- RX envelope & first-echo search window ----
e_rx  = envelope_of(rx_bp);
e_rx  = filtfilt(b_lp,a_lp,e_rx);

% Speed of sound [cm/us]
v_cm_per_us = 100*(331 + 0.6*T)/1e4;  % = (331+0.6T)*0.01 cm/us
% Min/Max sample offsets from TX based on two-way distance
tof_min_us = 2*search_cm(1) / v_cm_per_us;          % [us]
tof_max_us = 2*search_cm(2) / v_cm_per_us;          % [us]
win_min = n_tx0 + max(1, round(tof_min_us * 1e-6 * Fs));
win_max = min(N, n_tx0 + round(tof_max_us * 1e-6 * Fs));

win = win_min:win_max;
assert(~isempty(win), 'Empty RX search window; check search_cm or TX detection.');

% Adaptive threshold for RX
tau_rx = median(e_rx) + 3*madfun(e_rx);
[pks_rx,locs_rx] = findpeaks(e_rx(win), 'MinPeakHeight', tau_rx, 'MinPeakDistance', minpkdist_smpl);

if isempty(locs_rx)
    % fallback: take maximum within window
    [~,kmax] = max(e_rx(win));
    locs_rx = kmax;
    pks_rx  = e_rx(win(kmax));
end

n_rx_peak = win(locs_rx(1));    % absolute sample index

%% ---- TOF, distance & error ----
delta_n    = n_rx_peak - n_tx0;             % samples
delta_t_us = delta_n * 1e6 / Fs;            % microseconds
d_cm       = 0.5 * v_cm_per_us * delta_t_us;

err_cm = NaN;
if ~isempty(d_true_cm)
    err_cm = d_cm - d_true_cm;
end

%% ---- Spectra (pre/post demod) ----
% Raw RX (bandpass) vs envelope (baseband)
% Use Welch for smoother plots
[Prx,f1]  = pwelch(rx0, hamming(1024), 512, 4096, Fs, 'onesided');
[Pe,f2]   = pwelch(e_rx, hamming(1024), 512, 4096, Fs, 'onesided');

%% ---- Plots ----
[pth,base,~] = fileparts(matfile);
tag = datestr(now,'yyyymmdd_HHMMSS');

% 1) Time-domain with markers
fig1 = figure('Name','Time domain (TX/RX with envelope & markers)', 'Color','w');
t_ms = t*1e3;
subplot(2,1,1);
plot(t_ms, tx0, 'DisplayName','TX (bandpass)'); hold on;
plot(t_ms, e_tx, 'DisplayName','TX envelope');
xline(n_tx0/Fs*1e3,'--','TX start');
xlabel('Time [ms]'); ylabel('V'); title('TX channel'); grid on; legend('show');

subplot(2,1,2);
plot(t_ms, rx0, 'DisplayName','RX (bandpass)'); hold on;
plot(t_ms, e_rx, 'DisplayName','RX envelope');
xline(n_tx0/Fs*1e3,'--','TX start');
xline(n_rx_peak/Fs*1e3,'--r','RX peak');
xlabel('Time [ms]'); ylabel('V'); title(sprintf('RX channel (d=%.2f cm, \\Delta n=%d)', d_cm, delta_n));
grid on; legend('show');

if savefigs
    saveas(fig1, fullfile(pth, sprintf('%s_time_%s.png', base, tag)));
end

% 2) Spectra before/after demod
fig2 = figure('Name','Spectra: bandpass vs baseband', 'Color','w');
subplot(2,1,1);
plot(f1/1e3, 10*log10(Prx+eps));
xlim([0, Fs/2/1e3]); grid on;
xlabel('Frequency [kHz]'); ylabel('PSD [dB/Hz]');
title('RX bandpass spectrum (~40 kHz carrier)');

subplot(2,1,2);
plot(f2/1e3, 10*log10(Pe+eps));
xlim([0, max(20, 4*lp_fc)/1e3]); grid on;
xlabel('Frequency [kHz]'); ylabel('PSD [dB/Hz]');
title('Envelope/baseband spectrum (energy near DC..~burst BW)');

if savefigs
    saveas(fig2, fullfile(pth, sprintf('%s_spectra_%s.png', base, tag)));
end

%% ---- Console summary ----
fprintf('\n=== Ultrasonic processing summary ===\n');
fprintf('File            : %s\n', matfile);
fprintf('Fs, fc, T       : %.0f Hz, %.0f Hz, %.1f °C\n', Fs, fc, T);
fprintf('TX start index  : %d (t = %.3f ms)\n', n_tx0, n_tx0/Fs*1e3);
fprintf('RX peak index   : %d (t = %.3f ms)\n', n_rx_peak, n_rx_peak/Fs*1e3);
fprintf('Δn, Δt          : %d samples, %.3f us\n', delta_n, delta_t_us);
fprintf('Distance (cm)   : %.3f cm\n', d_cm);
if ~isnan(err_cm)
    fprintf('Error           : %.3f cm (measured - true)\n', err_cm);
end
fprintf('Search window   : [%.1f, %.1f] cm two-way\n', search_cm(1), search_cm(2));

%% ---- Output struct ----
out = struct();
out.matfile       = matfile;
out.Fs            = Fs;
out.fc            = fc;
out.T             = T;
out.lp_fc         = lp_fc;
out.method        = method;
out.n_tx0         = n_tx0;
out.n_rx_peak     = n_rx_peak;
out.delta_n       = delta_n;
out.delta_t_us    = delta_t_us;
out.d_cm          = d_cm;
out.err_cm        = err_cm;
out.v_cm_per_us   = v_cm_per_us;
out.search_cm     = search_cm;
out.fig_time      = fig1;
out.fig_spectra   = fig2;

end
