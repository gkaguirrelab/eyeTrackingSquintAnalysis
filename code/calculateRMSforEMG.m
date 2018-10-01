function [ medianRMS, trialStruct ] = calculateRMSforEMG(subjectID, varargin)

% Analyzes a single subject's EMG data from the OLApproach_Squint,
% SquintToPulse Experiment
%
% Syntax:
%  [ medianRMS, trialStruct ] = calculateRMSforEMG(subjectID)

% Description:
%   This function analyzes the EMG data from the OLApproach_Squint
%   Experiment, ultimately providing the root mean square (RMS) over the
%   designated squint window. Basically we first figure out how many
%   sessions a given subject has completed. Then we loop over each trial
%   and calculate the RMS over the designated window for each trial, and
%   compile that result according to stimulus type and contrast level. The
%   median RMS value across all trials, as well as the confidence interval
%   bounds, are outputted as well.

%   A couple of words on our chosen EMG metric, root mean square: We define
%   a window 1s after the stimulus onset until 1s after stimulus offset.
%   This window was chosen based on work by Stringham and colleagues
%   ('Action spetrcum for photophobia'). Within this window, we calculate
%   the square root of the sum of the squared voltage values. We then take
%   the median value across all trials for each stimulus type.

% Inputs:
%	subjectID             - A string describing the subjectID (e.g.
%                           MELA_0121) to be analyzed)

% Optional Key-Value Pairs:
%   windowOnset           - A number identifying the timepoint
%                           corresponding to the beginning of our squint
%                           window. The default is 2.5 s, which corresponds
%                           to 1 s after the stimulus is presented (both
%                           EMG and pupil data begin recording 1.5 s prior
%                           to stimulus onset, so 2.5 - 1.5 = 1 s).
%   windowOffset          - A number identifying the timepoint
%                           correspodning to the end of our squint window.
%                           The default is 6.5 s, which corresponds to 1 s
%                           after the stimulus offset (the stimulus is
%                           presented for 4 s)
%   makePlots             - A logical that controls plotting behavior. If
%                           set to true, plots showing the basic contrast
%                           response function are saved out in the
%                           subject's folder found in MELA_analysis
%   confidenceInterval    - A vector of length 1x2 that provides the
%                           percentile bounds for the confidence interval
%                           saved as part of the medianRMS struct

% Outputs:
%   medianRMS             - A 3x1 structure, where each subfield
%                           corresponds to the stimulus type (LMS,
%                           Melanopsin, or Light flux). Each subfield is
%                           itself a 9x1 structure, with each nested
%                           subfield named after the contrast levels (100%,
%                           200%, and 400%) and whether the content refers
%                           to the median value, or confidence interval
%                           boundary. The ultimate value contained is the
%                           root-mean square
%  trialStruct            - A nested structure similar in format to
%                           averageResponseStruct, where the first layer
%                           describes the stimulus type and second layer
%                           describes the contrast level. The innermost
%                           layer, however, is a vector containing the
%                           RMS from each trial


%% collect some inputs
p = inputParser; p.KeepUnmatched = true;
p.addParameter('makePlots',false,@islogical);
p.addParameter('windowOnset',2.5,@isnumeric);
p.addParameter('windowOffset',6.5,@isnumeric);
p.addParameter('confidenceInterval', [10 90], @isnumeric);
p.addParameter('sessions', {}, @iscell);

% Parse and check the parameters
p.parse(varargin{:});


%% Find the data
analysisBasePath = fullfile(getpref('melSquintAnalysis','melaAnalysisPath'), 'Experiments/OLApproach_Squint/SquintToPulse/DataFiles/', subjectID);
dataBasePath = getpref('melSquintAnalysis','melaDataPath');

% figure out the number of completed sessions
potentialSessions = dir(fullfile(dataBasePath, 'Experiments/OLApproach_Squint/SquintToPulse/DataFiles', subjectID, '*session*'));
potentialNumberOfSessions = length(potentialSessions);

% initialize outputStruct
stimuli = {'Melanopsin', 'LMS', 'LightFlux'};
contrasts = {100, 200, 400};
for ss = 1:length(stimuli)
    for cc = 1:length(contrasts)
        trialStruct.(stimuli{ss}).(['Contrast', num2str(contrasts{cc})]).left = [];
        trialStruct.(stimuli{ss}).(['Contrast', num2str(contrasts{cc})]).right = [];
    end
