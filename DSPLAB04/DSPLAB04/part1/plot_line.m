%% part1_hist_with_missing.m
% Robust LiDAR Part 1: handle missing/ multiple receive photons
clear; clc; close all;

% -------- 1. 讀檔（更穩健的讀法） ----------
emit = readmatrix('part1_emit_times_ps.csv');     % 發射時間 (×100 ps)
recv = readmatrix('part1_receive_times_ps.csv');  % 接收時間 (×100 ps)

% 把可能的矩陣或 row/col 向量攤平成單一向量
emit = emit(:);
recv = recv(:);

% 移除接收中的 NaN（保留以便 later 判斷沒有接收）
recv_valid = recv(~isnan(recv));

% -------- 2. 計算每個發射對應的最早有效接收（若存在） ----------
Nemit = numel(emit);
dt = NaN(Nemit,1);   % time difference (in units of 100 ps); NaN 表示沒有有效接收

% 若 recv 之長度和 emit 一樣且一一對應，直接做 element-wise（較快）
if numel(recv) == Nemit && all(~isnan(emit)) 
    % element-wise 情況（注意仍要檢查 recv > emit）
    tmp = recv - emit;
    tmp(~isfinite(tmp) | tmp <= 0) = NaN;
    dt = tmp;
else
    % 一般情況：recv 是「多個接收時間的清單」
    % 為效能，把 recv_sorted 事先排序
    recv_sorted = sort(recv_valid);
    % 對每個 emit 找 recv_sorted 中第一個 > emit(i)
    % 這邊用 index 掃描（當資料量很大時可再優化）
    rIdx = 1; % 目前 recv_sorted 的游標（加速）
    nRecv = numel(recv_sorted);
    for i = 1:Nemit
        e = emit(i);
        if ~isfinite(e)
            dt(i) = NaN;
            continue;
        end
        % 將 rIdx 移到第一個 recv_sorted(rIdx) > e
        while rIdx <= nRecv && recv_sorted(rIdx) <= e
            rIdx = rIdx + 1;
        end
        if rIdx <= nRecv
            dt(i) = recv_sorted(rIdx) - e;  % 取最早到達的大於發射時間者
            % 注意：不把 rIdx 自動 +1，因為同一個接收可能屬於下個 emit（視實驗情況）
        else
            dt(i) = NaN; % 沒有任何 recv > emit
        end
    end
end

% -------- 3. 過濾有效的時間差（正且有限） ----------
valid_mask = isfinite(dt) & (dt > 0);
num_valid = sum(valid_mask);
num_missing = Nemit - num_valid;

fprintf('發射總數: %d\n', Nemit);
fprintf('有效接收（可計算 Δt）: %d\n', num_valid);
fprintf('缺失或無有效接收: %d\n', num_missing);

if num_valid == 0
    warning('沒有任何有效的時間差，無法建立 histogram 或估算距離。');
    return;
end

dt_valid = dt(valid_mask);

% -------- 4. 建 histogram（500 bins，範圍 0 ~ 1250 ×100ps） ----------
num_bins = 500;
range_min = 0;
range_max = 1250;
edges = linspace(range_min, range_max, num_bins+1);

[counts, ~] = histcounts(dt_valid, edges);

% 找最大峰與其中心
[~, idx_max] = max(counts);
peak_center = (edges(idx_max) + edges(idx_max+1)) / 2;  % in units of 100 ps

% -------- 5. 時間差換算為距離（m） ----------
c = 3e8;  % m/s
delta_t_sec = peak_center * 1e-10;  % 100 ps -> s
distance_m = c * delta_t_sec / 2;

fprintf('Histogram 峰值時間差中心 = %.2f ×100 ps\n', peak_center);
fprintf('估測距離 ≈ %.3f m\n', distance_m);

% -------- 6. 畫圖（histogram + 標記峰值） ----------
figure('Units','normalized','Position',[0.15 0.2 0.6 0.55]);
histogram(dt_valid, edges, 'FaceAlpha', 0.85);
xlabel('Time difference \Delta t (×100 ps)');
ylabel('Counts');
title(sprintf('LiDAR Time Difference Histogram (valid pairs: %d, missing: %d)\\nEstimated distance = %.3f m', ...
    num_valid, num_missing, distance_m));
grid on;

% 在圖上畫峰值位置
hold on;
ymax = max(counts) * 1.05;
xline(peak_center, '--r', sprintf('Peak = %.2f (×100 ps)\\n%.3f m', peak_center, distance_m), ...
    'LabelOrientation','horizontal','LineWidth',1.5);
ylim([0 ymax]);
hold off;

% -------- 7. 若需要，將有效時間差存檔（選用） ----------
saveOption = true;
if saveOption
    writematrix(dt_valid, 'part1_dt_valid_ps.txt'); % 單位: ×100ps
    fprintf('已將有效的 Δt (×100ps) 存為 part1_dt_valid_ps.txt\n');
