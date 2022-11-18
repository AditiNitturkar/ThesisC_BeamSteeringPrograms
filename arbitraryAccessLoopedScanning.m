%This program stores a variable that contains the channels that the 
%mirror needs to stimulate at. The program loops through this list
%repeatedly until terminated. 

path(path,'./MTIDeviceMatlab'); % Add the MTIDeviceMatlab library to the path
clear; clf reset; clc;

%%%%%%%%%%%%%%%%Edit these variables%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
runs = 3;
%Channels are 1-64
%channelOrder = [1:64,63:-1:2]; %to scan with stops at each channel and back the same path
%channelOrder = [1,4,2,6,34]; %random scan, repeat it runs times
channelOrder = [1,8,9,16,17,24,25,32,33,40,41,48,49,56,57,64]; %linear scan with zigzags
%channelOrder = [1,8,16,9,17,24,32,25,33,40,48,41,49,56,64,57]; %linear scan with rectangle traversal
timePause = 0.1; % sec
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%plotter for path
figure;
plot(1,1,'ko');
hold on;
plot(1,4,'ko');
%
% Create an object of the MTIDevice class
mMTIDevice = MTIDevice;

try
%mMTIDevice.ConnectDevice('COM3'); % Fastest way to connect if device COM port is known
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

% Now apply new device parameters as desired by user at beginning of the session
% It is recommended to load the Mirrorcle-provided ini file for a
% specific device and set those parameters
lParams = mMTIDevice.LoadDeviceParams('mtidevice.ini');
mMTIDevice.SetDeviceParams(lParams);

% Get API version info and key parameters to display for user
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

display(' ');
display('Program will cycle through the channels set once');
display('Program will exit automatically. Do not exit manually');
display(' ');
answer = 0;
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
            tstep = 0; % Step time in ms
            mpos = 255; % Have the digital output 255 (laser on) in new pos.
            mMTIDevice.GoToDevicePosition(xpos,ypos,mpos,tstep);
            pause(timePause);
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