end

if isempty(p.Results.sessions)
sessions = [];
for ss = 1:potentialNumberOfSessions
    acquisitions = [];
    for aa = 1:6
        trials = [];
        for tt = 1:10
            if exist(fullfile(dataBasePath, 'Experiments/OLApproach_Squint/SquintToPulse/DataFiles', subjectID, potentialSessions(ss).name, sprintf('videoFiles_acquisition_%02d', aa), sprintf('trial_%03d.mp4', tt)), 'file');
                trials = [trials, tt];
            end
        end
        if isequal(trials, 1:10)
            acquisitions = [acquisitions, aa];
        end
    end
    if isequal(acquisitions, 1:6)
        sessions = [sessions, ss];
    end
end

numberOfCompletedSessions = sessions;
% get session IDs
sessionIDs = [];
for ss = numberOfCompletedSessions
    potentialSessions = dir(fullfile(dataBasePath, 'Experiments/OLApproach_Squint/SquintToPulse/DataFiles', subjectID, sprintf('*session_%d*', ss)));
    % in the event of more than one entry for a given session (which would
    % happen if something weird happened with a session and it was
    % restarted on a different day), it'll grab the later dated session,
    % which should always be the one we want
    for ii = 1:length(potentialSessions)
        if ~strcmp(potentialSessions(ii).name(1), 'x')
            sessionIDs{ss} = potentialSessions(ii).name;
        end
    end
end
else
   sessionIDs = p.Results.sessions; 
   numberOfCompletedSessions = 1:length(sessionIDs);
end


%% Load in the data for each session
for ss = numberOfCompletedSessions
    sessionNumber = strsplit(sessionIDs{ss}, 'session_');
    sessionNumber = sessionNumber{2};
    for aa = 1:6
        acquisitionData = load(fullfile(dataBasePath, 'Experiments/OLApproach_Squint/SquintToPulse/DataFiles', subjectID, sessionIDs{ss}, sprintf('session_%d_StP_acquisition%02d_emg.mat', str2num(sessionNumber),aa)));
        stimulusData = load(fullfile(dataBasePath, 'Experiments/OLApproach_Squint/SquintToPulse/DataFiles', subjectID, sessionIDs{ss}, sprintf('session_%d_StP_acquisition%02d_base.mat', str2num(sessionNumber),aa)));
        
        if p.Results.makePlots
            figure;
        end
        
        voltages = [];
        for tt = 1:10
            
            if tt ~= 1 % we're discarding the first trial of each acquisition
                % assemble packet
                trialData.response.timebase = acquisitionData.responseStruct.data(tt).emg.timebase;
                trialData.response.values.right = acquisitionData.responseStruct.data(tt).emg.response(1,:);
                trialData.response.values.left = acquisitionData.responseStruct.data(tt).emg.response(2,:);
                
                % center the voltages at 0. we've noticed that for whatever
                % reason, the baseline EMG results are not centered around
                % 0, but are in fact shifted a bit negative. even more
                % confusing, this is worse for the left EMG leads relative
                % to the right. centering at 0 should take care of this
                
                trialData.response.values.right = trialData.response.values.right - mean(trialData.response.values.right);
                trialData.response.values.left = trialData.response.values.left - mean(trialData.response.values.left);

                
                if p.Results.makePlots
                    subplot(2,5,tt)
                    hold on
                    plot(trialData.response.timebase, trialData.response.values.right);
                    plot(trialData.response.timebase, trialData.response.values.left);
                end
                
                % calculate RMS for the trial
                onsetIndex = find(trialData.response.timebase == p.Results.windowOnset);
                offsetIndex = find(trialData.response.timebase == p.Results.windowOffset);
                voltages.left = trialData.response.values.left(onsetIndex:offsetIndex);
                voltages.right = trialData.response.values.right(onsetIndex:offsetIndex);
                
                RMS.left = (sum(((voltages.left).^2)))^(1/2);
                RMS.right = (sum(((voltages.right).^2)))^(1/2);
                
                
                % stash the trial
                % first figure out what type of trial we're working with
                directionNameLong = stimulusData.trialList(tt).modulationData.modulationParams.direction;
                directionNameSplit = strsplit(directionNameLong, ' ');
                if strcmp(directionNameSplit{1}, 'Light')
                    directionName = 'LightFlux';
                else
                    directionName = directionNameSplit{1};
                end
                contrastLong = strsplit(directionNameLong, '%');
                contrast = contrastLong{1}(end-2:end);
                % pool the results
                nItems = length((trialStruct.(directionName).(['Contrast', contrast]).left));
                trialStruct.(directionName).(['Contrast', contrast]).left(nItems+1) = RMS.left;
                trialStruct.(directionName).(['Contrast', contrast]).right(nItems+1) = RMS.right;
            end
            
            
        end
    end
