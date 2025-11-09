filename = 'x_minus.txt';


lines = readlines(filename);
lines = strtrim(lines);        
lines(lines=="") = [];        
num_lines = numel(lines);

data = zeros(num_lines,6);  % 每行存 [acc_x acc_y acc_z gyro_x gyro_y gyro_z]

for k = 1:num_lines

    hex_vals = strsplit(lines(k),'-');
    
    % 中間 6 組數據
    bytes_middle = hex_vals(5:16);  
    
    for i = 1:6
        low_byte  = hex2dec(bytes_middle{2*i-1});
        high_byte = hex2dec(bytes_middle{2*i});
        val = bitor(low_byte, bitshift(high_byte,8));  % 組成 16-bit
        
        % 二補數轉換
        if val >= 2^15
            val = val - 2^16;
        end
        data(k,i) = val;
    end
end

disp(data);