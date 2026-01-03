function [D, nFrames] = readZ16Raw(fname, W, H, frameIdx, littleEndian)
% READZ16RAW  Read a Z16 (uint16) depth frame from a raw stream.
%   D         : H×W uint16 depth image
%   nFrames   : total frames in the file (inferred)
%
% Usage:
%   [D,n] = readZ16Raw('depth.raw',640,480,1,true);

if nargin < 5, littleEndian = true; end
mach = tern(littleEndian, 'ieee-le', 'ieee-be');

bytesPerPix = 2;
pixPerFrame = W*H;
bytesPerFrame = pixPerFrame*bytesPerPix;

info = dir(fname);
if isempty(info), error('File not found: %s', fname); end
if mod(info.bytes, bytesPerFrame) ~= 0
    warning('File size is not a multiple of one frame; check W/H.');
end
nFrames = floor(info.bytes / bytesPerFrame);
if nargin < 4 || isempty(frameIdx), frameIdx = 1; end
if frameIdx < 1 || frameIdx > nFrames
    error('frameIdx out of range (1..%d)', nFrames);
end

fid = fopen(fname, 'r', mach);
cleanup = onCleanup(@() fclose(fid));
fseek(fid, (frameIdx-1)*bytesPerFrame, 'bof');
raw = fread(fid, [W H], 'uint16=>uint16');  % read as W×H in row-order
D = raw.';                                  % transpose: make H×W

end

function y = tern(cond, a, b)
if cond, y = a; else, y = b; end
end