end
%% part1_hist_with_missing.m
% Robust LiDAR Part 1: handle missing/ multiple receive photons
clear; clc; close all;

% -------- 1. 讀檔（更穩健的讀法） ----------
emit = readmatrix('part1_emit_times_ps.csv');     % 發射時間 (×100 ps)
recv = readmatrix('part1_receive_times_ps.csv');  % 接收時間 (×100 ps)

% 把可能的矩陣或 row/col 向量攤平成單一向量
emit = emit(:);
recv = recv(:);

% 移除接收中的 NaN（保留以便 later 判斷沒有接收）
recv_valid = recv(~isnan(recv));

% -------- 2. 計算每個發射對應的最早有效接收（若存在） ----------
Nemit = numel(emit);
dt = NaN(Nemit,1);   % time difference (in units of 100 ps); NaN 表示沒有有效接收

% 若 recv 之長度和 emit 一樣且一一對應，直接做 element-wise（較快）
if numel(recv) == Nemit && all(~isnan(emit)) 
    % element-wise 情況（注意仍要檢查 recv > emit）
    tmp = recv - emit;
    tmp(~isfinite(tmp) | tmp <= 0) = NaN;
    dt = tmp;
else
    % 一般情況：recv 是「多個接收時間的清單」
    % 為效能，把 recv_sorted 事先排序
    recv_sorted = sort(recv_valid);
    % 對每個 emit 找 recv_sorted 中第一個 > emit(i)
    % 這邊用 index 掃描（當資料量很大時可再優化）
    rIdx = 1; % 目前 recv_sorted 的游標（加速）
    nRecv = numel(recv_sorted);
    for i = 1:Nemit
        e = emit(i);
        if ~isfinite(e)
            dt(i) = NaN;
            continue;
        end
        % 將 rIdx 移到第一個 recv_sorted(rIdx) > e
        while rIdx <= nRecv && recv_sorted(rIdx) <= e
            rIdx = rIdx + 1;
        end
        if rIdx <= nRecv
            dt(i) = recv_sorted(rIdx) - e;  % 取最早到達的大於發射時間者
            % 注意：不把 rIdx 自動 +1，因為同一個接收可能屬於下個 emit（視實驗情況）
        else
            dt(i) = NaN; % 沒有任何 recv > emit
        end
    end
end

% -------- 3. 過濾有效的時間差（正且有限） ----------
valid_mask = isfinite(dt) & (dt > 0);
num_valid = sum(valid_mask);
num_missing = Nemit - num_valid;

fprintf('發射總數: %d\n', Nemit);
fprintf('有效接收（可計算 Δt）: %d\n', num_valid);
fprintf('缺失或無有效接收: %d\n', num_missing);

if num_valid == 0
    warning('沒有任何有效的時間差，無法建立 histogram 或估算距離。');
    return;
end

dt_valid = dt(valid_mask);

% -------- 4. 建 histogram（500 bins，範圍 0 ~ 1250 ×100ps） ----------
num_bins = 500;
range_min = 0;
range_max = 1250;
edges = linspace(range_min, range_max, num_bins+1);

[counts, ~] = histcounts(dt_valid, edges);

% 找最大峰與其中心
[~, idx_max] = max(counts);
peak_center = (edges(idx_max) + edges(idx_max+1)) / 2;  % in units of 100 ps

% -------- 5. 時間差換算為距離（m） ----------
c = 3e8;  % m/s
delta_t_sec = peak_center * 1e-10;  % 100 ps -> s
distance_m = c * delta_t_sec / 2;

fprintf('Histogram 峰值時間差中心 = %.2f ×100 ps\n', peak_center);
fprintf('估測距離 ≈ %.3f m\n', distance_m);

% -------- 6. 畫圖（histogram + 標記峰值） ----------
figure('Units','normalized','Position',[0.15 0.2 0.6 0.55]);
histogram(dt_valid, edges, 'FaceAlpha', 0.85);
xlabel('Time difference \Delta t (×100 ps)');
ylabel('Counts');
title(sprintf('LiDAR Time Difference Histogram (valid pairs: %d, missing: %d)\\nEstimated distance = %.3f m', ...
    num_valid, num_missing, distance_m));
grid on;

% 在圖上畫峰值位置
hold on;
ymax = max(counts) * 1.05;
xline(peak_center, '--r', sprintf('Peak = %.2f (×100 ps)\\n%.3f m', peak_center, distance_m), ...
    'LabelOrientation','horizontal','LineWidth',1.5);
ylim([0 ymax]);
hold off;

% -------- 7. 若需要，將有效時間差存檔（選用） ----------
saveOption = true;
if saveOption
    writematrix(dt_valid, 'part1_dt_valid_ps.txt'); % 單位: ×100ps
    fprintf('已將有效的 Δt (×100ps) 存為 part1_dt_valid_ps.txt\n');
end