function R = match_lidar_tof(emit_csv, recv_csv, period, window)
%MATCH_LIDAR_TOF  Match LiDAR emit/receive timestamps into per-cycle TOF.
%   R = MATCH_LIDAR_TOF(emit_csv, recv_csv, period, window)
%   - emit_csv : path to CSV of emission times (one column)
%   - recv_csv : path to CSV of detection times (one column)
%   - period   : emission period (same units as timestamps), e.g., 1250
%   - window   : (optional) matching window length after each emit.
%                Default = period. Use < period if you gate earlier.
%
% Returns struct R with fields:
%   .tof            [Kx1] time-of-flight per emit (NaN if no return)
%   .emit_idx       [Kx1] indices into emit vector
%   .recv_idx       [Kx1] matched receive index (0 if none)
%   .num_returns    [Kx1] how many receives fell in the window
%   .hit_mask       logical, true if a receive was matched
%   .miss_mask      logical, true if no receive in window
%   .emit           emit times (sorted column)
%   .recv           receive times (sorted column)
%   .period, .window, .units (string)

    if nargin < 4 || isempty(window), window = period; end

    % --- Load CSVs robustly (headers/mixed tolerated) ---
    emit_raw = readmatrix(emit_csv);   % readtable also fine; readmatrix keeps numeric
    recv_raw = readmatrix(recv_csv);

    % Keep first numeric column if there are several
    if size(emit_raw,2) > 1, emit_raw = emit_raw(:,1); end
    if size(recv_raw,2) > 1, recv_raw = recv_raw(:,1); end

    % Clean and sort
    emit = emit_raw(~isnan(emit_raw));
    recv = recv_raw(~isnan(recv_raw));
    emit = sort(emit(:));   % column
    recv = sort(recv(:));

    K = numel(emit);
    N = numel(recv);

    tof         = nan(K,1);
    recv_idx    = zeros(K,1,'uint32');
    num_returns = zeros(K,1,'uint16');

    % Two-pointer sweep
    j = 1; % index into recv
    for k = 1:K
        t0 = emit(k);
        t1 = t0 + window;         % end of window for this cycle

        % advance j to the first receive >= t0
        while j <= N && recv(j) < t0
            j = j + 1;
        end
        if j > N
            % no more receives at all; remaining cycles are misses
            break
        end

        % Count how many receives fall within [t0, t1)
        jj = j;
        while jj <= N && recv(jj) < t1
            jj = jj + 1;
        end
        % Now receives in the window are j : jj-1 (possibly empty)

        m = (jj - j); % number of returns in the window
        num_returns(k) = m;

        if m >= 1
            % Case (1) or (3): take earliest receive in window => index j
            recv_idx(k) = j;
            tof(k)      = recv(j) - t0;

            % IMPORTANT: move j to first receive >= t1 so returns don't
            % get re-used by the next cycle.
            j = jj;
        else
            % Case (2): no returns in window => leave NaN, recv_idx=0
            % Keep j where it is; next emit may still catch future receives.
        end
    end

    hit_mask  = ~isnan(tof);
    miss_mask = isnan(tof);

    % Package results
    R = struct();
    R.tof         = tof;
    R.emit_idx    = (1:K).';
    R.recv_idx    = recv_idx;
    R.num_returns = num_returns;
    R.hit_mask    = hit_mask;
    R.miss_mask   = miss_mask;
    R.emit        = emit;
    R.recv        = recv;
    R.period      = period;
    R.window      = window;
    R.units       = "same-as-input";

    % Simple summary
    fprintf('[LiDAR] cycles: %d, hits: %d (%.1f%%), misses: %d\n', ...
        K, sum(hit_mask), 100*mean(hit_mask), sum(miss_mask));
    if any(hit_mask)
        t = tof(hit_mask);
        fprintf('  TOF stats (hits): min=%.6g  median=%.6g  mean=%.6g  max=%.6g\n', ...
            min(t), median(t), mean(t), max(t));
    end
end
