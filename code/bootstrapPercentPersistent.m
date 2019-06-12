function [ percentPersistentDistribution ] = bootstrapPercentPersistent(subjectList, varargin)

%{
Example:
subjectList = generateSubjectList;
pathToAverageResponseMatrix = '/Users/harrisonmcadams/Dropbox (Aguirre-Brainard Lab)/MELA_processing/Experiments/OLApproach_Squint/SquintToPulse/DataFiles/averageResponsePlots/groupAverageMatrix.mat';
saveName = '/Users/harrisonmcadams/Dropbox (Aguirre-Brainard Lab)/MELA_processing/Experiments/OLApproach_Squint/SquintToPulse/DataFiles/averageResponsePlots/bootstrap';

for ii = 20:40
    [ percentPersistentDistribution ] = bootstrapPercentPersistent(subjectList, 'nSubjectsInBootstrapSample', ii, 'saveName', saveName);
end

plotFig = figure;
SEMBySampleSize = [];
for ii = 20:40
    load(fullfile('/Users/harrisonmcadams/Dropbox (Aguirre-Brainard Lab)/MELA_processing/Experiments/OLApproach_Squint/SquintToPulse/DataFiles/averageResponsePlots/', ['bootstrap_N', num2str(ii), '.mat']));
    SEMBySampleSize(end+1) = std(percentPersistentDistribution);
    clear percentPersistentDistribution
end
plot(20:40, SEMBySampleSize, 'o');
xlabel('Number of Subjects')
ylabel('Standard Error')


%}

p = inputParser; p.KeepUnmatched = true;
p.addParameter('makePlots',true,@islogical);
p.addParameter('saveName', [], @ischar);
p.addParameter('nBootstrapIterations', 1000, @isnumeric);
p.addParameter('nSubjectsInBootstrapSample', 20, @isnumeric);
p.addParameter('pathToAverageResponseMatrix', [], @ischar);
p.addParameter('responseTimebase', 0:1/60:18.5, @isnumeric);
p.addParameter('debugBootstrapPlots', false, @islogical);
p.parse(varargin{:});

%% Get average response matrix
if isempty(p.Results.pathToAverageResponseMatrix)
    contrasts = {'400'};
    stimuli = {'Melanopsin'};
    
    for cc = 1:length(contrasts)
        for stimulus = 1:length(stimuli)
            averageResponseMatrix.(stimuli{stimulus}).(['Contrast', contrasts{cc}]) = [];
        end
    end
    
    for cc = 1:length(contrasts)
        for stimulus = 1:length(stimuli)
            for ss = 1:length(subjectList)
                clear trialStruct
                subjectID = subjectList{ss};
                
                load(fullfile(getpref('melSquintAnalysis', 'melaProcessingPath'), 'Experiments', 'OLApproach_Squint', 'SquintToPulse', 'DataFiles', subjectID, 'trialStruct_postSpotcheck.mat'));
                for tt = 1:length(trialStruct.(stimuli{stimulus}).(['Contrast',num2str(contrasts{cc})])(1,:))
                    averageResponse(tt) = nanmean(trialStruct.(stimuli{stimulus}).(['Contrast',num2str(contrasts{cc})])(:,tt));
                    STD(tt) = nanstd(trialStruct.(stimuli{stimulus}).(['Contrast',num2str(contrasts{cc})])(:,tt));
                    SEM(tt) = nanstd(trialStruct.(stimuli{stimulus}).(['Contrast',num2str(contrasts{cc})])(:,tt))/(length(trialStruct.(stimuli{stimulus}).(['Contrast',num2str(contrasts{cc})])(:,tt)) - sum(isnan((trialStruct.(stimuli{stimulus}).(['Contrast',num2str(contrasts{cc})])(:,tt)))));
                end
                
                
                averageResponseMatrix.(stimuli{stimulus}).(['Contrast', contrasts{cc}])(ss,:) = averageResponse;
                averageResponseMatrix.(stimuli{stimulus}).(['Contrast', contrasts{cc}, '_STD'])(ss,:) = STD;
                averageResponseMatrix.(stimuli{stimulus}).(['Contrast', contrasts{cc}, '_SEM'])(ss,:) = SEM;
                
                
            end
        end
    end
else
    load(fullfile(p.Results.pathToAverageResponseMatrix));
end


%% Perform the bootstrapping
% set some variables
nSubjects = length(subjectList);
percentPersistentDistribution = [];

% set up the TPUP fit
thePacket.response.timebase = 0:1/60*1000:18.5*1000;

stimulusStruct = makeStimulusStruct;
thePacket.stimulus = stimulusStruct;

thePacket.kernel = [];
thePacket.metaData = [];

defaultParamsInfo.nInstances = 1;

% Construct the model object
temporalFit = tfeTPUP('verbosity','full');

vlb=[-500, 150, 1, -1000, -1000, -1000]; % these boundaries are necessary to specify until we change how the delay parameter is implemented in the forward model (negative delay currently means push curve to the right). also the range of the amplitude parameters is probably much larger than we need
vub=[0, 400, 20, -0, -0, -0];
initialValues = [-200, 350, 5, -100, -100, -100];

