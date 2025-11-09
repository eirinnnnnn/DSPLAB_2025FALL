%% nrf_extract_hex_and_dec.m
% Parse an nRF Connect log, extract each (0x) frame, collapse I/A duplicate pairs,
% and decode the payload into 6 little-endian int16 values (acc_x/y/z, gyro_x/y/z).
%
% INPUT:   a text log like the snippet you pasted
% OUTPUTS: 
%   - frames_hex.txt        : one hex frame per line (post I/A dedup)
%   - frames_decoded.csv    : table with hex frame + decoded int16 fields
%
% Notes:
%   * Payload format assumed: first marker 0xFF 0x0F, then 12 payload bytes:
%       [axL axH ayL ayH azL azH gxL gxH gyL gyH gzL gzH] (little-endian int16)
%   * If a frame lacks the marker or 12 payload bytes after it, it is skipped.

clear; clc;

inFile  = 'square3_3.txt';      % <-- put your log filename here
hexOut  = 'square3_3_hex.txt';
csvOut  = 'square3_3.csv';

%% 1) Read text & extract all (0x) ... hex strings in order
txt = fileread(inFile);

% Generic matcher for "(0x) AA-BB-...-ZZ" everywhere in the file
pat_frames = '\(0x\)\s*([0-9A-Fa-f][0-9A-Fa-f](?:-[0-9A-Fa-f][0-9A-Fa-f])*)';
tokens     = regexp(txt, pat_frames, 'tokens');      % cell of 1x1 cells
all_hex    = cellfun(@(c)c{1}, tokens, 'UniformOutput', false);

fprintf('Found %d (0x) hex frames in the text.\n', numel(all_hex));

%% 2) Collapse I/A duplicate pairs (often the next line repeats the same bytes)
% Keep 1st occurrence of any consecutive duplicates; preserve order
dedup_hex = {};
dedup_hex = [dedup_hex, all_hex(~[false, strcmp(all_hex(2:end), all_hex(1:end-1))])]; %#ok<AGROW>

fprintf('After collapsing I/A pairs: %d unique frames.\n', numel(dedup_hex));

%% 3) Decode each frame: find marker FF-0F, then take the next 12 bytes as payload
n = numel(dedup_hex);
acc_x = []; acc_y = []; acc_z = [];
gyro_x = []; gyro_y = []; gyro_z = [];
kept_hex = {};           % hex strings we successfully decoded
skipped  = 0;

for i = 1:n
    hs  = dedup_hex{i};
    raw = hexstr_to_uint8_row(hs);           % 1 x M uint8

    % Find the first 0xFF 0x0F marker
    k = strfind(double(raw), [255 15]);
    if isempty(k)
        % (fallback: check 0x0F 0xFF just in case)
        k = strfind(double(raw), [15 255]);
        if isempty(k)
            skipped = skipped + 1;
            continue;
        end
    end
    payload_start = k(1) + 2;                 % first byte after the 2-byte marker

    % Need 12 payload bytes (for 6 int16)
    if payload_start + 12 - 1 > numel(raw)
        skipped = skipped + 1;
        continue;
    end

    p = raw(payload_start : payload_start+12-1);  % 1x12

    % Little-endian int16 pairs
    ax = typecast(uint16(p(1))  + bitshift(uint16(p(2)),  8), 'int16');
    ay = typecast(uint16(p(3))  + bitshift(uint16(p(4)),  8), 'int16');
    az = typecast(uint16(p(5))  + bitshift(uint16(p(6)),  8), 'int16');
    gx = typecast(uint16(p(7))  + bitshift(uint16(p(8)),  8), 'int16');
    gy = typecast(uint16(p(9))  + bitshift(uint16(p(10)), 8), 'int16');
    gz = typecast(uint16(p(11)) + bitshift(uint16(p(12)), 8), 'int16');

    acc_x(end+1,1)  = double(ax); %#ok<SAGROW>
    acc_y(end+1,1)  = double(ay); %#ok<SAGROW>
    acc_z(end+1,1)  = double(az); %#ok<SAGROW>
    gyro_x(end+1,1) = double(gx); %#ok<SAGROW>
    gyro_y(end+1,1) = double(gy); %#ok<SAGROW>
    gyro_z(end+1,1) = double(gz); %#ok<SAGROW>

    kept_hex{end+1,1} = hs; %#ok<SAGROW>
end

fprintf('Decoded %d frame(s). Skipped %d malformed/non-payload frames.\n', numel(kept_hex), skipped);

%% 4) Write outputs
% 4a) Raw hex frames (post-dedup) — one per line
fid = fopen(hexOut, 'w');
for i = 1:numel(kept_hex)
    fprintf(fid, '%s\n', kept_hex{i});
end
fclose(fid);
fprintf('Wrote hex frames to %s\n', hexOut);

% 4b) Decoded CSV: hex + 6 int16
T = table( string(kept_hex), acc_x, acc_y, acc_z, gyro_x, gyro_y, gyro_z, ...
    'VariableNames', {'hex_frame','acc_x','acc_y','acc_z','gyro_x','gyro_y','gyro_z'});
writetable(T, csvOut);
fprintf('Wrote decoded values to %s\n', csvOut);

%% 5) (Optional) quick sanity print for the first few rows
disp(T(1:min(5,height(T)), :));

%% ----------------- helpers -----------------
function row = hexstr_to_uint8_row(hs)
% Convert "AA-BB-...-ZZ" (hex pairs with dashes) to a 1xM uint8 row.
    parts = split(strtrim(hs), '-');   % string array
    row   = uint8(hex2dec(parts)).';   % transpose to force row vector
end
