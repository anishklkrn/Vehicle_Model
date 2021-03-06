clear all
close all
clc

% load('wheel_speeds.mat');
                              % used in initial testings with predefined
                              % generated speed of each wheel

% =========================================================================
% SIMULATION PARAMETERS
% =========================================================================
g = 9.80037;                  % [m/s^2]
SIM_TIME = 3.5;               % [s]
dt = 1e-4;                    % [s]

% =========================================================================
% PI CONTROLER PARAMETERS
% =========================================================================
                              % PI controller used to control the steering
                              % wheel steered angle
Kp = 5;
Ti = 0.08;
interrupt = 1e-3;             % [s]
                              % interrupt is used to simulate time when
                              % the controller samples and
                              % generates new output

% =========================================================================
% VEHICLE PARAMETERS of FSRA16
% Description: In simulation are used parameters for the vehicle
%              FSRA16 - Formula Student Road Arrow 2016 vehicle
% =========================================================================
L = 1600*1e-3;                % [mm] - Length 
T_front = 1250*1e-3;          % [mm] - Width of FRONT track (FRONT axel width)
T_rear = 1200*1e-3;           % [mm] - Width of REAR track (REAR axel width)
CG_height = 340*1e-3;         % [mm] - Height of CG (center of gravity)
a = 830*1e-3;                 % [mm] - Distance from CG to FRONT axel
b = 770*1e-3;                 % [mm] - Distance from CG to REAR axel

unsprung_mass = 70;
sprung_mass = 174;
driver_mass = 75;            % Estimated Driver mass for average driver
mass = sprung_mass+...
       unsprung_mass+...
       driver_mass;          % [kg]
m1_s = mass*(b/L)/2;         % [kg]
m2_s = mass*(b/L)/2;         % [kg]
m3_s = mass*(a/L)/2;         % [kg]
m4_s = mass*(a/L)/2;         % [kg]
max_steer = 135;             % [deg]
max_steerSpeed = 540;        % [deg/s] - estimated driver's speed of steering 
max_Dsteer = max_steerSpeed*dt;

% =========================================================================
% ENGINE PARAMETERS
% =========================================================================
max_speed = 135;            % [km/h] - Projected vehicle's max speed of FSRA16
accel_max = 10*dt;          % [m/s^2 * dt]
speed_max = 137.8;          % [kmh]
brake_max = 20*dt;          % [m/s^2 * dt] 

% =========================================================================
% TYRE PARAMETERS
% Description: FSRA16 uses Avon tires and parameters of these tires are
%              stored in the additional file tire_Avon.mat
%              This file is generated according to the datasheet from tire
%              manufacturer. In following lines, the data had to be
%              interpolated since the data from the datasheet has big
%              steps in the table review of tire's performances.
% =========================================================================
load('tire_Avon.mat');

sliped = -tire_Avon(:,2);
lateralLoaded = tire_Avon(:,3).*1e3;

slipAngle = -12:1e-3:12;
lateralLoad = interp1(sliped,lateralLoaded,slipAngle,'pchip');
C_alpha = (2.7778/2)*1e-03; % [N/deg]
WHEEL_DIAMETER = 0.33/2;

beta_FL = 0;
beta_FR = 0;
beta_RL = 0;
beta_RR = 0;

% =========================================================================
% DOUBLE LANE CHANGE TEST  %
% Description: Test is performed at the speed of 80 km/h and maintains that
%              speed along the test
% =========================================================================
speed = 80;        % [km/h]
steer = 0;
psi = 0;

% Generating control reference parameters for different test parts
% PART 1 - first straight
[orientationVector timeVector] = generateOrientation(0,0,0,0.34,dt,'step');
% PART 2 - steering to the left
[orientationVector timeVector] = ...
        generateOrientation(orientationVector,timeVector,18,0.55,dt,'ramp');
% PART 3 - going straight before turning right to enter into second lane
[orientationVector timeVector] = ...
        generateOrientation(orientationVector,timeVector,18,0.065,dt,'step');
% PART 4 - steering to the right to enter second lane
[orientationVector timeVector] = ...
        generateOrientation(orientationVector,timeVector,0,0.55,dt,'ramp');
% PART 5 - second straight
[orientationVector timeVector] = ...
        generateOrientation(orientationVector,timeVector,0,0.06,dt,'step');
% PART 6 - steering to the right, exiting second straight
[orientationVector timeVector] = ...
        generateOrientation(orientationVector,timeVector,-14,0.55,dt,'ramp');
% PART 7 - going straight before turning left to enter into first lane
[orientationVector timeVector] = ...
        generateOrientation(orientationVector,timeVector,-14,0.05,dt,'step');
