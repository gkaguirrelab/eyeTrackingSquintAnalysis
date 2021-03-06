function [medianResponseStruct, trialStruct] = transcribeAudioResponses(subjectID, varargin)
% Analyzes a single subject's verbal discomfort ratings  from the OLApproach_Squint,
% SquintToPulse Experiment
%
% Syntax:
%  [medianResponses, trialStruct] = transcribeAudioResponses(subjectID)

% Description:
%   This function compiles the verbal discomfort ratings from the
%   OLApproach_Squint Experiment. Basically we first figure out how many
%   sessions a given subject has completed. Then we loop over each trial
%   completed -- the audio response is played, and the operator is prompted
%   to enter the heard rating. After completion of all trials, these
%   ratings are compiled and summarized.

% Inputs:
%	subjectID             - A string describing the subjectID (e.g.
%                           MELA_0121) to be analyzed)

% Optional Key-Value Pairs:
%   resume                - A logical statement. If false, the routine
%                           starts at Session 1, Acquisition 1, Trial 1. If
%                           true, the routine assumes the operator has
%                           started analyzing this subject. It then finds
%                           the saved intermediate data, and resumes from
%                           the trial left off.
%   repeat                - A logical statement. If false, which is the
%                           default behavior, the name of the saved output
%                           will be audioTrialStruct.mat. If true, the name
%                           of the saved output will be
%                           audioTrialStruct_repetition.mat. This
%                           functionality has been added so we can have
%                           more than one rating of the same subject.

% Outputs:
%   medianResponseStruct - A 3x1 structure, where each subfield
%                           corresponds to the stimulus type (LMS,
%                           Melanopsin, or Light flux). Each subfield is
%                           itself a 9x1 structure, with each nested
%                           subfield named after the contrast levels (100%,
%                           200%, and 400%) and whether the content refers
%                           to the median value, or confidence interval
%                           boundary.
%  trialStruct            - A nested structure similar in format to
%                           averageResponseStruct, where the first layer
%                           describes the stimulus type and second layer
%                           describes the contrast level. The innermost
%                           layer, however, is a vector containing the
%                           verbal responses from each trial

% Usage:
%   If no data has been analyzed yet for the given subject, call the
%   function as [medianResponses, trialStruct] =
%   analyzeAudioResponses(subjectID) with the 'resume' behavior as the
%   default 'false.' This will then start the analysis at Session 1,
%   Acquisition 1, Trial 1. If data analysis had previously begun for this
%   subject, use [medianResponses, trialStruct] =
%   analyzeAudioResponses(subjectID, 'resume', true) and now the user will
%   be prompted to begin from wherever left off.
%
%   As the routine begins looping over trials, the verbal discomfort rating
%   will be played aloud through whatever default audio output is
%   configured on the operator's computer. At the end of teh audio clip,
%   the operator will be prompted to enter the verbal rating into the
%   console. If the operator desires to repeat the trial, the operator
%   should simply hit enter without inputting any value. If the operator
%   wishes to quit and resume later, simply enter the string 'quit' rather
%   than a value, and the intermediate data will be saved within the
%   relevant subject's directory as part of MELA_analysis.



%% collect some inputs
p = inputParser; p.KeepUnmatched = true;
p.addParameter('resume',false,@islogical);
p.addParameter('repeat',false,@islogical);
p.addParameter('nTrials',10,@isnumeric);
p.addParameter('nAcquisitions',6,@isnumeric);
p.addParameter('nSessions',4,@isnumeric);
p.addParameter('sessions', {}, @iscell);
p.addParameter('contrasts', {100, 200, 400}, @iscell);
p.addParameter('stimuli', {'LightFlux', 'Melanopsin', 'LMS'}, @iscell);
p.addParameter('protocol', 'SquintToPulse', @ischar);
p.addParameter('experimentNumber', [], @ischar);
p.addParameter('allowRepeatSessionNumbers', true, @islogical);
p.addParameter('makePlots', true, @islogical);


p.addParameter('confidenceInterval', [10 90], @isnumeric);


% Parse and check the parameters
p.parse(varargin{:});

contrasts = p.Results.contrasts;
stimuli = p.Results.stimuli;

