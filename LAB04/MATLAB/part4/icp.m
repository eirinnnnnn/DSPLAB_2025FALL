meta1 = parse_depth_meta('part3_full_Depth_metadata.csv');
meta2 = parse_depth_meta('part3_full_left_Depth_metadata.csv');
meta3 = parse_depth_meta('part3_full_right_Depth_metadata.csv');
scale = 1e-3;         % mm → m (adjust if yours is already meters)
flipY = true;         % so MATLAB Y is "up" visually

[D1, ~] = readZ16Raw('part3_full_Depth.raw', meta1.W, meta1.H);
[D2, ~] = readZ16Raw('part3_full_left_Depth.raw', meta2.W, meta2.H);
[D3, ~] = readZ16Raw('part3_full_right_Depth.raw', meta3.W, meta3.H);

pc1 = depthToPC(D1, meta1, scale, flipY);
pc2 = depthToPC(D2, meta2, scale, flipY);
pc3 = depthToPC(D3, meta3, scale, flipY);

% (Optional) crop to a region where all views overlap
roi = [-1 1 -1 1 0.2 3];   % [xmin xmax ymin ymax zmin zmax] (meters)
pc1 = select(pc1, findPointsInROI(pc1, roi));
pc2 = select(pc2, findPointsInROI(pc2, roi));
pc3 = select(pc3, findPointsInROI(pc3, roi));

% Remove outliers (radius or statistical)
pc1 = pcdenoise(pc1,'NumNeighbors',24,'Threshold',1);
pc2 = pcdenoise(pc2,'NumNeighbors',24,'Threshold',1);
pc3 = pcdenoise(pc3,'NumNeighbors',24,'Threshold',1);

% Voxel downsample for faster/robust ICP
voxel = 0.01;  % 1 cm voxels
f1 = pcdownsample(pc1,'gridAverage',voxel);
f2 = pcdownsample(pc2,'gridAverage',voxel);
f3 = pcdownsample(pc3,'gridAverage',voxel);

% Register f2 → f1
[t21, reg2, rmse21] = pcregistericp(f2, f1, ...
    'Metric','pointToPlane', 'InlierRatio',0.6, ...
    'MaxIterations',100, 'Tolerance',[1e-5 0.5]);

% Merge progressively and register the third to the merged model
model = pcmerge(pctransform(pc2, t21), pc1, voxel);  % high-res merge base

[t31, reg3, rmse31] = pcregistericp(f3, pcdownsample(model,'gridAverage',voxel), ...
    'Metric','pointToPlane','InlierRatio',0.6, ...
    'MaxIterations',100, 'Tolerance',[1e-5 0.5]);

% Apply transforms to original-resolution clouds
pc2_aligned = pctransform(pc2, t21);
pc3_aligned = pctransform(pc3, t31);

% Final merged cloud
merged = pcmerge(pc1, pc2_aligned, voxel);
merged = pcmerge(merged, pc3_aligned, voxel);

figure; pcshowpair(pc1, pc2_aligned); title('pc1 (cyan) vs pc2 aligned (magenta)');
figure; pcshowpair(pc1, pc3_aligned); title('pc1 (cyan) vs pc3 aligned (magenta)');

figure; pcshow(merged); title('Merged point cloud');
xlabel X; ylabel Y; zlabel Z; axis vis3d; view(3);


D_merged = pcToDepthRaw(merged, meta1, 1e-3, true);
fid = fopen('merged_from_pc.raw','w');
fwrite(fid, D_merged', 'uint16');   % transpose because we read column-major earlier
fclose(fid);
figure;
imagesc(double(D_merged) * 1e-3);   % convert mm→m for display
axis image off;
colormap(turbo); colorbar;
title('Depth map reprojected from merged point cloud');

imwrite(mat2gray(double(D_merged)), 'merged_depth_colored.png');
fprintf('Saved colored 2D depth map to merged_depth_colored.png\n');

