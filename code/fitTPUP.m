function [ modeledResponses, averageResponses ] = fitTPUP(subjectID, varargin)
%{
subjectID = 'MELA_0126';

%}

%% Parse the input

p = inputParser; p.KeepUnmatched = true;

p.addParameter('method','fixGamma',@ischar);
p.addParameter('determineGammaTau',true,@islogical);
p.addParameter('numberOfResponseIndicesToExclude', 40, @isnumeric);
p.addParameter('plotGroupAverageFits', false, @islogical);
p.addParameter('plotFits', true, @islogical);
p.addParameter('printParams', true, @islogical);


p.parse(varargin{:});

%% Get the average responses


%% Perform the fitting
if strcmp(p.Results.method, 'fixGamma')
    
    % First, determine the persistentGammaTau to be used across all
    % subjects
    if p.Results.determineGammaTau || strcmp(subjectID, 'group')
        % load average responses across all subjects
        load(fullfile(getpref('melSquintAnalysis', 'melaAnalysisPath'), 'Experiments/OLApproach_Squint/SquintToPulse/DataFiles/averageResponsePlots/groupAverageMatrix.mat'));
        
        % compute group average responses, including NaNing poor indices (at
        % the beginning and the end)
        
        melanopsinResponse = nanmean(averageResponseMatrix.Melanopsin.Contrast400);
        melanopsinResponse(1:p.Results.numberOfResponseIndicesToExclude) = NaN;
        melanopsinResponse(end-p.Results.numberOfResponseIndicesToExclude:end) = NaN;
        
        LMSResponse = nanmean(averageResponseMatrix.LMS.Contrast400);
        LMSResponse(1:p.Results.numberOfResponseIndicesToExclude) = NaN;
        LMSResponse(end-p.Results.numberOfResponseIndicesToExclude:end) = NaN;
        
        lightFluxResponse = nanmean(averageResponseMatrix.LightFlux.Contrast400);
        lightFluxResponse(1:p.Results.numberOfResponseIndicesToExclude) = NaN;
        lightFluxResponse(end-p.Results.numberOfResponseIndicesToExclude:end) = NaN;
        
        % assemble the responseStruct of the packet. To fix parameters,
        % we'll be concatenating these responses together.
        thePacket.response.values = [LMSResponse, melanopsinResponse, lightFluxResponse];
        thePacket.response.timebase = 0:1/60*1000:length(thePacket.response.values)*1/60 * 1000 - 1/60 * 1000;
        
        % assemble the stimuluStruct of the packet.
        stimulusStruct = makeStimulusStruct;
        % resample stimulus to match response
        resampledStimulusTimebase = 0:1/60*1000:1/60*length(nanmean(averageResponseMatrix.Melanopsin.Contrast400))*1000-1/60*1000;
        resampledStimulusProfile = interp1(stimulusStruct.timebase, stimulusStruct.values, resampledStimulusTimebase);
        thePacket.stimulus = [];
        thePacket.stimulus.timebase = thePacket.response.timebase;
        thePacket.stimulus.values = resampledStimulusProfile;
        thePacket.stimulus.values(length(resampledStimulusProfile)+1:length(thePacket.stimulus.timebase)) = 0;
        
        % assemble the rest of the packet
        thePacket.kernel = [];
        thePacket.metaData = [];
        defaultParamsInfo.nInstances = 1;
        
        % Construct the model object
        temporalFit = tfeHPUP('verbosity','full');
        
        % perform the fit
        [paramsFit,fVal,modelResponseStruct] = ...
            temporalFit.fitResponse(thePacket, ...
            'defaultParamsInfo', defaultParamsInfo, ...
            'fminconAlgorithm','sqp');
        
        % extract the persistent gamma tau that best describes the combined group
        % response
        groupAveragePersistentGammaTau = paramsFit.paramMainMatrix(2);
        
        % summarizing the group average model fit
        LMSFit = modelResponseStruct.values(1:length(modelResponseStruct.values)/3);
        melanopsinFit = modelResponseStruct.values(length(modelResponseStruct.values)/3+1:length(modelResponseStruct.values)/3*2);
        lightFluxFit = modelResponseStruct.values(length(modelResponseStruct.values)/3*2+1:end);
        
        if p.Results.plotGroupAverageFits || strcmp(subjectID, 'group')
            plotFig = figure;
            ax1 = subplot(1,3,1); hold on;
            plot(resampledStimulusTimebase/1000, LMSResponse, 'Color', 'k');
            plot(resampledStimulusTimebase/1000, LMSFit, 'Color', 'r');
            xlabel('Time (s)')
            ylabel('Pupil Area (% Change)');
            title('LMS')
            legend('Group average response', 'Model fit')
            
            ax2 = subplot(1,3,2); hold on;
            plot(resampledStimulusTimebase/1000, melanopsinResponse, 'Color', 'k');
            plot(resampledStimulusTimebase/1000, melanopsinFit, 'Color', 'r');
            xlabel('Time (s)')
            ylabel('Pupil Area (% Change)');
            title('Melanopsin')
            legend('Group average response', 'Model fit')
            
            ax3 = subplot(1,3,3); hold on;
            plot(resampledStimulusTimebase/1000, lightFluxResponse, 'Color', 'k');
            plot(resampledStimulusTimebase/1000, lightFluxFit, 'Color', 'r');
            xlabel('Time (s)')
            ylabel('Pupil Area (% Change)');
            title('Light Flux')
            legend('Group average response', 'Model fit')
            
            linkaxes([ax1, ax2, ax3]);
            
            set(gcf, 'Position', [29 217 1661 761]);
            
            fprintf(' <strong>Fitting group average response </strong>\n');
            temporalFit.paramPrint(paramsFit);
            fprintf('\n');
            
        end
        
        % stash out results if we're just looking for the group average
        % response
        if strcmp(subjectID, 'group')
            modeledResponses.LMS.timebase = resampledStimulusTimebase;
            modeledResponses.LMS.values = LMSFit;
            modeledResponses.LMS.params.paramNameCell = {'gammaTau', 'persistentGammaTau', 'LMSExponentialTau', 'LMSAmplitudeTransient', 'LMSAmplitudeSustained', 'LMSAmplitudePersistent'};
            for ii = 1:length(modeledResponses.LMS.params.paramNameCell)
                modeledResponses.LMS.params.paramMainMatrix(ii) =  paramsFit.paramMainMatrix(:,strcmp(paramsFit.paramNameCell,modeledResponses.LMS.params.paramNameCell{ii}));
            end
            modeledResponses.Melanopsin.timebase = resampledStimulusTimebase;
            modeledResponses.Melanopsin.values = melanopsinFit;
            modeledResponses.Melanopsin.params.paramNameCell = {'gammaTau', 'persistentGammaTau', 'MelanopsinExponentialTau', 'MelanopsinAmplitudeTransient', 'MelanopsinAmplitudeSustained', 'MelanopsinAmplitudePersistent'};
            for ii = 1:length(modeledResponses.Melanopsin.params.paramNameCell)
                modeledResponses.Melanopsin.params.paramMainMatrix(ii) =  paramsFit.paramMainMatrix(:,strcmp(paramsFit.paramNameCell,modeledResponses.Melanopsin.params.paramNameCell{ii}));
            end
            modeledResponses.LightFlux.timebase = resampledStimulusTimebase;
            modeledResponses.LightFlux.values = lightFluxFit;
            modeledResponses.LightFlux.params.paramNameCell = {'gammaTau', 'persistentGammaTau', 'LightFluxExponentialTau', 'LightFluxAmplitudeTransient', 'LightFluxAmplitudeSustained', 'LightFluxAmplitudePersistent'};
            for ii = 1:length(modeledResponses.LightFlux.params.paramNameCell)
                modeledResponses.LightFlux.params.paramMainMatrix(ii) =  paramsFit.paramMainMatrix(:,strcmp(paramsFit.paramNameCell,modeledResponses.LightFlux.params.paramNameCell{ii}));
            end
        
           
           averageResponses.LMS = LMSResponse;
           averageResponses.Melanopsin = melanopsinResponse;
           averageResponses.LightFlux = lightFluxResponse;
        end
        
        
    end
    
    % perform the search the average responses for the individual subject
    if ~strcmp(subjectID, 'group')
        
                % load average responses across all subjects
        load(fullfile(getpref('melSquintAnalysis', 'melaAnalysisPath'), 'Experiments/OLApproach_Squint/SquintToPulse/DataFiles/', subjectID, 'trialStruct_postSpotcheck.mat'));
        
        % compute group average responses, including NaNing poor indices (at
        % the beginning and the end)
        
        melanopsinResponse = nanmean(trialStruct.Melanopsin.Contrast400);
        melanopsinResponse(1:p.Results.numberOfResponseIndicesToExclude) = NaN;
        melanopsinResponse(end-p.Results.numberOfResponseIndicesToExclude:end) = NaN;
        
        LMSResponse = nanmean(trialStruct.LMS.Contrast400);
        LMSResponse(1:p.Results.numberOfResponseIndicesToExclude) = NaN;
        LMSResponse(end-p.Results.numberOfResponseIndicesToExclude:end) = NaN;
        
        lightFluxResponse = nanmean(trialStruct.LightFlux.Contrast400);
        lightFluxResponse(1:p.Results.numberOfResponseIndicesToExclude) = NaN;
        lightFluxResponse(end-p.Results.numberOfResponseIndicesToExclude:end) = NaN;
        
        % assemble the responseStruct of the packet. To fix parameters,
        % we'll be concatenating these responses together.
        thePacket.response.values = [LMSResponse, melanopsinResponse, lightFluxResponse];
        thePacket.response.timebase = 0:1/60*1000:length(thePacket.response.values)*1/60 * 1000 - 1/60 * 1000;
        
        % assemble the stimuluStruct of the packet.
        stimulusStruct = makeStimulusStruct;
        % resample stimulus to match response
        resampledStimulusTimebase = 0:1/60*1000:1/60*length(nanmean(averageResponseMatrix.Melanopsin.Contrast400))*1000-1/60*1000;
        resampledStimulusProfile = interp1(stimulusStruct.timebase, stimulusStruct.values, resampledStimulusTimebase);
        thePacket.stimulus = [];
        thePacket.stimulus.timebase = thePacket.response.timebase;
        thePacket.stimulus.values = resampledStimulusProfile;
        thePacket.stimulus.values(length(resampledStimulusProfile)+1:length(thePacket.stimulus.timebase)) = 0;
        
        % assemble the rest of the packet
        thePacket.kernel = [];
        thePacket.metaData = [];
        defaultParamsInfo.nInstances = 1;
        
        % Construct the model object
        temporalFit = tfeHPUP('verbosity','full');
        
        % set up initial parameters. This is how we're going to fix the
        % persistentGammaTau
        vlb = ...
            [1, ...         % 'gammaTau',
            1, ...          % 'persistentGammaTau'
            -500, ...       % 'LMSDelay'
            1, ...          % 'LMSExponentialTau'
            -10, ...        % 'LMSTransient'
            -10, ...        % 'LMSSustained'
            -10,...         % 'LMSPersistent'
            -500, ...       % 'MelanopsinDelay'
            1, ...          % 'MelanopsinExponentialTau'
            -10, ...        % 'MelanopsinTransient'
            -10, ...        % 'MelanopsinSustained'
            -10,...         % 'MelanopsinPersistent'
            -500, ...       % 'LightFluxDelay'
            1, ...          % 'LightFluxExponentialTau'
            -10, ...        % 'LightFluxTransient'
            -10, ...        % 'LightFluxSustained'
            -10];           % 'LightFluxPersistent'
        
        vub = ...
            [1000, ...      % 'gammaTau',
            1000, ...       % 'persistentGammaTau'
            0, ...          % 'LMSDelay'
            20, ...         % 'LMSExponentialTau'
            0, ...          % 'LMSTransient'
            0, ...          % 'LMSSustained'
            0,...           % 'LMSPersistent'
            0, ...          % 'MelanopsinDelay'
            20, ...         % 'MelanopsinExponentialTau'
            0, ...          % 'MelanopsinTransient'
            0, ...          % 'MelanopsinSustained'
            0,...           % 'MelanopsinPersistent'
            0, ...          % 'LightFluxDelay'
            20, ...         % 'LightFluxExponentialTau'
            0, ...          % 'LightFluxTransient'
            0, ...          % 'LightFluxSustained'
            0];             % 'LightFluxPersistent'        
        
        initialValues = ...
           [200, ...       % 'gammaTau',
            200, ...       % 'persistentGammaTau'
            -200, ...      % 'LMSDelay'
            10, ...        % 'LMSExponentialTau'
            -1, ...        % 'LMSTransient'
            -1, ...        % 'LMSSustained'
            -1,...         % 'LMSPersistent'
            -200, ...      % 'MelanopsinDelay'
            10, ...        % 'MelanopsinExponentialTau'
            -1, ...        % 'MelanopsinTransient'
            -1, ...        % 'MelanopsinSustained'
            -1,...         % 'MelanopsinPersistent'
            -200, ...      % 'LightFluxDelay'
            1, ...         % 'LightFluxExponentialTau'
            -1, ...        % 'LightFluxTransient'
            -1, ...        % 'LightFluxSustained'
            -1];           % 'LightFluxPersistent'  
        
        % perform the fit
        [paramsFit,fVal,modelResponseStruct] = ...
            temporalFit.fitResponse(thePacket, ...
            'vlb', vlb, 'vub', vub, 'intialValues', initialValues, ...
            'defaultParamsInfo', defaultParamsInfo, ...
            'fminconAlgorithm','sqp');
        
        if p.Results.printParams
                fprintf(' <strong>Fitting %s response </strong>\n', subjectID);
                temporalFit.paramPrint(paramsFit);
                fprintf('\n');
        end
        
        % extract the persistent gamma tau that best describes the combined group
        % response
        groupAveragePersistentGammaTau = paramsFit.paramMainMatrix(2);
        
        % summarizing the group average model fit
        LMSFit = modelResponseStruct.values(1:length(modelResponseStruct.values)/3);
        melanopsinFit = modelResponseStruct.values(length(modelResponseStruct.values)/3+1:length(modelResponseStruct.values)/3*2);
        lightFluxFit = modelResponseStruct.values(length(modelResponseStruct.values)/3*2+1:end);
        
        if p.Results.plotFits
            plotFig = figure;
            ax1 = subplot(1,3,1); hold on;
            plot(resampledStimulusTimebase/1000, LMSResponse, 'Color', 'k');
            plot(resampledStimulusTimebase/1000, LMSFit, 'Color', 'r');
            xlabel('Time (s)')
            ylabel('Pupil Area (% Change)');
            title('LMS')
            legend('Average response', 'Model fit')
            
            ax2 = subplot(1,3,2); hold on;
            plot(resampledStimulusTimebase/1000, melanopsinResponse, 'Color', 'k');
            plot(resampledStimulusTimebase/1000, melanopsinFit, 'Color', 'r');
            xlabel('Time (s)')
            ylabel('Pupil Area (% Change)');
            title('Melanopsin')
            legend('Average response', 'Model fit')
            
            ax3 = subplot(1,3,3); hold on;
            plot(resampledStimulusTimebase/1000, lightFluxResponse, 'Color', 'k');
            plot(resampledStimulusTimebase/1000, lightFluxFit, 'Color', 'r');
            xlabel('Time (s)')
            ylabel('Pupil Area (% Change)');
            title('Light Flux')
            legend('Average response', 'Model fit')
            
            linkaxes([ax1, ax2, ax3]);
            
            set(gcf, 'Position', [29 217 1661 761]);
            
        end
        
        % stash out results 
        modeledResponses.LMS.timebase = resampledStimulusTimebase;
        modeledResponses.LMS.values = LMSFit;
        modeledResponses.LMS.params.paramNameCell = {'gammaTau', 'persistentGammaTau', 'LMSExponentialTau', 'LMSAmplitudeTransient', 'LMSAmplitudeSustained', 'LMSAmplitudePersistent'};
        for ii = 1:length(modeledResponses.LMS.params.paramNameCell)
           modeledResponses.LMS.params.paramMainMatrix(ii) =  paramsFit.paramMainMatrix(:,strcmp(paramsFit.paramNameCell,modeledResponses.LMS.params.paramNameCell{ii}));
        end
        modeledResponses.Melanopsin.timebase = resampledStimulusTimebase;
        modeledResponses.Melanopsin.values = melanopsinFit;
        modeledResponses.Melanopsin.params.paramNameCell = {'gammaTau', 'persistentGammaTau', 'MelanopsinExponentialTau', 'MelanopsinAmplitudeTransient', 'MelanopsinAmplitudeSustained', 'MelanopsinAmplitudePersistent'};
        for ii = 1:length(modeledResponses.Melanopsin.params.paramNameCell)
            modeledResponses.Melanopsin.params.paramMainMatrix(ii) =  paramsFit.paramMainMatrix(:,strcmp(paramsFit.paramNameCell,modeledResponses.Melanopsin.params.paramNameCell{ii}));
        end
        modeledResponses.LightFlux.timebase = resampledStimulusTimebase;
        modeledResponses.LightFlux.values = lightFluxFit;
        modeledResponses.LightFlux.params.paramNameCell = {'gammaTau', 'persistentGammaTau', 'LightFluxExponentialTau', 'LightFluxAmplitudeTransient', 'LightFluxAmplitudeSustained', 'LightFluxAmplitudePersistent'};
        for ii = 1:length(modeledResponses.LightFlux.params.paramNameCell)
            modeledResponses.LightFlux.params.paramMainMatrix(ii) =  paramsFit.paramMainMatrix(:,strcmp(paramsFit.paramNameCell,modeledResponses.LightFlux.params.paramNameCell{ii}));
        end        
        
        averageResponses.LMS.values = LMSResponse;
        averageResponses.Melanopsin.values = melanopsinResponse;
        averageResponses.LightFlux.values = lightFluxResponse;
        
        
        
        
    end
    
    
    
    
    
else
    
    
    
    
    
end




end