if strcmp(p.Results.protocol, 'SquintToPulse')
    protocolShortName = 'StP';
elseif strcmp(p.Results.protocol, 'Deuteranopes')
    protocolShortName = 'Deuteranopes';
end


%% Find the data
analysisBasePath = fullfile(getpref('melSquintAnalysis','melaAnalysisPath'), 'Experiments/OLApproach_Squint', p.Results.protocol, 'DataFiles/', subjectID, p.Results.experimentNumber);
dataBasePath = getpref('melSquintAnalysis','melaDataPath');
% figure out filename of trialStruct
if (p.Results.repeat)
    fileName = 'audioTrialStruct_repetition.mat';
else
    fileName = 'audioTrialStruct_final.mat';
end

% figure out the number of completed sessions
potentialSessions = dir(fullfile(dataBasePath, 'Experiments/OLApproach_Squint', p.Results.protocol, 'DataFiles', subjectID, p.Results.experimentNumber, '2*session*'));
potentialNumberOfSessions = length(potentialSessions);

% initialize outputStruct
for ss = 1:length(stimuli)
    for cc = 1:length(contrasts)
        trialStruct.(stimuli{ss}).(['Contrast', num2str(contrasts{cc})]) = [];
    end
end
trialStruct.metaData = [];
% trialStruct.metaData.session = [];
% trialStruct.metaData.acquisition = [];
% trialStruct.metaData.trial = [];
trialStruct.metaData.index = [];

if isempty(p.Results.sessions)
    sessions = [];
    sessionIDs = [];
    for ss = 1:potentialNumberOfSessions
        acquisitions = [];
        for aa = 1:6
            trials = [];
            for tt = 1:10
                if exist(fullfile(dataBasePath, 'Experiments/OLApproach_Squint', p.Results.protocol, 'DataFiles', subjectID, p.Results.experimentNumber, potentialSessions(ss).name, sprintf('videoFiles_acquisition_%02d', aa), sprintf('trial_%03d.mp4', tt)), 'file');
                    trials = [trials, tt];
                end
            end
            if isequal(trials, 1:10)
                acquisitions = [acquisitions, aa];
            end
        end
        if isequal(acquisitions, 1:6)
            sessions = [sessions, ss];
            if p.Results.allowRepeatSessionNumbers
                sessionIDs{end+1} = potentialSessions(ss).name;
            end
        end
    end
    
    completedSessions = sessions;
    % get session IDs
    if ~p.Results.allowRepeatSessionNumbers
        for ss = completedSessions
            potentialSessions = dir(fullfile(dataBasePath, 'Experiments/OLApproach_Squint', p.Results.protocol, 'DataFiles', subjectID, p.Results.experimentNumber, sprintf('*session_%d*', ss)));
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
        sessionIDs = sessionIDs(~cellfun('isempty',sessionIDs));
    end
    
    nSessions = length(sessionIDs);
else
    sessionIDs = p.Results.sessions;
    nSessions = length(sessionIDs);
end

fprintf('Processing:\n');
for ii = 1:(nSessions)
    fprintf('\t%s\n', sessionIDs{ii});
end

% perform a safety check to make sure we don't overwrite our existing data
resumeStatus = p.Results.resume;

if ~(resumeStatus) % if resume is false
    if exist(fullfile(analysisBasePath, fileName), 'file')
        resumeCheck = GetWithDefault('>> It looks like this analysis has already begun for this subject. Would you like to resume this analysis instead?', 'y');
        if strcmp(resumeCheck, 'y')
            resumeStatus = true;
        end
    end
end

trialStruct.metaData.sessions = sessionIDs;

%% Load in the data for each session
% figure out where we're starting from
if resumeStatus
    load(fullfile(analysisBasePath, fileName))
    %     startingSession = trialStruct.metaData.session;
    %     startingAcquisition = trialStruct.metaData.acquisition;
    %     startingTrial = trialStruct.metaData.trial + 1;
    startingIndex = trialStruct.metaData.index;
else
    %startingSession = 1;
    %startingAcquisition = 1;
    %startingTrial = 1;
    startingIndex = 1;
    
    
end

totalTrials = p.Results.nTrials * p.Results.nAcquisitions * nSessions;