for ii = 1:p.Results.nBootstrapIterations
    
    % get the draw of subjects, with replacement
    bootstrappedSubjectIndices = datasample(1:nSubjects, p.Results.nSubjectsInBootstrapSample);
    
    % get the mean response of this bootstrap samples
    bootstrappedAverageResponse = nanmean(averageResponseMatrix.Melanopsin.Contrast400(bootstrappedSubjectIndices, :));
    
    % do the fit
    thePacket.response.values = bootstrappedAverageResponse;
    [paramsFit,fVal,modelResponseStruct] = ...
        temporalFit.fitResponse(thePacket, ...
        'defaultParamsInfo', defaultParamsInfo, ...
        'vlb', vlb, 'vub',vub, ...
        'initialValues',initialValues);
    
    % calculate percent persistent
    percentPersistent = paramsFit.paramMainMatrix(6)/(paramsFit.paramMainMatrix(4) + paramsFit.paramMainMatrix(5) + paramsFit.paramMainMatrix(6));
    
    % stash the result
    percentPersistentDistribution = [percentPersistentDistribution, percentPersistent];
    
    if p.Results.debugBootstrapPlots
        close all
        figure;
        plot(p.Results.responseTimebase(1:end-40)-1, bootstrappedAverageResponse(1:end-40));
        hold on
        plot(p.Results.responseTimebase(1:end-40)-1, modelResponseStruct.values(1:end-40));
        ylim([-0.8 0.1])
        xlim([0 17])
        xlabel('Time (s)')
        ylabel('Pupil Area (% Change)')
        title(['Percent Persistent: ', num2str(percentPersistent*100), '%']);
    end
    
    
end

%% Do some summary plotting
if p.Results.makePlot
    plotFig = figure;
    histogram(percentPersistentDistribution)
    xlabel('Percent Persistent')
    ylabel('Frequency')
    
    if ~isempty(p.Results.saveName)
        set(plotFig, 'Renderer','painters');
        print(plotFig, [p.Results.saveName, '_N', num2str(p.Results.nSubjectsInBootstrapSample)], '-dpdf');
        save([p.Results.saveName, '_N', num2str(p.Results.nSubjectsInBootstrapSample)], percentPersistentDistribution, '-v7.3');
    end
    
    % compute group mean model fit
    
    % set up the TPUP fit
    thePacket.response.timebase = 0:1/60*1000:18.5*1000;
    
    stimulusStruct = makeStimulusStruct;
    thePacket.stimulus = stimulusStruct;
    
    thePacket.kernel = [];
    thePacket.metaData = [];
    
    defaultParamsInfo.nInstances = 1;
    
    % Construct the model object
    temporalFit = tfeTPUP('verbosity','full');
    
    vlb=[-500, 150, 1, -1000, -1000, -1000]; % these boundaries are necessary to specify until we change how the delay parameter is implemented in the forward model (negative delay currently means push curve to the right). also the range of the amplitude parameters is probably much larger than we need
    vub=[0, 400, 20, -0, -0, -0];
    initialValues = [-200, 350, 5, -100, -100, -100];
    
    averageResponse = nanmean(averageResponseMatrix.Melanopsin.Contrast400);
    
    thePacket.response.values = averageResponse;
    [paramsFit,fVal,modelResponseStruct] = ...
        temporalFit.fitResponse(thePacket, ...
        'defaultParamsInfo', defaultParamsInfo, ...
        'vlb', vlb, 'vub',vub, ...
        'initialValues',initialValues);
    
    plotFig = figure; hold on;
    responseTimebase = 0:1/60:18.5;
    plot(responseTimebase(1:end-40)-1, modelResponseStruct.values(1:end-40));
    percentPersistent = paramsFit.paramMainMatrix(6)/(paramsFit.paramMainMatrix(4) + paramsFit.paramMainMatrix(5) + paramsFit.paramMainMatrix(6));
    minimumDetectableIncreasedPercentPersistent = prctile(percentPersistentDistribution, 95);
    meanTotalAUC = (paramsFit.paramMainMatrix(4) + paramsFit.paramMainMatrix(5) + paramsFit.paramMainMatrix(6));
    newPersistentAmplitude = minimumDetectableIncreasedPercentPersistent * meanTotalAUC;
    
    transientToTransientPlusSustained = paramsFit.paramMainMatrix(4)/(paramsFit.paramMainMatrix(4) + paramsFit.paramMainMatrix(5));
        newParams.paramMainMatrix(6) = newPersistentAmplitude;
    newParams.paramMainMatrix(4) = (meanTotalAUC - newPersistentAmplitude) * transientToTransientPlusSustained;
    newParams.paramMainMatrix(5) = (meanTotalAUC - newPersistentAmplitude) * (1-transientToTransientPlusSustained);
    
    
%     scalarForTransientAndSustainedComponents = (meanTotalAUC - paramsFit.paramMainMatrix(6))/meanTotalAUC;
%     newParams = paramsFit;
%     newParams.paramMainMatrix(6) = newPersistentAmplitude;
%     newParams.paramMainMatrix(4) = paramsFit.paramMainMatrix(4)*(scalarForTransientAndSustainedComponents);
%     newParams.paramMainMatrix(5) = paramsFit.paramMainMatrix(5)*(scalarForTransientAndSustainedComponents);
    
    %     newPersistentAmplitude = (minimumDetectableIncreasedPercentPersistent*paramsFit.paramMainMatrix(4) + paramsFit.paramMainMatrix(5)*minimumDetectableIncreasedPercentPersistent)/(1 - minimumDetectableIncreasedPercentPersistent);
    %     newParams = paramsFit;
    %     newParams.paramMainMatrix(6) = newPersistentAmplitude;
    
    [ newModelResponseStruct ] = temporalFit.computeResponse(newParams, thePacket.stimulus, thePacket.kernel);
    plot((newModelResponseStruct.timebase(1:end-40)-1000)./1000, newModelResponseStruct.values(1:end-40));
    ylim([-0.8 0.1])
    xlim([0 17])
    xlabel('Time (s)')
    ylabel('Pupil Area (% Change)')
    legend({'Mean Response', 'Minimum Detectable Increase in % Persistent'});
    
end