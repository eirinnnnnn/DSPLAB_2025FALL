% --- parameters of your depth image ---
W = 640;          % width
H = 480;          % height
fname = 'part3_full_left_Depth.raw';   % your .raw file

% --- read raw depth (uint16, little-endian) ---
fid = fopen(fname,'r');
depth = fread(fid, W*H, 'uint16=>double');   % read as double for plotting
fclose(fid);

% reshape to 2D [H x W]; raw is row-major (left→right, top→bottom)
depth = reshape(depth, [W, H]).';   % transpose to get [H x W]

% (optional) convert units, e.g. mm → m
scale = 1e-3;
depth_m = depth * scale;

% (optional) mask zeros (no return) as NaN so they show as holes
depth_m(depth_m == 0) = NaN;

% --- display as 2D depth map ---
figure;
imagesc(depth_m);         % or imagesc(depth) if you skip scaling
axis image off;           % keep aspect ratio; hide axes
colormap('jet');          % false-color like your PNG
colorbar;                 % show depth scale bar

% (optional) limit color range for better contrast
% caxis([0.3 2.5]);      % adjust to your depth range in meters
