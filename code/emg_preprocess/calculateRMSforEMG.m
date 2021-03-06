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
%   subjectID             - A string describing the subjectID (e.g.
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
p.addParameter('protocol','SquintToPulse',@ischar);
p.addParameter('stimuli',{'LightFlux', 'Melanopsin', 'LMS'},@iscell);
p.addParameter('contrasts',{100, 200, 400},@iscell);
p.addParameter('protocolShortName','StP',@ischar);
p.addParameter('experimentName',[],@ischar);
p.addParameter('makeDebugPlots',false,@islogical);
p.addParameter('normalize',true,@islogical);
p.addParameter('delayInSecs',1.1,@isnumeric);
p.addParameter('windowOnset',2.5,@isnumeric);
p.addParameter('nBootstraps',1000,@isnumeric);
p.addParameter('windowOffset',6.5,@isnumeric);
p.addParameter('baselineOnset',0,@isnumeric);
p.addParameter('baselineOffset',1.5,@isnumeric);
p.addParameter('confidenceInterval', [10 90], @isnumeric);
p.addParameter('sessions', {}, @iscell);
p.addParameter('savePath', fullfile(getpref('melSquintAnalysis', 'melaAnalysisPath'), 'melSquintAnalysis', 'EMG'), @ischar);
% Parse and check the parameters
p.parse(varargin{:});
%% Find the data
analysisBasePath = fullfile(getpref('melSquintAnalysis','melaProcessingPath'), 'Experiments/OLApproach_Squint/', p.Results.protocol, '/DataFiles/', subjectID);
dataBasePath = getpref('melSquintAnalysis','melaDataPath');
% figure out the number of completed sessions
potentialSessions = dir(fullfile(dataBasePath, 'Experiments/OLApproach_Squint/', p.Results.protocol, '/DataFiles', subjectID, p.Results.experimentName, '2*session*'));
potentialNumberOfSessions = length(potentialSessions);
% initialize outputStruct
stimuli = p.Results.stimuli;
contrasts = p.Results.contrasts;
for ss = 1:length(stimuli)
    for cc = 1:length(contrasts)
        trialStruct.(stimuli{ss}).(['Contrast', num2str(contrasts{cc})]).left = [];
        trialStruct.(stimuli{ss}).(['Contrast', num2str(contrasts{cc})]).right = [];
        
        normalizedByTrialTrialStruct.(stimuli{ss}).(['Contrast', num2str(contrasts{cc})]).left = [];
        normalizedByTrialTrialStruct.(stimuli{ss}).(['Contrast', num2str(contrasts{cc})]).right = [];
        
        normalizedBySessionTrialStruct.(stimuli{ss}).(['Contrast', num2str(contrasts{cc})]).left = [];
        normalizedBySessionTrialStruct.(stimuli{ss}).(['Contrast', num2str(contrasts{cc})]).right = [];
    end
    for session = 1:4
        
        baselineRMSAccumulator.(['Session', num2str(session)]).(stimuli{ss}).left = [];
        baselineRMSAccumulator.(['Session', num2str(session)]).(stimuli{ss}).right = [];
        
    end
end

pooledSTDs.normalizedBySession = [];
pooledSTDs.normalizedByTrial = [];

if isempty(p.Results.sessions)
    sessions = [];
    for ss = 1:potentialNumberOfSessions
        acquisitions = [];
        for aa = 1:6
            trials = [];
            for tt = 1:10
                if exist(fullfile(dataBasePath, 'Experiments/OLApproach_Squint/', p.Results.protocol, '/DataFiles', subjectID, p.Results.experimentName, potentialSessions(ss).name, sprintf('videoFiles_acquisition_%02d', aa), sprintf('trial_%03d.mp4', tt)), 'file');
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
        potentialSessions = dir(fullfile(dataBasePath, 'Experiments/OLApproach_Squint/', p.Results.protocol, '/DataFiles', subjectID, p.Results.experimentName, sprintf('*session_%d*', ss)));
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
sessionIDs = sessionIDs(~cellfun('isempty',sessionIDs));
for ss = 1:length(sessionIDs)
    sessionNumber = strsplit(sessionIDs{ss}, 'session_');
    sessionNumber = sessionNumber{2};
    availableAcquisitions = dir(fullfile(dataBasePath, 'Experiments/OLApproach_Squint/', p.Results.protocol, '/DataFiles', subjectID, p.Results.experimentName, sessionIDs{ss}, '*acquisition*_emg.mat'));
    
    acquisitions = [];
    
    for stimulus = 1:length(stimuli)
        for cc = 1:length(contrasts)
            trialStructBySession.(stimuli{stimulus}).(['Contrast', num2str(contrasts{cc})]).left = [];
            trialStructBySession.(stimuli{stimulus}).(['Contrast', num2str(contrasts{cc})]).right = [];
        end
    end
    
    for aa = 1:length(availableAcquisitions)
        acquisitionLongName = availableAcquisitions(aa).name;
        acquisitionLongName = strsplit(acquisitionLongName, '_emg.mat');
        acquisition = acquisitionLongName{1}(end-1:end);
        acquisition = str2num(acquisition);
        acquisitions = [acquisitions, acquisition];
    end
    
    
    for aa = acquisitions
        stimulusDataFile = fullfile(dataBasePath, 'Experiments/OLApproach_Squint/', p.Results.protocol, '/DataFiles', subjectID, p.Results.experimentName, sessionIDs{ss}, sprintf('session_%d_%s_acquisition%02d_base.mat', str2num(sessionNumber),p.Results.protocolShortName, aa));
        if exist(stimulusDataFile)
            acquisitionData = load(fullfile(dataBasePath, 'Experiments/OLApproach_Squint/', p.Results.protocol, '/DataFiles', subjectID, p.Results.experimentName, sessionIDs{ss}, sprintf('session_%d_%s_acquisition%02d_emg.mat', str2num(sessionNumber),p.Results.protocolShortName,aa)));
            stimulusData = load(stimulusDataFile);
            
            if p.Results.makeDebugPlots
                figure;
            end
            
            voltages = [];
            for tt = 1:10
                
                if tt ~= 1 % we're discarding the first trial of each acquisition
                    % assemble packet
                    trialData.response.timebase = acquisitionData.responseStruct.data(tt).emg.timebase;
                    trialData.response.values.right = acquisitionData.responseStruct.data(tt).emg.response(1,:);
                    trialData.response.values.left = acquisitionData.responseStruct.data(tt).emg.response(2,:);
                    
                    % adjust timebase for the delay in issuing the
                    % beginning recording command and the actual beginning
                    % of data recording
                    
                    if trialData.response.timebase(1) == 0
                        trialData.response.timebase = trialData.response.timebase + p.Results.delayInSecs;
                    end
                        
                    
                    
                    % center the voltages at 0. we've noticed that for whatever
                    % reason, the baseline EMG results are not centered around
                    % 0, but are in fact shifted a bit negative. even more
                    % confusing, this is worse for the left EMG leads relative
                    % to the right. centering at 0 should take care of this
                    
                    trialData.response.values.right = trialData.response.values.right - mean(trialData.response.values.right);
                    trialData.response.values.left = trialData.response.values.left - mean(trialData.response.values.left);
                    
                    
                    if p.Results.makeDebugPlots
                        subplot(2,5,tt)
                        hold on
                        plot(trialData.response.timebase, trialData.response.values.right);
                        plot(trialData.response.timebase, trialData.response.values.left);
                    end
                    
                    % calculate RMS for the trial
                    
                    [~, onsetIndex ]  = min(abs(trialData.response.timebase-p.Results.windowOnset));
                    [~, offsetIndex ]  = min(abs(trialData.response.timebase-p.Results.windowOffset));
                    [~, baselineOnsetIndex ]  = min(abs(trialData.response.timebase-p.Results.baselineOnset));
                    [~, baselineOffsetIndex ]  = min(abs(trialData.response.timebase-p.Results.baselineOffset));
                    
                    
                    voltages.left = trialData.response.values.left(onsetIndex:offsetIndex);
                    voltages.right = trialData.response.values.right(onsetIndex:offsetIndex);
                    
                    
                    if (p.Results.normalize)
                        
                        
                        
                        
                        RMS.left = (mean(((voltages.left).^2)))^(1/2);
                        RMS.right = (mean(((voltages.right).^2)))^(1/2);
                        
                        baselineVoltages.left = trialData.response.values.left(baselineOnsetIndex:baselineOffsetIndex);
                        baselineVoltages.right = trialData.response.values.right(baselineOnsetIndex:baselineOffsetIndex);
                        
                        baselineRMS.left = (mean(((baselineVoltages.left).^2)))^(1/2);
                        baselineRMS.right = (mean(((baselineVoltages.right).^2)))^(1/2);
                        
                        
                    else
                        voltages.left = trialData.response.values.left(onsetIndex:offsetIndex);
                        voltages.right = trialData.response.values.right(onsetIndex:offsetIndex);
                        
                        
                        RMS.left = (sum(((voltages.left).^2)))^(1/2);
                        RMS.right = (sum(((voltages.right).^2)))^(1/2);
                    end
                    
                    % stash the trial
                    % first figure out what type of trial we're working with
                    directionNameLong = stimulusData.trialList(tt).modulationData.modulationParams.direction;
                    directionNameSplit = strsplit(directionNameLong, ' ');
                    if strcmp(directionNameSplit{1}, 'Light')
                        directionName = 'LightFlux';
                    elseif strcmp(directionNameSplit{1}, 'L+S')
                        directionName = 'LS';
                    else
                        directionName = directionNameSplit{1};
                    end
                    contrastLong = strsplit(directionNameLong, '%');
                    contrastLong = strsplit(contrastLong{1}, ' ');
                    contrast = contrastLong{end};
                    % pool the results
                    nItems = length((trialStruct.(directionName).(['Contrast', contrast]).left));
                    if (p.Results.normalize)
                        
                        trialStruct.(directionName).(['Contrast', contrast]).left(nItems+1) = (RMS.left);
                        trialStruct.(directionName).(['Contrast', contrast]).right(nItems+1) = (RMS.right);
                        
                        trialStructBySession.(directionName).(['Contrast', contrast]).left(end+1) = (RMS.left);
                        trialStructBySession.(directionName).(['Contrast', contrast]).right(end+1) = (RMS.right);
                        
                        
                        normalizedByTrialTrialStruct.(directionName).(['Contrast', contrast]).left(nItems+1) = (RMS.left - baselineRMS.left)/(baselineRMS.left);
                        normalizedByTrialTrialStruct.(directionName).(['Contrast', contrast]).right(nItems+1) = (RMS.right - baselineRMS.right)/(baselineRMS.right);
                        
                        baselineRMSAccumulator.(['Session', num2str(sessionNumber)]).(directionName).left(end+1) = baselineRMS.left;
                        baselineRMSAccumulator.(['Session', num2str(sessionNumber)]).(directionName).right(end+1) = baselineRMS.right;
                    else
                        trialStruct.(directionName).(['Contrast', contrast]).left(nItems+1) = RMS.left;
                        trialStruct.(directionName).(['Contrast', contrast]).right(nItems+1) = RMS.right;
                        
                    end
                    
                end
                
            end
        end
    end
    
    if p.Results.normalize
        for stimulus = 1:length(stimuli)
            meanBaselineRMS.left = mean(baselineRMSAccumulator.(['Session', num2str(sessionNumber)]).(stimuli{stimulus}).left);
            meanBaselineRMS.right = mean(baselineRMSAccumulator.(['Session', num2str(sessionNumber)]).(stimuli{stimulus}).right);
            for contrast = 1:length(contrasts)
                
                normalizedBySessionTrialStruct.(stimuli{stimulus}).(['Contrast', num2str(contrasts{contrast})]).left = [normalizedBySessionTrialStruct.(stimuli{stimulus}).(['Contrast', num2str(contrasts{contrast})]).left, (trialStructBySession.(stimuli{stimulus}).(['Contrast', num2str(contrasts{contrast})]).left - meanBaselineRMS.left)./meanBaselineRMS.left];
                normalizedBySessionTrialStruct.(stimuli{stimulus}).(['Contrast', num2str(contrasts{contrast})]).right = [normalizedBySessionTrialStruct.(stimuli{stimulus}).(['Contrast', num2str(contrasts{contrast})]).right, (trialStructBySession.(stimuli{stimulus}).(['Contrast', num2str(contrasts{contrast})]).right - meanBaselineRMS.right)./meanBaselineRMS.right];
                
                pooledSTDs.normalizedBySession(end+1) = std(normalizedBySessionTrialStruct.(stimuli{stimulus}).(['Contrast', num2str(contrasts{contrast})]).left);
                pooledSTDs.normalizedBySession(end+1) = std(normalizedBySessionTrialStruct.(stimuli{stimulus}).(['Contrast', num2str(contrasts{contrast})]).right);
                
                
                pooledSTDs.normalizedByTrial(end+1) = std(normalizedByTrialTrialStruct.(stimuli{stimulus}).(['Contrast', num2str(contrasts{contrast})]).left);
                pooledSTDs.normalizedByTrial(end+1) = std(normalizedByTrialTrialStruct.(stimuli{stimulus}).(['Contrast', num2str(contrasts{contrast})]).right);
                
                
            end
        end
    end
    
end

if p.Results.normalize
    trialStruct = normalizedBySessionTrialStruct;
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

if p.Results.normalize
    
    saveName = [subjectID, '_EMGMedianRMS_normalized.mat'];
else
    saveName = [subjectID, '_EMGMedianRMS.mat'];
end

save(fullfile(p.Results.savePath, 'medianStructs', saveName), 'medianRMS', 'baselineRMSAccumulator');
%% Plot to summarize
makePlots = p.Results.makePlots;
if makePlots
    
    trialStructForPlotting = trialStruct;
    
    
    
    plotFig = figure;
    for stimulus = 1:length(stimuli)
        
        if strcmp(stimuli{stimulus}, 'Melanopsin')
            colors = {[220/255, 237/255, 200/255], [66/255, 179/255, 213/255], [26/255, 35/255, 126/255]};
        elseif strcmp(stimuli{stimulus}, 'LMS') || strcmp(stimuli{stimulus}, 'LS')
            grayColorMap = colormap(gray);
            colors = {grayColorMap(50,:), grayColorMap(25,:), grayColorMap(1,:)};
        elseif strcmp(stimuli{stimulus}, 'LightFlux')
            colors = {[254/255, 235/255, 101/255], [228/255, 82/255, 27/255], [77/255, 52/255, 47/255]};
        end
        
        axis.(['axis', num2str(stimulus)]) = subplot(3,2,(stimulus-1)*2+1);
        data = horzcat( trialStructForPlotting.(stimuli{stimulus}).(['Contrast', num2str(contrasts{1})]).left', trialStructForPlotting.(stimuli{stimulus}).(['Contrast', num2str(contrasts{2})]).left',  trialStructForPlotting.(stimuli{stimulus}).(['Contrast', num2str(contrasts{3})]).left');
        plotSpread(data, 'distributionColors', colors, 'xNames', {num2str(contrasts{1}), num2str(contrasts{2}), num2str(contrasts{3})}, 'distributionMarkers', '*', 'showMM', 3, 'binWidth', 0.3)
        title([stimuli{stimulus}, ', Left'])
        xlabel('Contrast')
        ylabel('RMS')
        %ylim([0 4]);
        axis.(['axis', num2str(stimulus+1)]) = subplot(3,2,(stimulus-1)*2+2);
        data = horzcat( trialStructForPlotting.(stimuli{stimulus}).(['Contrast', num2str(contrasts{1})]).right', trialStructForPlotting.(stimuli{stimulus}).(['Contrast', num2str(contrasts{2})]).right',  trialStructForPlotting.(stimuli{stimulus}).(['Contrast', num2str(contrasts{3})]).right');
        plotSpread(data, 'distributionColors', colors, 'xNames', {num2str(contrasts{1}), num2str(contrasts{2}), num2str(contrasts{3})}, 'distributionMarkers', '*', 'showMM', 3, 'binWidth', 0.3)
        title([stimuli{stimulus}, ', Right'])
        xlabel('Contrast')
        ylabel('RMS')
        %ylim([0 4]);
        linkaxes([axis.(['axis', num2str(stimulus)]), axis.(['axis', num2str(stimulus+1)])]);
        
        
    end
    
    analysisBasePath = fullfile(getpref('melSquintAnalysis','melaProcessingPath'), 'Experiments/OLApproach_Squint/', p.Results.protocol, '/DataFiles/', subjectID, p.Results.experimentName);
    
    if p.Results.normalize
        saveName = 'EMG_RMS_normalized';
    else
        saveName = 'EMG_RMS';
    end
    
    print(plotFig, fullfile(analysisBasePath, saveName), '-dpdf', '-fillpage')
    print(plotFig, fullfile(p.Results.savePath, 'plots', [subjectID, '_', saveName]), '-dpdf', '-fillpage')
    
    %close(plotFig)
    plotFig = figure;
    
    for stimulus = 1:length(stimuli)
        
        if strcmp(stimuli{stimulus}, 'Melanopsin')
            colors = {[220/255, 237/255, 200/255], [66/255, 179/255, 213/255], [26/255, 35/255, 126/255]};
        elseif strcmp(stimuli{stimulus}, 'LMS') || strcmp(stimuli{stimulus}, 'LS')
            grayColorMap = colormap(gray);
            colors = {grayColorMap(50,:), grayColorMap(25,:), grayColorMap(1,:)};
        elseif strcmp(stimuli{stimulus}, 'LightFlux')
            colors = {[254/255, 235/255, 101/255], [228/255, 82/255, 27/255], [77/255, 52/255, 47/255]};
        end
        
        ax.(['axis', num2str(stimulus)]) = subplot(3,1,stimulus);
        data = horzcat( nanmean([trialStructForPlotting.(stimuli{stimulus}).(['Contrast', num2str(contrasts{1})]).left; trialStructForPlotting.(stimuli{stimulus}).(['Contrast', num2str(contrasts{1})]).right])', nanmean([trialStructForPlotting.(stimuli{stimulus}).(['Contrast', num2str(contrasts{2})]).left; trialStructForPlotting.(stimuli{stimulus}).(['Contrast', num2str(contrasts{2})]).right])',  nanmean([trialStructForPlotting.(stimuli{stimulus}).(['Contrast', num2str(contrasts{3})]).left; trialStructForPlotting.(stimuli{stimulus}).(['Contrast', num2str(contrasts{3})]).right])');
        plotSpread(data, 'distributionColors', colors, 'xNames', {num2str(contrasts{1}), num2str(contrasts{2}), num2str(contrasts{3})}, 'distributionMarkers', '*', 'showMM', 3, 'binWidth', 0.3)
        title(stimuli{stimulus})
        xlabel('Contrast')
        ylabel('RMS')
        
    end
    
    if p.Results.normalize
        saveName = [subjectID, '_EMG_RMS_leftRightCombined_normalized'];
    else
        saveName = [subjectID, '_EMG_RMS_leftRightCombined'];
    end
    print(plotFig, fullfile(analysisBasePath, saveName), '-dpdf', '-fillpage')
    if isempty(p.Results.experimentName)
        print(plotFig, fullfile(p.Results.savePath, 'plots', saveName), '-dpdf', '-fillpage')
    else
        if ~exist(fullfile(p.Results.savePath, 'Deuteranopes', p.Results.experimentName, 'plots'))
            mkdir(fullfile(p.Results.savePath, 'Deuteranopes', p.Results.experimentName, 'plots'))
        end
        print(plotFig, fullfile(p.Results.savePath, 'Deuteranopes', p.Results.experimentName, 'plots', saveName), '-dpdf', '-fillpage')
    end
    
end
end % end function