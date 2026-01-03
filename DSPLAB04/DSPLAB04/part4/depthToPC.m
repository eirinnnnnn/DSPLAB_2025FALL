function pc = depthToPC(D, meta, scale, flipY)
% D: HxW uint16 depth; meta: struct with W,H,Fx,Fy,PPx,PPy
% scale: e.g., 1e-3 for mm→m; flipY: true to make Y-up
[uu,vv] = meshgrid(0:meta.W-1, 0:meta.H-1);
Z = double(D) * scale;
mask = Z > 0;

if flipY
    Y = -(vv - meta.PPy).*Z / meta.Fy;
else
    Y =  (vv - meta.PPy).*Z / meta.Fy;
end
X = (uu - meta.PPx).*Z / meta.Fx;

pts = [X(mask), Y(mask), Z(mask)];
pc  = pointCloud(pts);
end
