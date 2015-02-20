clear all;
close all;
disp('===========================');
addpath('libviso2');
addpath('utils');
addpath('learning');


addpath('~/Dropbox/PhD/Code/MATLAB/matlab_rosbag-0.4-mac64/');
rosBagFileName = '/Users/valentinp/Desktop/Pioneer-VI/2015-02-18-12-24-23.bag';

%Set up topics
viRightCamTopic = '/right/image_rect';
viLeftCamTopic = '/left/image_rect';
imuTopic = '/imu0';

%Load the bag
bag = ros.Bag.load(rosBagFileName);
bag.info()
bagImageRightVIData = bag.readAll({viRightCamTopic});
bagImageLeftVIData = bag.readAll({viLeftCamTopic});
viLeftcalib = bag.readAll({'/cam0/camera_info'}); %right
viRightcalib = bag.readAll({'/cam1/camera_info'}); %left
bagImuData = bag.readAll({imuTopic});

viImageSize = [752 480];

data = load('datasets/2015-01-28-16-11-17_1loop.mat');
param.f     = data.fu;
param.cu    = data.cu;
param.cv    = data.cv;
param.base  = data.b;
first_frame = 1;
calibParams.c_u = data.cu;
calibParams.c_v = data.cv;
calibParams.f_u = data.fu;
calibParams.f_v = data.fv;
calibParams.b = data.b;
last_frame  = length(bagImageRightVIData)-5;

