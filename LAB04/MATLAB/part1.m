%% part1_hist_bin_sweep_blue.m
clear; clc; close all;

%% -------------------- 1. 讀檔 --------------------------
emit = readmatrix('part1_emit_times_ps.csv');
recv = readmatrix('part1_receive_times_ps.csv');

emit = emit(:);
recv = recv(:);
recv_valid = recv(~isnan(recv));

%% -------------------- 2. 計算每個 emit 對應最早 recv --------------------------
Nemit = numel(emit);
dt = NaN(Nemit,1);

if numel(recv)==Nemit
    tmp = recv - emit;
    tmp(~isfinite(tmp) | tmp<=0) = NaN;
    dt = tmp;
else
    recv_sorted = sort(recv_valid);
    rIdx = 1;
    nRecv = numel(recv_sorted);

    for i = 1:Nemit
        e = emit(i);
        if ~isfinite(e), continue; end

        while rIdx <= nRecv && recv_sorted(rIdx) <= e
            rIdx = rIdx + 1;
        end

        if rIdx <= nRecv
            dt(i) = recv_sorted(rIdx) - e;
        end
    end
end

%% -------------------- 3. 有效 dt --------------------------
valid_mask = isfinite(dt) & dt > 0;
dt_valid = dt(valid_mask);

fprintf("有效 dt = %d, 缺失 = %d\n", sum(valid_mask), sum(~valid_mask));

if isempty(dt_valid)
    error("沒有有效的 dt，無法畫 histogram");
end

%% -------------------- 4. bin sweep --------------------------
bin_list = [500, 700, 900, 1100, 1500];  % 五種 bin ≥ 500

figure('Units','normalized','Position',[0.05 0.05 0.9 0.85]);

for i = 1:length(bin_list)

    nbins = bin_list(i);
    edges = linspace(0, 1250, nbins+1);

    subplot(3,2,i);
    h = histogram(dt_valid, edges);
    h.FaceColor = [0 0.45 0.95];   % 藍色
    h.EdgeColor = 'none';         % 去邊框比較好看

    title(sprintf("Bin = %d", nbins));
    xlabel("Δt (×100 ps)");
    ylabel("Counts");
    grid on;
end
% -------- 新增：時間差換算成距離（使用 histogram centroid） ----------
edges = linspace(0, 1250, num_bins+1);
[counts, ~] = histcounts(dt_valid, edges);

[~, idx_max] = max(counts);
peak_center = (edges(idx_max) + edges(idx_max+1)) / 2;  % 單位：×100ps

c = 3e8;  % m/s
delta_t_sec = peak_center * 1e-10;  % 100ps → 秒
distance_m = c * delta_t_sec / 2;

fprintf('Histogram peak time = %.2f ×100ps\n', peak_center);
fprintf('Estimated distance = %.3f m\n', distance_m);