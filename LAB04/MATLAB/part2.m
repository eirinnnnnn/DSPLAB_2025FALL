%% Part2: 3x3 bin/window comparison (no best window)
clear; clc;

%% ---------- 讀檔並建立 ToF ----------
emit = readmatrix('part2_emit_times_ps.csv'); emit = emit(~isnan(emit));
recv = readmatrix('part2_receive_times_ps.csv'); recv = recv(~isnan(recv));
emit = sort(double(emit(:)),'ascend'); recv = sort(double(recv(:)),'ascend');
Ne = numel(emit);

% 同步：對每個接收事件取最近且不晚於它的發射事件
idx_prev_emit = interp1(emit, 1:Ne, recv, 'previous', NaN);
valid = ~isnan(idx_prev_emit);
idx_prev_emit = idx_prev_emit(valid);
recv_valid = recv(valid);

dt_100ps = recv_valid - emit(idx_prev_emit);
in_range = (dt_100ps >= 0) & (dt_100ps <= 1250);
dt_100ps = dt_100ps(in_range);
idx_prev_emit = idx_prev_emit(in_range);

min_dt_per_emit = accumarray(idx_prev_emit(:), dt_100ps(:), [Ne 1], @min, NaN);
tof = min_dt_per_emit(~isnan(min_dt_per_emit));

%% ---------- 參數設定 ----------
bin_counts = [500, 1000, 1500];    % 三種 bin 數
fixed_windows = [21, 31, 41];      % 三種 window
c = 299792458;

%% ---------- 準備圖與 summary（只有 9 組） ----------
figure('Name','Part2: 3x3 bin/window comparison','Units','normalized','Position',[0.05 0.05 0.9 0.85]);

Summary = table('Size',[9 7], ...
    'VariableTypes', {'double','double','double','double','double','double','double'}, ...
    'VariableNames', {'Bin','Window','Delta_t_100ps','FWHM_100ps','PeakSum','Density','Distance_m'});

plot_idx = 1;

for ib = 1:length(bin_counts)
    nbins = bin_counts(ib);
    edges = linspace(0,1250,nbins+1);
    bin_width = edges(2)-edges(1);
    counts = histcounts(tof, edges);
    centers = edges(1:end-1) + diff(edges)/2;

    for j = 1:length(fixed_windows)
        W = fixed_windows(j);
        if mod(W,2)==0, W = W+1; end
        if W > nbins
            error('Window %d too large for nbins=%d', W, nbins);
        end

        [dt_star_100ps, fwhm_100ps, mov_sum, iMax] = calc_centroid(counts, centers, W, bin_width);
        peakSum = max(mov_sum);
        density = peakSum / W;

        dt_star_sec = dt_star_100ps * 100e-12;
        d_est_m = c * dt_star_sec / 2;

        Summary(plot_idx,:) = {nbins, W, dt_star_100ps, fwhm_100ps, peakSum, density, d_est_m};

        subplot(3,3,plot_idx);
        plot_histogram(counts, centers, W, iMax, dt_star_100ps, fwhm_100ps, nbins, W);

        plot_idx = plot_idx + 1;
    end
end

%% ---------- 顯示 summary ----------
disp('==== Summary of 3x3 bin-window combos ====');
disp(Summary);

%% ==================== Local functions ====================
function [dt_star_100ps, fwhm_100ps, mov_sum, iMax] = calc_centroid(counts, centers, W, bin_width)
    win = ones(W,1);
    mov_sum  = conv(counts, win, 'valid');
    mov_wsum = conv(counts .* centers, win, 'valid');
    centroid = mov_wsum ./ max(mov_sum,1);
    [~, iMax] = max(mov_sum);
    dt_star_100ps = centroid(iMax);

    % FWHM
    half_max = mov_sum(iMax)/2;
    idx_above = find(mov_sum >= half_max);
    if isempty(idx_above)
        fwhm_bins = 0;
    else
        fwhm_bins = idx_above(end) - idx_above(1) + 1;
    end
    fwhm_100ps = fwhm_bins * bin_width;
end

function plot_histogram(counts, centers, W, iMax, dt_star_100ps, fwhm_100ps, nbins, window_display)
    bar(centers, counts, 1, 'EdgeColor','none'); grid on;
    xlim([0 1250]);
    xlabel('\Delta t (100 ps)'); ylabel('Count');
    title(sprintf('Bins=%d, W=%d', nbins, window_display));
    hold on;

    x_left = centers(iMax);
    x_right = centers(iMax + W - 1);
    ymax = max(counts) * 1.05;
    patch([x_left x_right x_right x_left], [0 0 ymax ymax], [0.85 0.85 1], 'FaceAlpha',0.25,'EdgeColor','none');

    text(x_left + 1, ymax*0.9, sprintf('\\Deltat*=%.1f, FWHM=%.1f', dt_star_100ps, fwhm_100ps), ...
         'FontSize',8,'Color','r');

    hold off;
end