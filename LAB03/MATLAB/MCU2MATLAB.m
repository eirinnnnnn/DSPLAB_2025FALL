portName   = "COM4";
baudRate   = 115200;
timeoutSec = 2;

s = serialport(portName, baudRate, "Timeout", timeoutSec);
flush(s);

cmd         = uint16(hex2dec('5A'));  
frameLength = 16;                     
write(s, cmd, "uint16");
fprintf("→ Sent command: %d\n", cmd);


result = [];

fprintf("→ 開始接收資料... 按 Ctrl+C 可中止接收\n");

try
    while true
        raw = read(s, frameLength, "uint8");

        acc_x  = typecast(uint16(raw(5))  + bitshift(uint16(raw(6)),  8), 'int16');
        acc_y  = typecast(uint16(raw(7))  + bitshift(uint16(raw(8)),  8), 'int16');
        acc_z  = typecast(uint16(raw(9))  + bitshift(uint16(raw(10)),  8), 'int16');
        gyro_x = typecast(uint16(raw(11))  + bitshift(uint16(raw(12)), 8), 'int16');
        gyro_y = typecast(uint16(raw(13)) + bitshift(uint16(raw(14)), 8), 'int16');
        gyro_z = typecast(uint16(raw(15)) + bitshift(uint16(raw(16)), 8), 'int16');

        newRow = [acc_x, acc_y, acc_z, gyro_x, gyro_y, gyro_z];
        result = [result; newRow];  

        fprintf("← SAMPLE %3d | ACC = [%6d, %6d, %6d], GYRO = [%6d, %6d, %6d]\n", ...
            size(result, 1), acc_x, acc_y, acc_z, gyro_x, gyro_y, gyro_z);
    end
catch
    fprintf("→ 使用者中止接收，總共接收到 %d 筆資料。\n", size(result, 1));
end

clear s;