%Set up IMU to Cam transform
p_ci_i = [0.0602131703928; -0.00145860604554; -0.0465617957282];
R_ic = rotmat_from_quat([0.999996930467 -5.44616859609e-05 0.00246256274859 -0.000268097157994]');
R_ci = R_ic';
T_camimu = [R_ci -R_ci*p_ci_i; 0 0 0 1];


%%
% demonstrates sparse scene flow (quad matching = 2 consecutive stereo pairs)
% matching parameters
param.nms_n                  = 2;   % non-max-suppression: min. distance between maxima (in pixels)
param.nms_tau                = 50;  % non-max-suppression: interest point peakiness threshold
param.match_binsize          = 50;  % matching bin width/height (affects efficiency only)
param.match_radius           = 200; % matching radius (du/dv in pixels)
param.match_disp_tolerance   = 1;   % du tolerance for stereo matches (in pixels)
param.outlier_disp_tolerance = 5;   % outlier removal: disparity tolerance (in pixels)
param.outlier_flow_tolerance = 5;   % outlier removal: flow tolerance (in pixels)
param.multi_stage            = 1;   % 0=disabled,1=multistage matching (denser and faster)
param.half_resolution        = 1;   % 0=disabled,1=match at half resolution, refine at full resolution
param.refinement             = 0;   % refinement (0=none,1=pixel,2=subpixel)

%% Setup
addpath('settings');
R = diag(25*ones(4,1));
optParams.RANSACCostThresh = 0.05;
optParams.RANSACMaxIterations = round(log(1-0.999)/log(1-(1-0.5)^3));
optParams.maxGNIter = 10;
optParams.lineLambda = 0.75;
optParams.LMlambda = 1e-5;
%% Extract IMU timestamps
%Subtract gravity
imuData = NaN(6, length(bagImuData));
imuDataTimeStamps = NaN(1, length(bagImuData));
for imu_i=1:length(bagImuData)
    imuDataTimeStamps(imu_i) = bagImuData{imu_i}.header.stamp.time;
    imuData(:, imu_i) = [bagImuData{imu_i}.linear_acceleration; bagImuData{imu_i}.angular_velocity];
end

%%
%create figure
figure('Color',[1 1 1]);
ha1 = axes('Position',[0.05,0.7,0.9,0.25]);

axis off;
ha2 = axes('Position',[0.05,0.05,0.9,0.6]);
axis equal, grid on, hold on;
% gt = load('2015-02-13-18-28-05-1loop_GroundTruth.mat');
% plot(gt.p_camw_w_gt(1,:), gt.p_camw_w_gt(3,:),'-k');

%%
repeatIter =  1;
meanRMSEHist = [];
for repeat_i = 1:repeatIter
rng('shuffle');
% init matcher
matcherMex('init',param);

% push back first images
I1 = uint8(reshape(bagImageLeftVIData{first_frame}.data, viImageSize(1), viImageSize(2))');
I2 = uint8(reshape(bagImageRightVIData{first_frame}.data, viImageSize(1), viImageSize(2))');
I1 = I1(1:478, :);
I2 = I2(1:478, :);
matcherMex('push',I1,I2); 
previousViTime = bagImageLeftVIData{first_frame}.header.stamp.time;
xInit.p = zeros(3,1);
xInit.v = zeros(3,1);
xInit.b_g = zeros(3,1);
xInit.b_a = zeros(3,1);
xInit.q = [1; zeros(3,1)];
xState = xInit;
 
k =1;
T_wcam = eye(4);
T_wcam_hist = T_wcam;

for frame=first_frame+1:1:last_frame
  
  
  % read current images
   I1 = uint8(reshape(bagImageLeftVIData{frame}.data, viImageSize(1), viImageSize(2))');
   I2 = uint8(reshape(bagImageRightVIData{frame}.data, viImageSize(1), viImageSize(2))');

     
   I1 = I1(1:478, :);
   I2 = I2(1:478, :);
   
 
   %IMU data
   currentViTime = bagImageLeftVIData{frame}.header.stamp.time;
   imuMask = imuDataTimeStamps >= previousViTime & imuDataTimeStamps < currentViTime;
   imuDataWindowTimeStamps = imuDataTimeStamps(imuMask);
   previousViTime = currentViTime;
   imuDataWindow = imuData(:, imuMask);
   xPrevState = xState; 
   for imusub_i = 2:size(imuDataWindow,2)
        dt = imuDataWindowTimeStamps(imusub_i) - imuDataWindowTimeStamps(imusub_i-1);
        [xState] = integrateIMU(xState, imuDataWindow(1:3, imusub_i-1), imuDataWindow(4:6, imusub_i-1), dt, zeros(3,1));
   end
   
   C_21_imu_est = rotmat_from_quat(xState.q)'*rotmat_from_quat(xPrevState.q);
   C_21_est = T_camimu(1:3,1:3)*C_21_imu_est*T_camimu(1:3,1:3)';

   
    matcherMex('push',I1,I2); 
    % match images
    matcherMex('match',2);
    p_matched = matcherMex('get_matches',2);

    % showMatchedFeatures(I1, I2, p_matched(1:2,:)', p_matched(3:4,:)');
    % drawnow;

    %Triangulate points and prune any at Infinity
    numFts = 25;
         
    if size(p_matched,2) > numFts
        selectIdx = randperm(size(p_matched,2), numFts);
    else
        selectIdx = 1:size(p_matched,2);
    end
    p_matched = p_matched(:,selectIdx);
    [p_f1_1, p_f2_2] = triangulateAllPointsDirect(p_matched, calibParams);
    %[predVectors] = computePredVectors( p_matched(1:2,:), I1, imuDataWindow(:,end));
    
      %Show image
%    axes(ha1); cla;
%    imagesc(I1);
%    axis off; colormap(gray);
    
     pruneId = isinf(p_f1_1(1,:)) | isinf(p_f1_1(2,:)) | isinf(p_f1_1(3,:)) | isinf(p_f2_2(1,:)) | isinf(p_f2_2(2,:)) | isinf(p_f2_2(3,:));
     p_f1_1 = p_f1_1(:, ~pruneId);
     p_f2_2 = p_f2_2(:, ~pruneId);
 

    %Find inliers based on rotation matrix from IMU
    [p_f1_1, p_f2_2, T_21_est] = findInliersRot(p_f1_1, p_f2_2, C_21_est, optParams,calibParams);
    %T_21_est = scalarWeightedPointCloudAlignment(p_f1_1, p_f2_2, C_21_est);
    fprintf('Tracking %d features. \n', size(p_f1_1,2));
   
    %Calculate initial guess using scalar weights, then use matrix weighted
    %non linear optimization
    
    if size(p_f1_1, 2) > 4
        R_1 = repmat(R, [1 1 size(p_f1_1, 2)]);
        R_2 = R_1;
        T_21_opt = matrixWeightedPointCloudAlignment(p_f1_1, p_f2_2, R_1, R_2, T_21_est, calibParams, optParams);
    else
        T_21_opt = eye(4);
    end
        
    T_wcam = T_wcam*inv(T_21_opt);
    T_wcam_hist(:,:,end+1) = T_wcam;
    
    % update trajectory
%          axes(ha2);
%         plot(T_wcam(1,4),T_wcam(3,4),'b*');
%          hold on;
%          grid on;
%          drawnow();
        k = k + 1;
        fprintf('k:%d, repeat_i: %d \n',k,repeat_i);
end

% close matcher
matcherMex('close');
end
%%
f = strsplit(rosBagFileName, '/');
f = strsplit(char(f(end)), '.');
fileName = char(f(1));
save(['groundtruth/' fileName '_VIO.mat'], 'T_wcam_hist');
%%
addpath('groundtruth/');
figure
translation = NaN(3, size(T_wcam_hist, 3));
for i = 1:size(T_wcam_hist, 3)
    T_wcam =  T_wcam_hist(:, :, i);
    translation(:,i) = T_wcam(1:3, 4);
end
plot(translation(1,:), translation(3,:),'-g', 'LineWidth', 2);
grid on;
hold on;

rtk_data = load('/Users/valentinp/Desktop/Pioneer-VI/GPS/rover1_rtk.mat');

[R,T] = icp(translation,rtk_data.xyz');

rtk_registered = R*rtk_data.xyz';

%plot3(rtk_data.xyz(:,1),rtk_data.xyz(:,2), rtk_data.xyz(:,3),'-k', 'LineWidth', 2);
plot(rtk_registered(1,:), rtk_registered(3,:),'-k', 'LineWidth', 2);
title(fileName);
xlabel('Right [m]');
ylabel('Forward [m]');
legend('VIO', 'RTK GPS', 'Location','NorthWest');

saveas(gcf, ['groundtruth/' fileName '_VIOandGPS.fig']);

% %Plot error and variances
% transErrVec = zeros(3, size(T_wcam_hist,3));
% for i = 1:size(T_wcam_hist,3)
%     transErrVec(:,i) = translation(:, i) - rtk_registered(:,i);
% end
% meanRMSE = mean(sqrt(sum(transErrVec.^2,1)/3));