trialAccumulator = [];

%% pool the audio files
% to speed up just rolling through trials
counter = 1;
for ii = 1:totalTrials
    
    [tt, aa, ss] = ind2sub([10;6;nSessions], ii);
    
    % determine which session we're in. Note this doesn't always correspond
    % to the ss variable obtained above, in the case that we're missing a
    % middle session.
    sessionID = sessionIDs{ceil((ii/totalTrials*nSessions))};
    sessionNumber = strsplit(sessionIDs{ss}, 'session_');
    sessionNumber = sessionNumber{2};
    sessionNumber = str2num(sessionNumber);
    
    acquisitionDataFile = fullfile(dataBasePath, 'Experiments/OLApproach_Squint', p.Results.protocol, 'DataFiles', subjectID, p.Results.experimentNumber, sessionIDs{ss}, sprintf('session_%d_%s_acquisition%02d_base.mat', sessionNumber,protocolShortName, aa));
    if exist(acquisitionDataFile)
        acquisitionData = load(acquisitionDataFile);
        
        
        
        trialData.response.values = acquisitionData.responseStruct.data(tt).audio;
        [ firstTimePoint, secondTimePoint ] = grabRelevantAudioIndices(trialData.response.values, 16000);
        % convert timepoint to indices
        firstIndex = firstTimePoint * 16000;
        secondIndex = secondTimePoint * 16000;
        if isempty(firstIndex)
            firstIndex = 1;
        elseif firstIndex < 1
            firstIndex = 1;
        end
        if isempty(secondIndex)
            secondIndex = length(trialData.response.values);
        elseif (secondIndex > length(trialData.response.values))
            secondIndex = length(trialData.response.values);
        end
        trialAccumulator(counter).audio = trialData.response.values(firstIndex:secondIndex);
        
        
        % figure out the stimulus and contrast
        directionNameLong = acquisitionData.trialList(tt).modulationData.modulationParams.direction;
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
        nItems = length((trialStruct.(directionName).(['Contrast', contrast])));
        trialAccumulator(counter).stimulus =[directionName, '_Contrast' contrast];
        
        counter = counter + 1;
    end
    
    
    
end

for ii = startingIndex:totalTrials
    
    [tt, aa, ss] = ind2sub([10;6;nSessions], ii);
    
    sessionID = sessionIDs{ceil((ii/totalTrials*nSessions))};
    sessionNumber = strsplit(sessionIDs{ss}, 'session_');
    sessionNumber = sessionNumber{2};
    sessionNumber = str2num(sessionNumber);
    
    %acquisitionData = load(fullfile(dataBasePath, 'Experiments/OLApproach_Squint', p.Results.protocol, 'DataFiles', subjectID, sessionIDs{ss}, sprintf('session_%d_StP_acquisition%02d_base.mat', ss,aa)));
    
    
    fprintf('Session %d, Acquisition %d, Trial %d\n', sessionNumber, aa, tt);
    
    trialData.response.values = trialAccumulator(ii).audio;
    
    % listen to the audio
    trialDoneFlag = false;
    while ~trialDoneFlag
        sound(trialData.response.values, 16000*1)
        % pause(length(trialData.response.values)/16000)
        % prompt user to input rating
        discomfortRating = GetWithDefault('>><strong>Enter discomfort rating:</strong>', '');
        switch discomfortRating
            % play the clip over again if necessary
            case ''
                
            case 'quit'
                %trialStruct.metaData.session = ss;
                %trialStruct.metaData.acquisition = aa;
                %trialStruct.metaData.trial = tt-1;
                
                trialStruct.metaData.index = ii;
                save(fullfile(analysisBasePath, fileName), 'trialStruct', 'trialStruct', '-v7.3');
                return
                
            case '0'
                trialDoneFlag = true;
            case '1'
                trialDoneFlag = true;
            case '2'
                trialDoneFlag = true;
            case '3'
                trialDoneFlag = true;
            case '4'
                trialDoneFlag = true;
            case '5'
                trialDoneFlag = true;
            case '6'
                trialDoneFlag = true;
            case '7'
                trialDoneFlag = true;
            case '8'
                trialDoneFlag = true;
            case '9'
                trialDoneFlag = true;
            case '10'
                trialDoneFlag = true;
            case 'NaN'
                trialDoneFlag = true;
                
            otherwise
                fprintf('Please provide a valid numerical rating.\n')
        end
    end
    
    %stashing the result
    % first figure out the stimulus type
    stimulusNameFull = trialAccumulator(ii).stimulus;
    stimulusNameFull_split = strsplit(stimulusNameFull, '_');
    directionName = stimulusNameFull_split(1);
    contrastName = stimulusNameFull_split(2);
    % pool the results
    nItems = length((trialStruct.(directionName{1}).([contrastName{1}])));
    if tt ~= 1
        trialStruct.(directionName{1}).([contrastName{1}])(nItems+1) = str2num(discomfortRating);
    end
    if ~exist(fullfile(analysisBasePath), 'dir')
        mkdir(fullfile(analysisBasePath));
    end
    trialStruct.metaData.index = ii + 1;
    save(fullfile(analysisBasePath, fileName), 'trialStruct', 'trialStruct', '-v7.3');
    
    
    
    
