% --- Load depth map (.raw) ---
meta = parse_depth_meta('part3_full_Depth_metadata.csv');

[D, ~] = readZ16Raw('part3_full_Depth.raw', meta.W, meta.H, 1, true);

% [D, ~] = readZ16Raw('merged_from_pc.raw', meta.W, meta.H, 1, true);

Z = double(D) * 1e-3;   
figure; imagesc(Z); colormap(turbo); axis image off; colorbar;
title('Original depth map');


Zf = double(D);
h = fspecial('laplacian', 0);      

% convolution
L = imfilter(Zf, h, 'replicate');

% Emphasize edges
edges = abs(L);
edges = edges / max(edges(:));
figure;
imshow(edges, []);
title('Laplacian edge map (from depth)');

BW = edges > 0.01;    
figure;
imshow(BW);
title('Binary depth edges');

figure;
imshow(mat2gray(Zf)); hold on;
visboundaries(BW,'Color','r');
title('Edges overlaid on depth image');
