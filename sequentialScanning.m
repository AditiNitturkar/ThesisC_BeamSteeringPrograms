%This program takes in a desired frequency and mode (zigzag, rectangular)
%and drives the beam across all 64 channels at that frequency indefinitely
%until terminated. 
%LED should be in constant current mode

clear; clf; clc;

%%%%%%%%%%%%%%%%%%%%%%Change these variables%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
frequency = 1; %Hz (1 frame = 64 channels). 
mode = 1; %1 is zigzag, 0 is rectangular
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

path(path,'./MTIDeviceMatlab'); % Add the MTIDeviceMatlab library to the path

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
%Load parameters
lParams = mMTIDevice.LoadDeviceParams('mtidevice.ini');
mMTIDevice.SetDeviceParams(lParams);
version = mMTIDevice.GetAPIVersion();
params = mMTIDevice.GetDeviceParams();
DisplayVersionAndKeyParams();

% Any additional parameters can be set directly as follows:
% This overrides any previously set parameters
mMTIDevice.SetDeviceParam( MTIParam.DataScale, 1.0 );
rate = 20000;
mMTIDevice.SetDeviceParam( MTIParam.SampleRate, rate );
err = mMTIDevice.GetLastError();
% Turn MEMS driver on
mMTIDevice.SetDeviceParam( MTIParam.MEMSDriverEnable, 1 )
%mMTIDevice.SetDeviceParam( MTIParam.DigitalOutputEnable, 1);

display(' ');
display('Program will exit automatically. Do not exit manually');
display(' ');

channelOrder = getChannelOrder(mode);

%Now get the points to repeat movement 
if (frequency > 2000)
    frequency = 2000; 
end
if (frequency < 0.01)
    frequency = 0.01;
end
[x,y,m] = getDataStream(mode, frequency, rate);
adjustModulationDelay = 1;

disp('Starting now');
%Send the coordinates to move to
mMTIDevice.SendDataStream(x,y,m,length(x),adjustModulationDelay,1); % Send data to Controller and run automatically

disp('Press any key to stop the device');
pause;

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

function [channelOrder] = getChannelOrder(mode) 
    if (mode == 1)
        %zigzag
        channelOrder = [1,8,9,16,17,24,25,32,33,40,41,48,49,56,57,64,49,56,41,48,33,40,25,32,17,24,9,16,1]; 
    elseif (mode == 0)
        %rectangular
        channelOrder = [1,8,16,9,17,24,32,25,33,40,48,41,49,56,64,57,49,56,48,41,33,40,32,25,17,24,16,9,1]; 
    else 
        %Get from start to first point
        channelOrder = [1];
    end
end

function [x, y, m] = getDataStream(mode, frequency, rate)
    channelOrder = getChannelOrder(mode);
    totalPoints = round(rate * 2 / frequency,0);
    if (length(channelOrder) == 1) 
        %In mode x, finding the starting pos 
        src_x = 0;
        src_y = 0;
        pointsPerJump = round(rate * 0.1,0);
        if pointsPerJump == 0
            pointsPerJump = 50;
        end
        x = zeros(pointsPerJump,1);
        y = zeros(pointsPerJump,1);
        m = uint8(zeros(pointsPerJump,1));
    else
        disp('Entering non init mode');
        %In all other modes, starting from channel 1
        pos = getPos(1);
        src_x = pos(1);
        src_y = pos(2);
        
        x = zeros(totalPoints,1);
        y = zeros(totalPoints,1);
        m = uint8(zeros(totalPoints,1));
        pointsPerJump = round(totalPoints / length(channelOrder),0);
    end
    j = 1;
    for i = 1:length(channelOrder)
        %For each point, get pointsPerJump points between it and the next
        %point
        pos = getPos(channelOrder(i));
        dest_x = pos(1);
        dest_y = pos(2);
        x(j : j + pointsPerJump - 1) = linspace(src_x, dest_x, pointsPerJump);
        y(j : j + pointsPerJump - 1) = linspace(src_y, dest_y, pointsPerJump);
        m(i : i + pointsPerJump - 1) = uint8(255);
        if (length(channelOrder) == 1)
            %In the starting mode, turn m off
            m(i : i + pointsPerJump - 1) = uint8(0);
        end
        src_x = dest_x;
        src_y = dest_y;
        j = j + pointsPerJump;
    end 
    disp('Gotten all of the x, y, m points successfully');
    x = x(1:length(m));
    y = y(1:length(m));
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
