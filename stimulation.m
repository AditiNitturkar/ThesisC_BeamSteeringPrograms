%This program enables users to stimulate specific channels of an MOA
%Specify channel numbers to loop through and time per channel
%- the arduino program can specify
%the frequency, pulse width, etc. (so make sure time per channel
%corresponds to that)

%LED should be in external control mode
%Arduino stimulation should be loaded

path(path,'./MTIDeviceMatlab'); % Add the MTIDeviceMatlab library to the path
clear; clc;

%%%%%%%%%Change these variables%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
channelOrder = 1:5;
target_freq = 5; %Hz of the pulses at a channel (max 10Hz)
pulse_width = 0.5; %ratio of on to off (min 0.5ms to 1ms) 
num_of_pulses = 10; %at a given channel
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

a = arduino(); %Create arduino object

% Create an object of the MTIDevice class
mMTIDevice = MTIDevice;

try
mMTIDevice.ConnectDevice(); % Easiest way (no argument) will autoconnect 

% Then we can check if connection is successful
err = mMTIDevice.GetLastError();
if (err ~= MTIError.MTI_SUCCESS)
    disp('Failed to connect. Error returned is:');
    disp(err);
    mMTIDevice.DisconnectDevice();
    delete(mMTIDevice);
    return;
end

mMTIDevice.ResetDevicePosition(); % Send mirror to origin and zero offsets
lParams = mMTIDevice.LoadDeviceParams('mtidevice.ini');
mMTIDevice.SetDeviceParams(lParams);
version = mMTIDevice.GetAPIVersion();
params = mMTIDevice.GetDeviceParams();
DisplayVersionAndKeyParams();

% Any additional parameters can be set directly as follows:
% This overrides any previously set parameters
mMTIDevice.SetDeviceParam( MTIParam.DataScale, 1.0 );
mMTIDevice.SetDeviceParam( MTIParam.SampleRate, 20000 );
err = mMTIDevice.GetLastError();
% Turn MEMS driver on
mMTIDevice.SetDeviceParam( MTIParam.MEMSDriverEnable, 1 )
%mMTIDevice.SetDeviceParam( MTIParam.DigitalOutputEnable, 1);

%fix up the freq
stim_freq = 1/(1/target_freq-0.09)


display(' ');
display('Program will exit automatically. Do not exit manually');
display(' ');
answer = 0;
runs = 1;
for j = 1:runs
    for i = 1:length(channelOrder)
        Pos = getPos(channelOrder(i));
        xpos = Pos(1,1);
        if xpos>1 
            break;
        end
        ypos = Pos(1,2);
        answer=max(abs(xpos),abs(ypos));
        if answer<=1
            % Go to new position with a 10ms step from current position
            disp("New Point");
            tstep = 100; % Step time in ms
            mpos = 0; %
            mMTIDevice.GoToDevicePosition(xpos,ypos,mpos,tstep);
            %once here, use arduino pin to generate signal 
            for p = 1:(num_of_pulses+1)
                writeDigitalPin(a, 'D13', 1);
                pause(1.0/stim_freq*pulse_width); %sec
                writeDigitalPin(a, 'D13', 0);
                pause(1.0/stim_freq*(1-pulse_width)); %sec
            end   
        else
            break;
        end
    end

end

% Return device to origin and close the session nicely
mMTIDevice.ResetDevicePosition();
% After the device is back to origin - disable the driver
mMTIDevice.SetDeviceParam( MTIParam.MEMSDriverEnable, 0 );
% Disconnect and delete the object
mMTIDevice.DisconnectDevice();
delete(mMTIDevice);
display('Closed successfully..');

catch
    display('Application failed to run properly!');
    mMTIDevice.ClearInputBuffer();
    mMTIDevice.DisconnectDevice();
    delete(mMTIDevice);
    display('Closed in final catch..');
end

function [Pos] = getPos(num)
    %COnverts from 1:64 to pairs
    channel(1,1) = floor(num/8)+1;
    if (mod(num,8) == 0) 
        channel(1,1) = floor(num/8); %divisible by 8 so won't start from 0
    end
    channel(1,2) = mod(num,8);
    if channel(1,2) == 0
        channel(1,2) = 8;
    end
    %Channel 1,1 is top left 
    %Channel 8,8 is bottom right 
    %Pos 1,1 is bottom left
    %Pos -1,-1 is top right
    x = channel(1,1);
    y = channel(1,2);
    xmap = [1 0.7143 0.4286 0.1429 -0.1429 -0.4286 -0.7143 -1 -2];
    ymap = [-1 -0.7143 -0.4286 -0.1429 0.1429 0.4286 0.7143 1 2];
    
    Pos(1) = xmap(x);
    Pos(2) = ymap(y); 
end

function [wOffset] = getWOffset(pos)
    if (pos == 1)
        wOffset = pos - 0.001;
    elseif (pos == -1)
        wOffset = pos + 0.001;
    else 
        wOffset = pos + 0.001;
    end
end

%%%%%%%%%%%%%%% ARDUINO CODE %%%%%%%%%%%%%%%%
%If you want it on without pulses, use Arduino digital trigger read

% void setup() {
%   // put your setup code here, to run once:
%   pinMode(2, INPUT);
%   pinMode(13,OUTPUT);
%   Serial.begin(9600);
% }
% 
% void loop() {
%   //Pin2 is dout0, reads 1 when on 
%   if (digitalRead(2) == 1) {
%     digitalWrite(13,HIGH);
%   } else if (digitalRead(2) == 0) {
%     digitalWrite(13,LOW);
%   }
% }

%If you want pulsed, use the below function. Note that you need to manually
%match the freq, pulse width and number of pulses in the arduino

