%% 0) Load data
S = load('received_data.mat');              % expect variable: received_data (Volts)
x = S.received_data(:);                     % column
Fs = 1000;                                  % lab default capture rate

t = (0:numel(x)-1).'/Fs;

%% 1) Quick sanity + center
x = x - median(x,'omitnan');                % remove DC bias around 0 V
x = filloutliers(x,'linear','movmedian',Fs/2); % soft de-spike (optional)

%% 2) Baseline wander removal (HP at ~0.5–0.7 Hz)
hpFc = 0.7;                                 % per spec: ECG above ~0.7 Hz
hp = designfilt('highpassiir','FilterOrder',4, ...
    'HalfPowerFrequency',hpFc,'SampleRate',Fs,'DesignMethod','butter');
x_hp = filtfilt(hp, x);

%% 3) 60 Hz notch (and optional 120 Hz)
notch60 = designfilt('bandstopiir','FilterOrder',2, ...
    'HalfPowerFrequency1',59,'HalfPowerFrequency2',61, ...
    'DesignMethod','butter','SampleRate',Fs);
x_n60 = filtfilt(notch60, x_hp);

% Optional 120 Hz if visible:
% notch120 = designfilt('bandstopiir','FilterOrder',2, ...
%     'HalfPowerFrequency1',119,'HalfPowerFrequency2',121, ...
%     'DesignMethod','butter','SampleRate',Fs);
% x_n = filtfilt(notch120, x_n60);
x_n = x_n60;

%% 4) Bandpass ~0.7–30 Hz (per spec)
bp = designfilt('bandpassiir','FilterOrder',6, ...
    'HalfPowerFrequency1',0.7,'HalfPowerFrequency2',30, ...
    'DesignMethod','butter','SampleRate',Fs);
x_bp = filtfilt(bp, x_n);

%% 5) Spectral check (before/after)
N = 2^nextpow2(numel(x));
f = (0:N-1)/N*Fs;
Xraw = abs(fft(x, N));
Xbp  = abs(fft(x_bp, N));

figure; 
subplot(2,1,1); plot(t, x); grid on; title('Raw ECG (V)');
subplot(2,1,2); plot(t, x_bp); grid on; title('Cleaned ECG (0.7–30 Hz, 60 Hz notched)');

figure;
plot(f(1:N/2), 20*log10(Xraw(1:N/2)+eps)); hold on;
plot(f(1:N/2), 20*log10(Xbp(1:N/2)+eps));
grid on; xlabel('Hz'); ylabel('dB');
legend('Raw','Cleaned'); title('Spectrum (Raw vs Cleaned)');

%% 6) R-peak detection (simple + robust)
% Emphasize QRS (~10–25 Hz) using a short derivative + moving integration
qrs_lp = designfilt('bandpassiir','FilterOrder',4, ...
    'HalfPowerFrequency1',8,'HalfPowerFrequency2',20, ...
    'DesignMethod','butter','SampleRate',Fs);
y = filtfilt(qrs_lp, x_bp);
y = abs(y);
y = movmean(y, round(0.120*Fs));           % ~120 ms window

% Adaptive threshold
thr = 0.4*max(y);                           % start; adjust if needed
[~, locs] = findpeaks(y, 'MinPeakHeight',thr, 'MinPeakDistance', round(0.25*Fs));

% Snap peaks to local maxima on cleaned signal
win = round(0.06*Fs);                       % ±60 ms
rpk = zeros(size(locs));
for k=1:numel(locs)
    i0 = max(1, locs(k)-win); i1 = min(numel(x_bp), locs(k)+win);
    [~, ii] = max(x_bp(i0:i1));
    rpk(k) = i0 + ii - 1;
end
rpk = unique(rpk);

% Metrics
RR = diff(rpk)/Fs;                          % seconds
bpm = 60./RR;                               % beats per minute
Vpp = max(x_bp) - min(x_bp);

fprintf('Detected %d beats\n', numel(rpk));
fprintf('Mean HR = %.1f bpm (median %.1f)\n', mean(bpm,'omitnan'), median(bpm,'omitnan'));
fprintf('Peak-to-peak amplitude (cleaned) = %.3f V\n', Vpp);

figure; 
plot(t, x_bp); hold on; 
plot(rpk/Fs, x_bp(rpk), 'ro'); grid on;
title('Cleaned ECG with detected R-peaks'); xlabel('s'); ylabel('V');

%% 7) === Save figures ===
outDir = "figures";
if ~exist(outDir, "dir")
    mkdir(outDir);
end

% Save the three main figures
figHandles = findall(0, 'Type', 'figure');  % get open figure handles
for k = 1:numel(figHandles)
    fig = figHandles(k);
    figure(fig); % bring to focus
    fname = fullfile(outDir, sprintf('ECG_Fig%d.png', k));
    exportgraphics(fig, fname, 'Resolution', 300); % high-res PNG
    fprintf('Saved figure %d → %s\n', k, fname);
end

% Optional: also save as .fig for later editing in MATLAB
for k = 1:numel(figHandles)
    savefig(figHandles(k), fullfile(outDir, sprintf('ECG_Fig%d.fig', k)));
end
