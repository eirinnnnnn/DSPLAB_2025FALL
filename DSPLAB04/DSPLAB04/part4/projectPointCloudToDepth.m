function D = projectPointCloudToDepth(pc, meta, scale, flipY)

W = meta.W;
H = meta.H;

XYZ = pc.Location;
X = XYZ(:,1);
Y = XYZ(:,2);
Z = XYZ(:,3);

% Flip Y back to camera convention (image row increases downward)
if flipY
    Y = -Y;
end

% Only keep valid points
valid = (Z > 0) & isfinite(Z);

X = X(valid);
Y = Y(valid);
Z = Z(valid);

% Apply projection: 3D → pixel coords
u = meta.Fx .* (X ./ Z) + meta.PPx;
v = meta.Fy .* (Y ./ Z) + meta.PPy;

% Round to pixel indices
u = round(u);
v = round(v);

% Keep only pixels inside image
mask = (u >= 1 & u <= W & v >= 1 & v <= H);
u = u(mask);
v = v(mask);
Z = Z(mask);

% Create depth image (take nearest depth if multiple points fall on same pixel)
D = inf(H, W);
lin = sub2ind([H, W], v, u);
for k = 1:numel(lin)
    if Z(k) < D(lin(k))
        D(lin(k)) = Z(k);
    end
end

% Missing pixels = 0 depth
D(D == inf) = 0;

% Convert to uint16 Z16-style
D = uint16(D / scale);

end
