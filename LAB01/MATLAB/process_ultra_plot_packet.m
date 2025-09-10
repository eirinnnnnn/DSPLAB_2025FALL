function process_ultra_plot_packet(matfile, varargin)
% process_ultra_plot_packet('data_20cm_1.mat', 'Fs',160e3,'fc',40e3,'T',25,'d_true_cm',20)

% ---- 參數 ----
p = inputParser;
addParameter(p,'Fs',160e3);      % 取樣率
addParameter(p,'fc',40e3);       % 載波
addParameter(p,'T',25);          % 室溫(°C)，只用來算理論 n*
addParameter(p,'d_true_cm',[]);  % 如果提供，會顯示理論 n*
addParameter(p,'lp_fc',6e3);     % 低通截止 (包絡頻寬 ~1/T_burst ≈ 5kHz，可掃 2~10k)
addParameter(p,'plot_zoom',2.5e-3); % 峰值附近顯示窗寬(秒)，預設 ±2.5 ms
parse(p,varargin{:});
Fs      = p.Results.Fs;
fc      = p.Results.fc;
TdegC   = p.Results.T;
d_true  = p.Results.d_true_cm;
lp_fc   = p.Results.lp_fc;
zoom_w  = p.Results.plot_zoom;

% ---- 讀檔 ----
S = load(matfile);
if isfield(S,'received_data')
    rx = double(S.received_data(:));
elseif isfield(S,'rx')           % 後備名稱
    rx = double(S.rx(:));
else
    error('找不到變數 received_data（或 rx）於 %s', matfile);
end
N = numel(rx);
n = (0:N-2).';  t = n/Fs;

% ---- DC offset ----
rx = rx(2:end);
rx_dc = rx - median(rx);

% ---- 下變頻：乘上 e^{-j2πf_c t} ----
w0 = 2*pi*fc/Fs;
lo = exp(-1j*w0*n);
bb = rx_dc .* lo;   % baseband complex (I + jQ)

% ---- 低通濾波（保留包絡頻帶），零相位 filtfilt ----
% IIR Butterworth 6 階；若想更平直可改用 FIR
d = designfilt('lowpassiir','FilterOrder',6, ...
    'HalfPowerFrequency',lp_fc,'SampleRate',Fs);
bb_f = filtfilt(d, real(bb)) + 1j*filtfilt(d, imag(bb));

% ---- 取得包絡 ----
env = abs(bb_f);

% ---- 簡單峰值偵測（以 robust baseline 做門檻）----
base = median(env);
noise = median(abs(env - base))*1.4826;  % robust sigma
env_s = movmean(env, 8);                  % 輕微平滑
[pk, n_meas] = max(env_s);
% 也可用閾值： idx = find(env_s > base + 5*noise, 1, 'first');

% ---- 理論 n*（若提供距離）----
n_theo = NaN;
if ~isempty(d_true)
    v = 331 + 0.6*TdegC;             % m/s
    n_theo = (2*(d_true/100)/v) * Fs;
    fprintf('理論 n* = %.2f | 量測峰值 n_meas = %d | Δ=%.2f samples\n', ...
            n_theo, n_meas, n_meas - n_theo);
else
    fprintf('量測峰值 n_meas = %d (未提供 d_true_cm，故不計理論 n*)\n', n_meas);
end

% ---- 繪圖：原始、下變頻後實部、包絡（全域 + 峰值近觀）----
figure('Name','Demod & Envelope'), tiledlayout(2,1,'Padding','compact','TileSpacing','compact');

% (A) 全域視圖
nexttile;
plot(t*1e3, rx, 'Color',[0.7 0.7 0.7], 'DisplayName','Raw RX');
hold on; 
plot(t*1e3, real(bb_f), 'DisplayName','Baseband (real)');
plot(t*1e3, env, 'LineWidth',1.2, 'DisplayName','Envelope');
xline(n_meas/Fs*1e3,'k--','Peak'); 
if ~isnan(n_theo), xline(n_theo/Fs*1e3,'r--','n^* theo'); end
hold off; grid on;
xlabel('Time (ms)'); ylabel('Amplitude (V or a.u.)');
title(sprintf('Demodulated (f_c=%.0f kHz), LPF=%.0f Hz', fc/1e3, lp_fc));
legend('Location','best');

% (B) 峰值附近 zoom
t0 = n_meas/Fs;
nexttile;
tL = max(0, t0 - zoom_w); tR = min(t(end), t0 + zoom_w);
sel = (t>=tL & t<=tR);
plot(t(sel)*1e3, env(sel), 'LineWidth',1.2, 'DisplayName','Envelope (zoom)');
hold on; y = ylim;
plot((n_meas/Fs)*1e3*[1 1], y, 'k--','DisplayName','Peak');
if ~isnan(n_theo)
    plot((n_theo/Fs)*1e3*[1 1], y, 'r--','DisplayName','n^* theo');
end
hold off; grid on;
xlabel('Time (ms)'); ylabel('Envelope');
title('Packet (zoomed around peak)'); legend('Location','best');

rx_fft = fft(rx, n);

% Frequency vector for plotting
f = (0:n-1)*(Fs/n); % Frequency vector

% Plot the magnitude of the FFT
figure;
plot(f, abs(rx_fft));
title('Magnitude of FFT');
xlabel('Frequency (Hz)');
ylabel('|X(f)|');
xlim([0 Fs/2]); % Limit x-axis to half the sampling frequency
grid on;

end