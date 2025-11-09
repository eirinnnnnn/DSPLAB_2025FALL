%% extract_and_decode_nrf_bytes.m
% Extracts (0x) hex byte sequences from an nRF Connect log,
% robustly locates the payload after the 0xFF 0x0F marker,
% decodes them into accelerometer and gyroscope readings,
% writes CSV, and plots the six signals.

clear; clc;

% -------- Input / output file names --------
inFile  = 'car03_202510221410.txt';   % your nRF Connect log
outFile = 'car03.csv';   % decoded numeric data

% -------- Step 1: Extract byte strings from log --------
txt = fileread(inFile);

% Matches lines like: (0x) 01-00-...-10-00
pattern = '\(0x\)\s*([0-9A-Fa-f][0-9A-Fa-f](?:-[0-9A-Fa-f][0-9A-Fa-f])*)';
tokens  = regexp(txt, pattern, 'tokens');
frames  = cellfun(@(x) x{1}, tokens, 'UniformOutput', false);

fprintf('Found %d frame(s).\n', numel(frames));

% -------- Step 2: Convert each frame to bytes & decode --------
% We look for the first 0xFF 0x0F pair, then read the next 12 bytes as:
% acc_x, acc_y, acc_z, gyro_x, gyro_y, gyro_z (each int16 little-endian).
data = [];             % will become [N x 6]
n_skipped = 0;

for i = 1:numel(frames)
    % Convert "AA-BB-..." -> uint8 vector (force ROW vector)
    hexParts = split(frames{i}, '-');        % nx1 string array
    raw      = uint8(hex2dec(hexParts)).';   % 1 x M (transpose to row)

    % Basic length guard
    if numel(raw) < 14   % minimal size to even hold FF-0F + 12 bytes
        n_skipped = n_skipped + 1;
        continue;
    end

    % Find first occurrence of the framing marker 0xFF 0x0F
    seq = double(raw);   % ensure it's a row vector for strfind
    k = strfind(seq, [255 15]);   % positions where FF 0F begins

    % Optional alternate ordering check (rare, but keep it robust)
    alt_used = false;
    if isempty(k)
        k = strfind(seq, [15 255]);
        if isempty(k)
            n_skipped = n_skipped + 1;
            continue;
        else
            alt_used = true;
        end
    end

    payload_start = k(1) + 2;   % first byte AFTER the 2-byte marker

    % We need 12 payload bytes for 6 int16 values
    if payload_start + 12 - 1 > numel(raw)
        n_skipped = n_skipped + 1;
        continue;
    end

    p = raw(payload_start : payload_start + 12 - 1);  % 1x12 payload

    % Little-endian int16 decode (low byte first, then high byte)
    acc_x  = typecast(uint16(p(1))  + bitshift(uint16(p(2)),  8), 'int16');
    acc_y  = typecast(uint16(p(3))  + bitshift(uint16(p(4)),  8), 'int16');
    acc_z  = typecast(uint16(p(5))  + bitshift(uint16(p(6)),  8), 'int16');
    gyro_x = typecast(uint16(p(7))  + bitshift(uint16(p(8)),  8), 'int16');
    gyro_y = typecast(uint16(p(9))  + bitshift(uint16(p(10)), 8), 'int16');
    gyro_z = typecast(uint16(p(11)) + bitshift(uint16(p(12)), 8), 'int16');

    data = [data; double([acc_x, acc_y, acc_z, gyro_x, gyro_y, gyro_z])]; %#ok<AGROW>
end

fprintf('Decoded %d sample(s). Skipped %d frame(s).\n', size(data,1), n_skipped);

% -------- Step 3: Write results to CSV --------
headers = {'acc_x','acc_y','acc_z','gyro_x','gyro_y','gyro_z'};
T = array2table(data, 'VariableNames', headers);
writetable(T, outFile);
fprintf('✅ Saved to %s\n', outFile);

% -------- Step 4: Plot results --------
if ~isempty(data)
    figure('Name','Accelerometer and Gyroscope Data','NumberTitle','off');

    subplot(2,1,1);
    plot(data(:,1:3), 'LineWidth', 1);
    title('Accelerometer');
    xlabel('Sample Index');
    ylabel('Raw Value');
    legend('acc\_x','acc\_y','acc\_z','Location','best');
    grid on;

    subplot(2,1,2);
    plot(data(:,4:6), 'LineWidth', 1);
    title('Gyroscope');
    xlabel('Sample Index');
    ylabel('Raw Value');
    legend('gyro\_x','gyro\_y','gyro\_z','Location','best');
    grid on;
else
    warning('No decoded samples to plot.');
end
