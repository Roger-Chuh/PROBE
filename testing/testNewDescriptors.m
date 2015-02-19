% demonstrates sparse optical flow
disp('===========================');
clear; close all;
addpath('../libviso2');
addpath('../learning');
% matching parameters
param.nms_n                  = 1;   % non-max-suppression: min. distance between maxima (in pixels)
param.nms_tau                = 50;  % non-max-suppression: interest point peakiness threshold
param.match_binsize          = 10;  % matching bin width/height (affects efficiency only)
param.match_radius           = 10; % matching radius (du/dv in pixels)
param.match_disp_tolerance   = 1;   % du tolerance for stereo matches (in pixels)
param.outlier_disp_tolerance = 5;   % outlier removal: disparity tolerance (in pixels)
param.outlier_flow_tolerance = 5;   % outlier removal: flow tolerance (in pixels)
param.multi_stage            = 1;   % 0=disabled,1=multistage matching (denser and faster)
param.half_resolution        = 0;   % 0=disabled,1=match at half resolution, refine at full resolution
param.refinement             = 0;   % refinement (0=none,1=pixel,2=subpixel)

% read images from file
%main1 = imread('/Volumes/STARSExFAT/KITTI/2011_09_26/2011_09_26_drive_0096_sync/image_00/data/0000000000.png');
%main2 = imread('/Volumes/STARSExFAT/KITTI/2011_09_26/2011_09_26_drive_0096_sync/image_00/data/0000000001.png');

 main1 = imread('/Users/valentinp/Desktop/KITTI/2011_09_26/2011_09_26_drive_0005_sync/image_00/data/0000000008.png');
 main2 = imread('/Users/valentinp/Desktop/KITTI/2011_09_26/2011_09_26_drive_0005_sync/image_00/data/0000000009.png');


% init matcher
matcherMex('init',param);

% push back images
matcherMex('push',main1);
matcherMex('push',main2);
matcherMex('match',0);
p_matched_global = matcherMex('get_matches',0);
% close matcher
matcherMex('close');
U = p_matched_global(3,:) - p_matched_global(1,:);
V = p_matched_global(4,:) - p_matched_global(2,:);
global_mean = mean(sqrt(sum([U.^2; V.^2])));
    

imshow(main2);
hold on;

binSize = 60;

for u=1:binSize:size(main1,2)-binSize
    for v = 1:binSize:size(main1,1)-binSize
        
    I1p = main1(v:v+binSize, u:u+binSize);
    I1c = main2(v:v+binSize, u:u+binSize);



%I1p = rgb2gray(imread('/home/geiger/test_data/2013_04_29_drive_0018_extract/image_03/data/0000000336.png'));
%I1c = rgb2gray(imread('/home/geiger/test_data/2013_04_29_drive_0018_extract/image_03/data/0000000337.png'));


% init matcher
matcherMex('init',param);

% push back images
matcherMex('push',I1p);
matcherMex('push',I1c);
matcherMex('match',0);
p_matched = matcherMex('get_matches',0);

% close matcher
matcherMex('close');



%Compute divergence
U = p_matched(3,:) - p_matched(1,:);
V = p_matched(4,:) - p_matched(2,:);

bm = blurMetric(I1c);
ent = entropy(I1c);

Ig = fft2(double(I1c));
Iglf = Ig(1:binSize/5,1:binSize/5);
Ighf = Ig(end-binSize/5:end,end-binSize/5:end);
Iglf = mean(log(abs(Iglf(:))));
Ighf = mean(log(abs(Ighf(:))));

if ~isempty(U)
    predictor = mean(sqrt(sum([U.^2; V.^2])))/global_mean
else
    predictor = 0
end
    text(u+binSize/2,v+binSize/2,sprintf('%.1f',predictor), 'Color', 'r') 
    text(u+binSize/2,v+binSize/2+10,sprintf('%.1f',Ighf), 'Color', 'g') 
    
    end
end

% 
% divergence(X,Y,U,V)
%%
%%# Read an image
I = main1;
Ig = fft2(double(I));
Iglf = Ig(1:50,1:50);
Ighf = Ig(end-50:end,end-50:end);
mean(log(abs(Iglf(:))))
mean(log(abs(Ighf(:))))
