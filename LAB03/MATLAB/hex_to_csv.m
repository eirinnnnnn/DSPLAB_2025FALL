% parse_imu_hex.m
% Reads lines of hyphen-separated hex bytes.
% Bytes 1–4: data numbering prefix (kept as both hex and little-endian u32).
% Starting from byte 5: six 2-byte signed little-endian values:
%   accx, accy, accz, gyrx, gyry, gyrz
% Extra trailing bytes (if any) are ignored.

% --------------- USER INPUT ---------------
infile  = 'square3_3_hex.txt';   % one frame per line, e.g.:
% FF-0F-A3-8F-52-FB-36-FF-34-41-FA-FF-10-00-00-00-00-00-FF-0F
outfile = 'square3_3.csv';
% -----------------------------------------

% Read all lines
if ~isfile(infile)
    error('Input file "%s" not found.', infile);
end
lines = strtrim(splitlines(fileread(infile)));
lines = lines(~cellfun(@isempty, lines));

% Preallocate (grow dynamically if needed)
results = struct( ...
    'prefix_hex',        "", ...
    'prefix_u32_le',     uint32(0), ...
    'accx',              int16(0), ...
    'accy',              int16(0), ...
    'accz',              int16(0), ...
    'gyrx',              int16(0), ...
    'gyry',              int16(0), ...
    'gyrz',              int16(0) );
res = repmat(results, 0, 1);

for k = 1:numel(lines)
    ln = lines{k};

    % Extract all 2-hex-digit tokens (robust against '-', spaces, commas)
    tokens = regexp(ln, '([0-9A-Fa-f]{2})', 'match');
    if isempty(tokens)
        warning('Line %d: no hex tokens found. Skipping.', k);
        continue;
    end

    % Convert to uint8 array
    b = uint8(hex2dec(upper(tokens))).';  % row vector of bytes

    if numel(b) < 4 + 12
        warning('Line %d: only %d bytes (need at least 16). Skipping.', k, numel(b));
        continue;
    end

    % ---- Prefix (first 4 bytes) ----
    prefix_bytes = b(1:4);                % [b1 b2 b3 b4]
    % store hex string of the 4 bytes:
    prefix_hex = sprintf('%02X-%02X-%02X-%02X', prefix_bytes);
    % little-endian uint32 value:
    %   u32_le = b1 + 256*b2 + 65536*b3 + 16777216*b4
    prefix_u32_le = uint32(prefix_bytes(1)) ...
                  + bitshift(uint32(prefix_bytes(2)), 8) ...
                  + bitshift(uint32(prefix_bytes(3)), 16) ...
                  + bitshift(uint32(prefix_bytes(4)), 24);

    % ---- Sensor words (next 12 bytes) ----
    data_bytes = b(5:end);
    % Take the first 12 bytes for accx..gyrz
    sensor12 = data_bytes(1:12);
    % reshape into 6 words of 2 bytes each: [lo hi] per row
    w = reshape(sensor12, 2, []).';  % 6x2

    % Combine as little-endian uint16 then reinterpret as int16
    u16 = uint16(w(:,1)) + bitshift(uint16(w(:,2)), 8);
    s16 = typecast(u16, 'int16');    % signed values

    % Map to signals
    accx = s16(1);
    accy = s16(2);
    accz = s16(3);
    gyrx = s16(4);
    gyry = s16(5);
    gyrz = s16(6);

    % Append to results
    rec = results;
    rec.prefix_hex    = string(prefix_hex);
    rec.prefix_u32_le = prefix_u32_le;
    rec.accx = accx; rec.accy = accy; rec.accz = accz;
    rec.gyrx = gyrx; rec.gyry = gyry; rec.gyrz = gyrz;
    res(end+1,1) = rec; %#ok<AGROW>
end

% Convert to table and save
T = struct2table(res);
writetable(T, outfile);

fprintf('Parsed %d frame(s). Saved to %s\n', height(T), outfile);