end

%% make median RMS struct
for ss = 1:length(stimuli)
    for cc = 1:length(contrasts)
        
        for ll = 1:2
            if ll == 1
                laterality = 'left';
            elseif ll == 2
                laterality = 'right';
            end
            medianRMS.(stimuli{ss}).(['Contrast',num2str(contrasts{cc}) '_median']).(laterality) = nanmedian(trialStruct.(stimuli{ss}).(['Contrast',num2str(contrasts{cc})]).(laterality));
            
            sortedVector = sort(trialStruct.(stimuli{ss}).(['Contrast',num2str(contrasts{cc})]).(laterality));
            
            medianRMS.(stimuli{ss}).(['Contrast',num2str(contrasts{cc}), '_', num2str(p.Results.confidenceInterval(1))]).(laterality) = sortedVector(round(p.Results.confidenceInterval(1)/100*length((trialStruct.(stimuli{ss}).(['Contrast', num2str(contrasts{cc})]).(laterality)))));
            medianRMS.(stimuli{ss}).(['Contrast',num2str(contrasts{cc}), '_', num2str(p.Results.confidenceInterval(2))]).(laterality) = sortedVector(round(p.Results.confidenceInterval(2)/100*length((trialStruct.(stimuli{ss}).(['Contrast', num2str(contrasts{cc})]).(laterality)))));
            
        end
    end
end