% PART 8 - steering to the left to enter first lane again
[orientationVector timeVector] = ...
        generateOrientation(orientationVector,timeVector,0,0.55,dt,'ramp');
% PART 9 - vehicle returned to the first lane, going straight again
[orientationVector timeVector] = ...
        generateOrientation(orientationVector,timeVector,0,.45,dt,'step');

% Mass distribution on each wheel
m1 = m1_s; % Front left
m2 = m2_s; % Front rigth
m3 = m3_s; % Rear left
m4 = m4_s; % Rear right

% =========================================================================
% Packing all parameters into one vector variable
% Description: 
%   >> vehicle parameters    - length, width, CG, masses, orientation
%   >> simulation parameters - initial steering position, max speed, max
%                              speed of steering...
%   >> tire parameters       - sleep angle of each wheel
%                               (FL - front left; FR - front right)
%                               (RL - rear left; RR - rear right)
%   >> wheel location        - initial location of CG and vehicle
%                              orientation
% =========================================================================
vehicle_Params = [L T_front T_rear CG_height a b mass m1_s m2_s m3_s m4_s psi];
sym_Params = [steer(1) speed max_steer max_speed C_alpha g dt];
tire_Params = [beta_FL beta_FR beta_RL beta_RR];
wheel_location = [-a,0];
     
% =========================================================================
% INIT START LOCATION  
% Description: Calculate initial position of center of gravity (CG), car
%              center (CC), position of each wheel
%
% NOTICE:      Movement is placed only in xy-plane ! ! !
% =========================================================================
x_CG(1) = 0;
y_CG(1) = 0;

x_CC(1) = -b*cos(psi(1));
y_CC(1) = -b*sin(psi(1));

x_FR(1) = x_CG(1)+sqrt(a^2+(T_front/2)^2)*cos(psi(1)-atan((T_front/2)/a));
y_FR(1) = y_CG(1)+sqrt(a^2+(T_front/2)^2)*sin(psi(1)-atan((T_front/2)/a));

x_RR(1) = x_CG(1)-b*cos(psi(1))+(T_rear/2)*sin(psi(1));
y_RR(1) = y_CG(1)-b*sin(psi(1))-(T_rear/2)*cos(psi(1));

x_FL(1) = x_FR(1)-T_front*sin(psi(1));
y_FL(1) = y_FR(1)+T_front*cos(psi(1));

x_RL(1) = x_RR(1)-T_rear*sin(psi(1));
y_RL(1) = y_RR(1)+T_rear*cos(psi(1));

d_psi = 0;      sigma_CG = 0;

m1 = m1_s;      m2 = m2_s;
m3 = m3_s;      m4 = m4_s;

dm_longitudinal = [0; 0];
dm_lateral = [0; 0];

FL_speed = 0;
FR_speed = 0;
RL_speed = 0;
RR_speed = 0;
wheel_speeds = [FL_speed' FR_speed' RL_speed' RR_speed'];

acp_CG = 0;  acp_psi = 0;  

% =========================================================================
% START SIMULATION
% Description: For specific angles and orientations refer to the figure of
%              car model -> (../Figures/Vehicle_angles_newFont.png)
% =========================================================================
time = 0;
e = [];         % car orientation error in comparison to the reference
u = [];         % steering control
lastState = 0;
for position = 1:length(timeVector)
    if((mod(timeVector(position),interrupt))==0)
        e(position) = round((orientationVector(position)-psi(position)*180/pi)*1e4)/1e4;
        u(position) = Kp*e(position)+Kp*dt*e(position)/Ti;
