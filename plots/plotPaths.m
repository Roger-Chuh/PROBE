kittiRun = '2011_09_26_drive_0005_sync';

load([kittiRun '_paths.mat']);
load([kittiRun '_probePath.mat']);
n6 = load([kittiRun '_noMore600Path.mat']);
n6w = load([kittiRun '_noMore600PathAndWeights.mat']);
lv2 = load([kittiRun '_libviso2.mat']);




figure
for p_i = 1:size(p_wcam_hist,3)
    h1 = plot(p_wcam_hist(1,:,p_i),p_wcam_hist(3,:,p_i), '-k', 'LineWidth', 1);
    hold on;
end
h2 = plot(translation(1,:),translation(3,:), '-g', 'LineWidth', 2);
h4 = plot(n6.translation(1,:),n6.translation(3,:), '-b', 'LineWidth', 2);
h5 = plot(n6w.translation(1,:),n6w.translation(3,:), '-c', 'LineWidth', 2);
h6 = plot(lv2.translation(1,:),lv2.translation(3,:), '--m', 'LineWidth', 2);
h3 = plot(p_wcam_w_gt(1,:),p_wcam_w_gt(3,:), '-r', 'LineWidth', 2);


f = strsplit(dataBaseDir, '/');
f = strsplit(char(f(end)), '.');
fileName = char(f(1));

title(sprintf('Training Runs \n %s', fileName), 'Interpreter', 'none')
xlabel('x [m]')
ylabel('z [m]')
xlim([-30 10])

legend([h1, h2, h4, h5,h6, h3], {'Training Runs', 'Probe Path','Exclude Right Side', 'Exclude Right Side + Probe','libviso2','Ground Truth'})
grid on;
addpath('/Users/valentinp/Research/MATLAB/export_fig'); %Use Oliver Woodford's awesome export_fig package to get trimmed PDFs
export_fig(gcf, sprintf('%s_comp.pdf', kittiRun), '-transparent');

%Plot error and variances
transErr = zeros(3, size(translation,2));
transErrN6 = zeros(3, size(translation,2));
transErrN6W = zeros(3, size(translation,2));
transErrlv2 = zeros(3, size(translation,2));


for i = 1:size(T_wcam_hist,3)
    transErr(:,i) = translation(1:3, i) - p_wcam_w_gt(:,i);
    transErrN6(:,i) = n6.translation(1:3, i) - p_wcam_w_gt(:,i);
    transErrN6W(:,i) = n6w.translation(1:3, i) - p_wcam_w_gt(:,i);   
    transErrlv2(:,i) = lv2.translation(1:3, i) - p_wcam_w_gt(:,i);   
end
meanRMSE = mean(sqrt(sum(transErr.^2,1)/3))
meanRMSEN6 = mean(sqrt(sum(transErrN6.^2,1)/3))
meanRMSEN6W = mean(sqrt(sum(transErrN6W.^2,1)/3))
meanRMSELV2 = mean(sqrt(sum(transErrlv2.^2,1)/3))

norm(transErr(:,end))
norm(transErrN6(:,end))
norm(transErrN6W(:,end))
norm(transErrlv2(:,end))