%% Plot to summarize
plotFig = figure;
melAxis1 = subplot(3,2,1);
data = horzcat( trialStruct.Melanopsin.Contrast100.left', trialStruct.Melanopsin.Contrast200.left',  trialStruct.Melanopsin.Contrast400.left');
plotSpread(data, 'distributionColors', {[220/255, 237/255, 200/255], [66/255, 179/255, 213/255], [26/255, 35/255, 126/255]}, 'xNames', {'100%', '200%', '400%'}, 'distributionMarkers', '*', 'showMM', 3, 'binWidth', 0.3)
title('Melanopsin, Left')
xlabel('Contrast')
ylabel('RMS')
%ylim([0 4]);
melAxis2 = subplot(3,2,2);
data = horzcat( trialStruct.Melanopsin.Contrast100.right', trialStruct.Melanopsin.Contrast200.right',  trialStruct.Melanopsin.Contrast400.right');
plotSpread(data, 'distributionColors', {[220/255, 237/255, 200/255], [66/255, 179/255, 213/255], [26/255, 35/255, 126/255]}, 'xNames', {'100%', '200%', '400%'}, 'distributionMarkers', '*', 'showMM', 3, 'binWidth', 0.3)
title('Melanopsin, Right')
xlabel('Contrast')
ylabel('RMS')
%ylim([0 4]);
linkaxes([melAxis1, melAxis2]);


grayColorMap = colormap(gray);
lmsAxis1 = subplot(3,2,3);
data = horzcat( trialStruct.LMS.Contrast100.left', trialStruct.LMS.Contrast200.left',  trialStruct.LMS.Contrast400.left');
plotSpread(data, 'distributionColors', {grayColorMap(50,:), grayColorMap(25,:), grayColorMap(1,:)}, 'xNames', {'100%', '200%', '400%'}, 'distributionMarkers', '*', 'showMM', 3, 'binWidth', 0.3)
title('LMS, Left')
xlabel('Contrast')
ylabel('RMS')
%ylim([0 4]);
lmsAxis2= subplot(3,2,4);
data = horzcat( trialStruct.LMS.Contrast100.right', trialStruct.LMS.Contrast200.right',  trialStruct.LMS.Contrast400.right');
plotSpread(data, 'distributionColors', {grayColorMap(50,:), grayColorMap(25,:), grayColorMap(1,:)}, 'xNames', {'100%', '200%', '400%'}, 'distributionMarkers', '*', 'showMM', 3, 'binWidth', 0.3)
title('LMS, Right')
xlabel('Contrast')
ylabel('RMS')
%ylim([0 4]);
linkaxes([lmsAxis1, lmsAxis2]);


lightFluxAxis1 = subplot(3,2,5);
data = horzcat( trialStruct.LightFlux.Contrast100.left', trialStruct.LightFlux.Contrast200.left',  trialStruct.LightFlux.Contrast400.left');
plotSpread(data, 'distributionColors', {[254/255, 235/255, 101/255], [228/255, 82/255, 27/255], [77/255, 52/255, 47/255]}, 'xNames', {'100%', '200%', '400%'}, 'distributionMarkers', '*', 'showMM', 3, 'binWidth', 0.3)
title('Light Flux, Left')
xlabel('Contrast')
ylabel('RMS')
%ylim([0 4]);
lightFluxAxis2 = subplot(3,2,6);
data = horzcat( trialStruct.LightFlux.Contrast100.right', trialStruct.LightFlux.Contrast200.right',  trialStruct.LightFlux.Contrast400.right');
plotSpread(data, 'distributionColors', {[254/255, 235/255, 101/255], [228/255, 82/255, 27/255], [77/255, 52/255, 47/255]}, 'xNames', {'100%', '200%', '400%'}, 'distributionMarkers', '*', 'showMM', 3, 'binWidth', 0.3)
title('Light Flux, Right')
xlabel('Contrast')
ylabel('RMS')
%ylim([0 4]);
linkaxes([lightFluxAxis1, lightFluxAxis2]);

analysisBasePath = fullfile(getpref('melSquintAnalysis','melaAnalysisPath'), 'Experiments/OLApproach_Squint/SquintToPulse/DataFiles/', subjectID);
print(plotFig, fullfile(analysisBasePath,'EMG_RMS'), '-dpdf', '-fillpage')
close(plotFig)

plotFig = figure;
melAxCombined = subplot(3,1,1);
data = horzcat( nanmean([trialStruct.Melanopsin.Contrast100.left; trialStruct.Melanopsin.Contrast100.right])', nanmean([trialStruct.Melanopsin.Contrast200.left; trialStruct.Melanopsin.Contrast200.right])',  nanmean([trialStruct.Melanopsin.Contrast400.left; trialStruct.Melanopsin.Contrast400.right])');
plotSpread(data, 'distributionColors', {[220/255, 237/255, 200/255], [66/255, 179/255, 213/255], [26/255, 35/255, 126/255]}, 'xNames', {'100%', '200%', '400%'}, 'distributionMarkers', '*', 'showMM', 3, 'binWidth', 0.3)
title('Melanopsin')
xlabel('Contrast')
ylabel('RMS')

lmsAxCombined = subplot(3,1,2);
data = horzcat( nanmean([trialStruct.LMS.Contrast100.left; trialStruct.LMS.Contrast100.right])', nanmean([trialStruct.LMS.Contrast200.left; trialStruct.LMS.Contrast200.right])',  nanmean([trialStruct.LMS.Contrast400.left; trialStruct.LMS.Contrast400.right])');
plotSpread(data, 'distributionColors', {grayColorMap(50,:), grayColorMap(25,:), grayColorMap(1,:)}, 'xNames', {'100%', '200%', '400%'}, 'distributionMarkers', '*', 'showMM', 3, 'binWidth', 0.3)
title('LMS')
xlabel('Contrast')
ylabel('RMS')

lightFluxAxCombined = subplot(3,1,3);
data = horzcat( nanmean([trialStruct.LightFlux.Contrast100.left; trialStruct.LightFlux.Contrast100.right])', nanmean([trialStruct.LightFlux.Contrast200.left; trialStruct.LightFlux.Contrast200.right])',  nanmean([trialStruct.LightFlux.Contrast400.left; trialStruct.LightFlux.Contrast400.right])');
plotSpread(data, 'distributionColors', {[254/255, 235/255, 101/255], [228/255, 82/255, 27/255], [77/255, 52/255, 47/255]}, 'xNames', {'100%', '200%', '400%'}, 'distributionMarkers', '*', 'showMM', 3, 'binWidth', 0.3)
title('LightFlux')
xlabel('Contrast')
ylabel('RMS')
print(plotFig, fullfile(analysisBasePath,'EMG_RMS_leftRightCombined'), '-dpdf', '-fillpage')
close(plotFig)

end % end function