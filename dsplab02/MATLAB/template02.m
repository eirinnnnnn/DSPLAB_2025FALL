eval("serialportlist")
clear
portName      = "COM4";    % 
baudRate      = 115200;    % 
timeoutSec    = 1;         % 

%% 

s = serialport(portName, baudRate, "Timeout", timeoutSec);
flush(s);   % 

hhex = '2000';
%% 
cmd            = uint16(hex2dec(hhex));    %
bytesPerFrame  = (hex2dec(hhex ))*10;         

%% 1. 
% while(1) 
write(s, cmd, "uint16");
fprintf("→ Sent command: %d\n", cmd);

raw = read(s, bytesPerFrame, "uint8");
original_raw = raw;
raw = reshape(raw,10,uint16(hex2dec(hhex)));


%% 3. 
% result=zeros(1,hex2dec('2000'));
%% 4. 
for ff=1:hex2dec(hhex )
data=squeeze(raw(:,ff));

adc3=256*data(8)+data(7);


result(1,ff)=adc3;

fprintf("← Received ADC = [%4d]\n", adc3);
% fprintf("← Received ADC = [%4d]\n", adc1);

end
received_data=result.*(3.3/4096);
% save('ecgsignal_move.mat', 'received_data');
% clear s;


% figure(1);
% % dist = (1+324+141:8192+324+141)/160000*170*100;
% dist = (1:8192)/160000*170*100;
plot(1:hex2dec(hhex),received_data);
ylim([0 3.3]);
% end



