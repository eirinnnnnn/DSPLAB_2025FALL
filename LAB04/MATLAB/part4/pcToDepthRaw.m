function [D_raw] = pcToDepthRaw(pc, meta, scale, flipY)
% Project scattered XYZ back into a Z16-style depth map.
% pc     : MATLAB pointCloud (merged)
% meta   : struct with W,H,Fx,Fy,PPx,PPy
% scale  : e.g., 1e-3 for mm→m   (use same as before)
% flipY  : whether you flipped Y earlier

W = meta.W;
H = meta.H;

pts = pc.Location;
X = pts(:,1);  Y = pts(:,2);  Z = pts(:,3);
valid = Z>0 & isfinite(Z);

if flipY
    Y = -Y;  % undo flip so that image row index grows downward
end

% Project to pixel coords
u = meta.Fx .* (X ./ Z) + meta.PPx;
v = meta.Fy .* (Y ./ Z) + meta.PPy;

% Round to nearest integer pixel coordinates
u = round(u);  v = round(v);

% Keep those within image bounds
mask = valid & u>=1 & u<=W & v>=1 & v<=H;
u = u(mask);  v = v(mask);  Z = Z(mask);

% Initialize image with NaN, fill using nearest (keep nearest point in Z)
D = nan(H, W);
linInd = sub2ind([H,W], v, u);
for k = 1:numel(linInd)
    idx = linInd(k);
    if isnan(D(idx)) || Z(k) < D(idx)
        D(idx) = Z(k);
    end
end

% Convert back to uint16 in millimeters
D_raw = uint16(D / scale);
end
