%% Run all two-stage model analyses
%
% This is a wrapper script that runs the two-stage model fit for the
% production of fit results and figures for the melaSquint papers.
%

%% Housekeeping
clear
close all

%% Discomfort

% Announce
fprintf('\nFitting the discomfort data, all parameters free...\n\n');

% Fit the discomfort data
[~, figHandle2] = fitTwoStageModel('modality','discomfort','rngSeed',1000);
% Save figure 2
print(figHandle2, '~/Desktop/discomfort_params.pdf', '-dpdf', '-fillpage')

% Announce
fprintf('\nFitting the discomfort data, locking Stage 1...\n\n');

% Re-fit the discomfort data, locking the first two parameters
x0 = [0.6323, 1.7488, 1, 1];
lb = [0.6323, 1.7488, 0, -10];
ub = [0.6323, 1.7488, Inf, 10];
figHandle1 = fitTwoStageModel('modality','discomfort','x0',x0,'lb',lb,'ub',ub,'rngSeed',1000);
% Save figure 1
print(figHandle1, '~/Desktop/discomfort_fit.pdf', '-dpdf', '-fillpage')


%% Pupil

% Announce
fprintf('\nFitting the pupil data, all parameters free...\n\n');

% Fit the pupil data
[~, figHandle2] = fitTwoStageModel('modality','pupil','rngSeed',1000);
% Save figure 2
print(figHandle2,'~/Desktop/pupil_params.pdf', '-dpdf', '-fillpage')

% Announce
fprintf('\nFitting the pupil data, locking all params...\n\n');

% Re-fit the pupil data, locking all parameters
x0 = [0.4152, 0.8292, 0.1296, -0.1512];
lb = [0.4152, 0.8292, 0.1296, -0.1512];
ub = [0.4152, 0.8292, 0.1296, -0.1512];
figHandle1 = fitTwoStageModel('modality','pupil','x0',x0,'lb',lb,'ub',ub,'nBoots',2,'rngSeed',1000);
% Save figure 1
print(figHandle1, '~/Desktop/pupil_fit.pdf', '-dpdf', '-fillpage')


%% EMG

% Announce
fprintf('\nFitting the EMG data, all parameters free...\n\n');

% Fit the EMG data
[figHandle1, figHandle2] = fitTwoStageModel('modality','emg','responseMetric', 'normalizedPulseAUC', 'rngSeed',1000);
% Save figures
print(figHandle1, '~/Desktop/emg_fit.pdf', '-dpdf', '-fillpage')
print(figHandle2, '~/Desktop/emg_params.pdf', '-dpdf', '-fillpage')


%% Blink

% Announce
fprintf('\nFitting the blink data, all parameters free...\n\n');

% Fit the blink data
[figHandle1, figHandle2] = fitTwoStageModel('modality','blinks', 'rngSeed',1000);
% Save figures
print(figHandle1, '~/Desktop/blinks_fit.pdf', '-dpdf', '-fillpage')
print(figHandle2, '~/Desktop/blinks_params.pdf', '-dpdf', '-fillpage')

% Re-fit, constraining the first two params
x0 = [0.2933, 1.3333, 5, 20];
lb = [0.2933, 1.3333, 0, 0];
ub = [0.2933, 1.3333, Inf, Inf];
figHandle1 = fitTwoStageModel('modality','blinks','x0',x0,'lb',lb,'ub',ub,'rngSeed',1000);
% Save figure 1
print(figHandle1, '~/Desktop/blinks_fit.pdf', '-dpdf', '-fillpage')



