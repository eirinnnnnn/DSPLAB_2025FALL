period = 1250;                 % your stated period
R = match_lidar_tof('part1_emit_times_ps.csv','part1_receive_times_ps.csv', period);          % window = period
% or, if you want a tighter gate (e.g., 0.6*period):
% R = match_lidar_tof('emit.csv','recv.csv', period, 0.6*period);

% Access TOF series (NaN where missed):
tof = R.tof;

% Optional: histogram of valid TOFs
valid = ~isnan(tof);
figure; histogram(tof(valid), 100); xlabel('TOF'); ylabel('count'); title('TOF histogram');

% Optional: per-cycle plot (emit vs matched receive)
figure; 
plot(R.emit, 'o'); hold on;
idx = R.recv_idx; idx(idx==0) = 1;   % avoid 0 for indexing, not plotted
matched_recv_times = nan(size(R.emit));
hit = R.hit_mask;
matched_recv_times(hit) = R.emit(hit) + R.tof(hit);
plot(matched_recv_times, '.'); 
legend('emit','matched recv'); ylabel('time'); xlabel('cycle');
title('Per-cycle earliest return');
