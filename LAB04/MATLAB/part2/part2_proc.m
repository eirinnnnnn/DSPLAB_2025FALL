%% ==================== Part 2: Window + Centroid =======================
% 讀 CSV（單欄或含標題皆可）
emit = readmatrix('part2_emit_times_ps.csv');    emit = emit(~isnan(emit));  % [~200k x 1]
recv = readmatrix('part2_receive_times_ps.csv'); recv = recv(~isnan(recv));  % [~140k x 1]
emit = sort(double(emit(:)), 'ascend');
recv = sort(double(recv(:)), 'ascend');
Ne = numel(emit); Nr = numel(recv);

% ---------- Part 1 同步流程：建立 ToF 樣本 ----------
% 對每個接收事件，找最近且不晚於它的發射事件
idx_prev_emit = interp1(emit, 1:Ne, recv, 'previous', NaN);
valid = ~isnan(idx_prev_emit);
idx_prev_emit = idx_prev_emit(valid);
recv_valid    = recv(valid);

% 時間差 Δt（單位：100 ps），限制在 0~1250
dt_100ps = recv_valid - emit(idx_prev_emit);
in_range = (dt_100ps >= 0) & (dt_100ps <= 1250);
dt_100ps = dt_100ps(in_range);
idx_prev_emit = idx_prev_emit(in_range);

% 每個發射週期只取「最早抵達」的光子（Δt 最小）
min_dt_per_emit = accumarray(idx_prev_emit(:), dt_100ps(:), [Ne 1], @min, NaN);
tof = min_dt_per_emit(~isnan(min_dt_per_emit));   % ToF 樣本（單位：100 ps）

% ---------- 建立 histogram（同 Part 1 規格） ----------
nbins = 600;                          % >= 500
edges = linspace(0, 1250, nbins+1);   % 0~1250（單位：100 ps）
[counts, edges] = histcounts(tof, edges);
centers = edges(1:end-1) + diff(edges)/2;

% ---------- Part 2：Window + 取質心 ----------
% 視資料尖峰寬度選窗長（單位：bin）。預設 31 bin（約 3.1 ns）
% 你可改為 21 / 41 做敏感度測試；應確保能涵蓋尖峰但不過寬。
W = 31;                       
if mod(W,2)==0, W = W+1; end         % 取奇數窗較對稱
if W > nbins, error('Window size W 太大'); end

% 逐格掃描（與 for-loop 等價，使用捲積計算移動加總更快）
win = ones(W,1);
mov_sum   = conv(counts,            win, 'valid');  % 每個 window 的總 count
mov_wsum  = conv(counts.*centers,   win, 'valid');  % 每個 window 的加權和（算質心）
centroid  = mov_wsum ./ max(mov_sum,1);             % 每個 window 的質心（100 ps 單位）
[~, iMax] = max(mov_sum);                            % 找到總 count 最多的 window
dt_star_100ps = centroid(iMax);                      % 最終答案：該 window 的質心

% ---------- 轉距離 d = c * Δt / 2 ----------
c = 299792458;                          % m/s
dt_star_sec = dt_star_100ps * 100e-12;  % 100 ps -> s
d_est_m = c * dt_star_sec / 2;

% ---------- 視覺化 ----------
figure('Name','Part 2: Window + Centroid');
bar(centers, counts, 1, 'EdgeColor','none'); grid on;
xlim([0 1250]);
xlabel('Time Difference (unit: 100 ps)');
ylabel('Count');
title('Time-of-Flight Histogram (Part 2)');

% 標示最佳 window 與質心
x_left  = centers(iMax);
x_right = centers(iMax+W-1);
hold on;
patch([x_left x_right x_right x_left], [0 0 max(counts)*1.05 max(counts)*1.05], ...
      [0.85 0.85 1], 'FaceAlpha', 0.25, 'EdgeColor','none');           % 最佳 window 區域
xline(dt_star_100ps, '--', ...
      sprintf('Centroid = %.1f  (\\rightarrow %.2f m)', dt_star_100ps, d_est_m), ...
      'LabelOrientation','horizontal', 'LabelVerticalAlignment','bottom');
hold off;

% ---------- 簡要輸出 ----------
fprintf('[Part 2] nbins=%d, window=%d bins\n', nbins, W);
fprintf('[Part 2] 有效發射週期(收到最早光子)：%d / %d\n', numel(tof), Ne);
fprintf('[Part 2] Δt* (質心) ≈ %.1f (100 ps 單位)  →  d ≈ %.2f m\n', dt_star_100ps, d_est_m);

% ----------（可選）for-loop 寫法示範 ----------
%{
mov_sum2 = zeros(nbins-W+1,1);
centroid2 = zeros(nbins-W+1,1);
for i = 1:(nbins-W+1)
    seg_c = counts(i:i+W-1);
    seg_x = centers(i:i+W-1);
    s = sum(seg_c);
    mov_sum2(i)  = s;
    centroid2(i) = sum(seg_c .* seg_x) / max(s,1);
end
% 檢核
assert(max(abs(mov_sum2 - mov_sum)) < 1e-9);
assert(max(abs(centroid2 - centroid)) < 1e-9);
%}