%         u(position) = e(position);

        % ! ! ! Notice ! ! !
        % Always saturate max steering angle and steering angle speed
        if(position>1)
            if(u(position)>0 && u(position-1)>0 &&...
               u(position)-u(position-1)>max_Dsteer)

                u(position) = u(position-1)+max_Dsteer;
            else if(u(position)>0 && u(position-1)>0 &&...
                    u(position)-u(position-1)<-max_Dsteer)
                      u(position) = u(position-1)-max_Dsteer;
                 end
            end
            if(u(position)<0 && u(position-1)<0 &&...
               u(position)-u(position-1)<-max_Dsteer)

                u(position) = u(position-1)-max_Dsteer;
            else if(u(position)<0 && u(position-1)<0 &&...
                    u(position)-u(position-1)>max_Dsteer)
                      u(position) = u(position-1)+max_Dsteer;
                 end
            end

            if(u(position)>0 && u(position-1)<0 &&...
               u(position)-u(position-1)>max_Dsteer)

                u(position) = u(position-1)+max_Dsteer;
            else if(u(position)<0 && u(position-1)>0 &&...
                    u(position)-u(position-1)<-max_Dsteer)
                      u(position) = u(position-1)-max_Dsteer;
                 end
            end
        else
            if(u(position)>max_Dsteer)
                u(position) = max_Dsteer;
            else if(u(position)<-max_Dsteer)
                    u(position) = -max_Dsteer;
                 end
            end
        end

        if(u(position)>135)
            u(position) = 135;
        else if(u(position)<-135)
                u(position) = -135;
             end
        end
    else
        e(position) = e(position-1);
        u(position) = Kp*e(position)+Kp*dt*e(position)/Ti;
    end
    steer = [steer; u(position)];
    
    % Store new recalculated parameters of the car 
    vehicle_Params = [L T_front T_rear CG_height a b mass m1(position) m2(position) m3(position) m4(position) psi(position)];
    sym_Params = [steer(position) speed(1) max_steer max_speed C_alpha g dt];
    tire_Params = [beta_FL(position) beta_FR(position) beta_RL(position) beta_RR(position)];
    wheel_location = [x_CG(position) y_CG(position)...
                      x_FR(position) y_FR(position)...
                      x_RR(position) y_RR(position)...  
                      x_FL(position) y_FL(position)...
                      x_RL(position) y_RL(position)];
                  
	% Move the car to the new position
    [output lastState] = wheel_move(wheel_speeds,vehicle_Params,sym_Params,tire_Params,wheel_location,slipAngle,lateralLoad,lastState); 
    
    x_FL = [x_FL; output(2,1)];     y_FL = [y_FL; output(2,7)];
    x_FR = [x_FR; output(2,2)];     y_FR = [y_FR; output(2,8)];
    x_RL = [x_RL; output(2,3)];     y_RL = [y_RL; output(2,9)];
    x_RR = [x_RR; output(2,4)];     y_RR = [y_RR; output(2,10)];
    x_CG = [x_CG; output(2,5)];     y_CG = [y_CG; output(2,11)];
    x_CC = [x_CC; output(2,6)];     y_CC = [y_CC; output(2,12)];

    psi = [psi; output(2,13)];     d_psi = [d_psi; output(2,14)];

    beta_FL = [beta_FL; output(2,15)];
    beta_FR = [beta_FR; output(2,16)]; 
    beta_RL = [beta_RL; output(2,17)]; 
    beta_RR = [beta_RR; output(2,18)];

    sigma_CG = [sigma_CG; output(2,19)]; %time = [time; output(2,20)];

    m1 = [m1; output(2,21)];      m2 = [m2; output(2,22)];
    m3 = [m3; output(2,23)];      m4 = [m4; output(2,24)];
    dm_longitudinal = [dm_longitudinal output(:,27)];
    dm_lateral = [dm_lateral -output(:,28)];
    
    FL_speed = [FL_speed output(2,29)/WHEEL_DIAMETER];
    FR_speed = [FR_speed output(2,30)/WHEEL_DIAMETER];
    RL_speed = [RL_speed output(2,31)/WHEEL_DIAMETER];
    RR_speed = [RR_speed output(2,32)/WHEEL_DIAMETER];
    wheel_speeds = [FL_speed(end) FR_speed(end) RL_speed(end) RR_speed(end)];

    acp_CG = [acp_CG; output(2,25)];  acp_psi = [acp_psi; output(2,26)];
    time = [time time(end)+dt];
end

wheel_speeds = [FL_speed' FR_speed' RL_speed' RR_speed'];

x = [x_FL x_FR x_RL x_RR x_CG x_CC];
y = [y_FL y_FR y_RL y_RR y_CG y_CC];

m = [m1 m2 m3 m4 mass.*ones(length(time),1) dm_lateral' dm_longitudinal']; % size = length(time) x (4+1+2+2)
beta = [beta_FL beta_FR beta_RL beta_RR];

vehicle_Params = [L T_front T_rear CG_height a b g speed dt];
tire_Params = [C_alpha WHEEL_DIAMETER];

orientationVector = [orientationVector; orientationVector(end)];
timeVector = [timeVector; timeVector(end)];

% Pack all the data and prepare to plot
data = [x y m beta wheel_speeds psi d_psi acp_psi acp_CG sigma_CG steer time' orientationVector timeVector];
disp(['Total time for ISO-standard test: ', num2str(max(time)),'s.']);
disp(['Distance: ', num2str(max(x_CG)),'m.']);
disp(['Max lateral G: ', num2str(max(acp_CG)/g),'G.']);

% Plot the Double Lane Change Test executed simulation 
plotData(data,vehicle_Params,tire_Params,'DLC');