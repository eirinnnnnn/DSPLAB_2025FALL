eval("serialportlist")
portName      = "COM4";    % 
baudRate      = 115200;    % 
timeoutSec    = 1;         % 

%% 
s = serialport(portName, baudRate, "Timeout", timeoutSec);
flush(s);   % 

%% 
cmd            = uint16(hex2dec('2000'));    %
bytesPerFrame  = (hex2dec('2000'))*6*2;          

%% 1. 
write(s, cmd, "uint16");
fprintf("→ Sent command: %d\n", cmd);
raw = read(s, bytesPerFrame, "uint8");
% original_raw = raw;
raw = reshape(raw,6,uint16(hex2dec('4000')));

%% 3. 
result=zeros(1,hex2dec('2000'));
tx_result=zeros(1,hex2dec('2000'));
%% 4. 
for ff=1:8192
data=squeeze(raw(:,ff));
adc0=256*data(4)+data(3);
result(1,ff)=adc0;
fprintf("← Received ADC = [%4d]\n", adc0);
end

for ff=8193:(8192*2)
data=squeeze(raw(:,ff));
adc1=256*data(4)+data(3);   
tx_result(1,ff-8192)=adc1;
fprintf("← Received ADC = [%4d]\n", adc1);

end
received_data=result.*(3.3/4096);
tx_received_data=tx_result.*(3.3/4096);

save('data_60cm_AC_ON.mat', 'received_data', 'tx_received_data');

% Number of samples
num_samples = 1:length(received_data);

% Create the plot
figure;
plot(num_samples, tx_received_data, 'DisplayName', 'TX Received Data');
hold on;
plot(num_samples, (received_data), 'DisplayName', 'Received Date');

% Formatting the plot
xlabel('Number of Samples');
ylabel('Values');
title('Received Date and TX Received Data vs. Number of Samples');
legend('show');
grid on;

% Convert datetime to numeric for plotting
% datetick('x', 'dd-mmm-yyyy', 'keepticks'); % Format x-axis for dates
hold off;
ylim([0 4])

clear s;