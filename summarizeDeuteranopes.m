subjectStruct = getDeuteranopeSubjectStruct;
stimuli = {'LightFlux', 'Melanopsin',  'LS'};

%% Summarize pupillometry
fitType = 'initial';
saveNameSuffix = '_postSpotCheck';

for experiment = 1:2
    experimentName = ['experiment_', num2str(experiment)];
    subjectIDs = fieldnames(subjectStruct.(['experiment', num2str(experiment)]));
    
    if experiment == 1
        contrasts = {100, 200, 400};
    elseif experiment == 2
        contrasts = {400, 800, 1200};
        
    end
    
    for ss = 1:5
        
        makeSubjectAverageResponses(subjectIDs{ss}, 'experimentName', experimentName, 'stimuli', stimuli, 'contrasts', contrasts, 'Protocol', 'Deuteranopes', 'protocolShortName', 'Deuteranopes','blinkBufferFrames', [3 6], 'saveNameSuffix', saveNameSuffix, 'sessions', subjectStruct.(['experiment', num2str(experiment)]).(subjectIDs{ss}))
        
    end
end

%% Summarize discomfort ratings

fileName = 'audioTrialStruct_final.mat';
discomfort = [];

% pre-allocate results variable
for experiment = 1:2
    
    if experiment == 1
        contrasts = {100, 200, 400};
    elseif experiment == 2
        contrasts = {400, 800, 1200};
    end
    
    for stimulus = 1:length(stimuli)
        for contrast = 1:length(contrasts)
            
            discomfort.(['experiment', num2str(experiment)]).(stimuli{stimulus}).(['Contrast', num2str(contrasts{contrast})]) = [];
        end
        
    end
end

% pool results
for experiment = 1:2
    experimentName = ['experiment_', num2str(experiment)];
    subjectIDs = fieldnames(subjectStruct.(['experiment', num2str(experiment)]));
    
    if experiment == 1
        contrasts = {100, 200, 400};
    elseif experiment == 2
        contrasts = {400, 800, 1200};
        
    end
    
    for ss = 1:5
        analysisBasePath = fullfile(getpref('melSquintAnalysis','melaAnalysisPath'), 'Experiments/OLApproach_Squint/Deuteranopes/DataFiles/', subjectIDs{ss}, ['experiment_', num2str(experiment)]);
        load(fullfile(analysisBasePath, fileName));
        for stimulus = 1:length(stimuli)
            for contrast = 1:length(contrasts)
                discomfort.(['experiment', num2str(experiment)]).(stimuli{stimulus}).(['Contrast', num2str(contrasts{contrast})])(end+1) = nanmedian(trialStruct.(stimuli{stimulus}).(['Contrast', num2str(contrasts{contrast})]));
            end
        end
        
    end
end

% plot results
for experiment = 1:2
    discomfortRating.Controls = discomfort.(['experiment', num2str(experiment)]);
    if experiment == 1
        contrasts = {100, 200, 400};
    elseif experiment == 2
        contrasts = {400, 800, 1200};
        
    end
    
    savePath = fullfile(getpref('melSquintAnalysis', 'melaAnalysisPath'), 'melSquintAnalysis', 'discomfortRatings', 'deuteranopes');
    plotSpreadResults(discomfortRating, 'stimuli', stimuli, 'contrasts', contrasts, 'saveName', fullfile(savePath, ['groupSummary_experiment', num2str(experiment), '.pdf']))
    
    
end

plotFig = figure; 
for stimulus = 1:length(stimuli)
    subplot(1,3,stimulus); hold on;
    title(stimuli{stimulus});
    data = [discomfort.experiment1.(stimuli{stimulus}).Contrast100; discomfort.experiment1.(stimuli{stimulus}).Contrast200; discomfort.experiment1.(stimuli{stimulus}).Contrast400];
    plotSpread(data', 'xValues', [log10(100), log10(200), log10(400)], 'distributionColors', 'k')
    plot([log10(100), log10(200), log10(400)], [median(discomfort.experiment1.(stimuli{stimulus}).Contrast100), median(discomfort.experiment1.(stimuli{stimulus}).Contrast200), median(discomfort.experiment1.(stimuli{stimulus}).Contrast400)], '*', 'Color', 'k')
    experiment1Plot = plot([log10(100), log10(200), log10(400)], [median(discomfort.experiment1.(stimuli{stimulus}).Contrast100), median(discomfort.experiment1.(stimuli{stimulus}).Contrast200), median(discomfort.experiment1.(stimuli{stimulus}).Contrast400)], 'Color', 'k');

    
    data = [discomfort.experiment2.(stimuli{stimulus}).Contrast400; discomfort.experiment2.(stimuli{stimulus}).Contrast800; discomfort.experiment2.(stimuli{stimulus}).Contrast1200];
    plotSpread(data', 'xValues', [log10(400), log10(800), log10(1200)], 'distributionColors', 'r')
    plot([log10(400), log10(800), log10(1200)], [median(discomfort.experiment2.(stimuli{stimulus}).Contrast400), median(discomfort.experiment2.(stimuli{stimulus}).Contrast800), median(discomfort.experiment2.(stimuli{stimulus}).Contrast1200)], '*', 'Color', 'r')
    experiment2Plot = plot([log10(400), log10(800), log10(1200)], [median(discomfort.experiment2.(stimuli{stimulus}).Contrast400), median(discomfort.experiment2.(stimuli{stimulus}).Contrast800), median(discomfort.experiment2.(stimuli{stimulus}).Contrast1200)], 'Color', 'r');

    
    xticks([log10(100), log10(200), log10(400), log10(800), log10(1200)]);
    xticklabels({'100%', '200%', '400%', '800%', '1200%'});
    xtickangle(45);
    xlabel('Contrast')
    
    ylim([-0.5 10]);
    ylabel('Discomfort Rating')
    
    if stimulus == 3
       legend([experiment1Plot, experiment2Plot], 'Experiment 1', 'Experiment 2'); 
       legend('boxoff')
    end
end
set(plotFig, 'Position', [680 460 968 518]);
export_fig(plotFig, fullfile(savePath, 'combinedExperimentsSummary.pdf');