end

save(fullfile(analysisBasePath, fileName), 'trialStruct', 'trialStruct', '-v7.3');

%% make median responses
for ss = 1:length(stimuli)
    for cc = 1:length(contrasts)
        
        
        medianResponseStruct.(stimuli{ss}).(['Contrast',num2str(contrasts{cc}) '_median']) = nanmedian(trialStruct.(stimuli{ss}).(['Contrast',num2str(contrasts{cc})]));
        
        sortedVector = sort(trialStruct.(stimuli{ss}).(['Contrast',num2str(contrasts{cc})]));
        
        medianResponseStruct.(stimuli{ss}).(['Contrast',num2str(contrasts{cc}), '_', num2str(p.Results.confidenceInterval(1))]) = sortedVector(round(p.Results.confidenceInterval(1)/100*length((trialStruct.(stimuli{ss}).(['Contrast', num2str(contrasts{cc})])))));
        medianResponseStruct.(stimuli{ss}).(['Contrast',num2str(contrasts{cc}), '_', num2str(p.Results.confidenceInterval(2))]) = sortedVector(round(p.Results.confidenceInterval(2)/100*length((trialStruct.(stimuli{ss}).(['Contrast', num2str(contrasts{cc})])))));
        
        
    end
end

%% Plot results
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
        
        axis.(['axis', num2str(stimulus)]) = subplot(3,1,stimulus);
        data = horzcat( trialStructForPlotting.(stimuli{stimulus}).(['Contrast', num2str(contrasts{1})])', trialStructForPlotting.(stimuli{stimulus}).(['Contrast', num2str(contrasts{2})])',  trialStructForPlotting.(stimuli{stimulus}).(['Contrast', num2str(contrasts{3})])');
        plotSpread(data, 'distributionColors', colors, 'xNames', {num2str(contrasts{1}), num2str(contrasts{2}), num2str(contrasts{3})}, 'distributionMarkers', '*', 'showMM', 3, 'binWidth', 0.3)
        title([stimuli{stimulus}])
        xlabel('Contrast')
        ylabel('Discomfort Ratings')
        ylim([0 10]);
     

        
    end
    
    analysisBasePath = fullfile(getpref('melSquintAnalysis','melaProcessingPath'), 'Experiments/OLApproach_Squint/', p.Results.protocol, '/DataFiles/', subjectID, p.Results.experimentNumber);

    saveName = [subjectID, '_discomfortRatings.pdf'];

    
    export_fig(plotFig, fullfile(analysisBasePath, saveName))
    
   
    
end

%% local functions
    function inputVal = GetWithDefault(prompt,defaultVal)
        % inputVal = GetWithDefault(prompt,defaultVal)
        %
        % Prompt for a number or string, with a default returned if user
        % hits return.
        %
        % 4/3/10  dhb  Wrote it.
        
        if (ischar(defaultVal))
            inputVal = input(sprintf([prompt ' [%s]: '],defaultVal),'s');
        else
            inputVal = input(sprintf([prompt ' [%g]: '],defaultVal));
        end
        if (isempty(inputVal))
            inputVal = defaultVal;
        end
    end % end GetWithDefault

end % end function
