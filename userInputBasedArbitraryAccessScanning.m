%This program goes to any channel on the optrode array 

path(path,'./MTIDeviceMatlab'); % Add the MTIDeviceMatlab library to the path
clear; clf reset; clc;

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

answer=0;
display(' ');
display('Input channel the device should step and settle to.');
display('Program will exit when you enter 9,9');
display(' ');
while answer<=1
    s=input('Input target channel in col,row format: ','s');
    channel = sscanf(s, '%f , %f')
    Pos = getPos(channel);
    xpos = Pos(1,1);
    if xpos>1 
        break;
    end
    ypos = Pos(2,1);
    answer=max(abs(xpos),abs(ypos));
    if answer<=1
        % Go to new position with a 10ms step from current position
        tstep = 10; % Step time in ms
        mpos = 255; % Have the digital output 255 (laser on) in new pos.
        mMTIDevice.GoToDevicePosition(xpos,ypos,mpos,tstep);
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

function [Pos] = getPos(channel)
    %Channel 1,1 is top left 
    %Channel 8,8 is bottom right 
    %Pos 1,1 is bottom left
    %Pos -1,-1 is top right
    x = channel(1,1);
    y = channel(2,1);
    xmap = [1 0.7143 0.4286 0.1429 -0.1429 -0.4286 -0.7143 -1 2];
    ymap = [-1 -0.7143 -0.4286 -0.1429 0.1429 0.4286 0.7143 1 2];
    
    Pos(1,1) = xmap(1,x);
    Pos(2,1) = ymap(1,y); 
end