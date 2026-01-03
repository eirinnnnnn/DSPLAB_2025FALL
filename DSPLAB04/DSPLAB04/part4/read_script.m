rawFile = 'part3_full_Depth.raw';
meta    = parse_depth_meta('part3_full_Depth_metadata.csv');

[D, nFrames] = readZ16Raw(rawFile, meta.W, meta.H, 1, true); % little-endian Z16
figure; imagesc(D); axis image off; colormap(turbo); colorbar;
title(sprintf('Depth (Z16), frame 1/%d', nFrames));


%% ==================
scale = 1e-3;                     % Z16 is usually mm → meters
[uu,vv] = meshgrid(0:meta.W-1, 0:meta.H-1);
Z = double(D) * scale;
mask = Z > 0;

X = (uu - meta.PPx).*Z / meta.Fx;
Y = (vv - meta.PPy).*Z / meta.Fy;

pc = pointCloud([X(mask), Y(mask), Z(mask)]);
figure; pcshow(pc); xlabel X; ylabel Y; zlabel Z;
view(0, -90)       % or tweak az, el to your liking
camup([0 -1 0])    % make 'down' on image correspond to 'up' visually

title('Reconstructed point cloud');
