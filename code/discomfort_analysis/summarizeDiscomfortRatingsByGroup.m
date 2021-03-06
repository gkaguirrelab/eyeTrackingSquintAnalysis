%% Determine list of studied subjects
dataBasePath = getpref('melSquintAnalysis','melaDataPath');


load(fullfile(getpref('melSquintAnalysis', 'melaAnalysisPath'), 'Experiments/OLApproach_Squint/SquintToPulse/DataFiles/', 'subjectListStruct.mat'));

subjectIDs = fieldnames(subjectListStruct);

%% Pool results
controlDiscomfort = [];
mwaDiscomfort = [];
mwoaDiscomfort = [];

stimuli = {'Melanopsin', 'LMS', 'LightFlux'};
contrasts = {100, 200, 400};



for stimulus = 1:length(stimuli)
    for contrast = 1:length(contrasts)
        controlDiscomfort.(stimuli{stimulus}).(['Contrast', num2str(contrasts{contrast})]) = [];
        mwaDiscomfort.(stimuli{stimulus}).(['Contrast', num2str(contrasts{contrast})]) = [];
        mwoaDiscomfort.(stimuli{stimulus}).(['Contrast', num2str(contrasts{contrast})]) = [];
    end
end


for ss = 1:length(subjectIDs)
    
    
    group = linkMELAIDToGroup(subjectIDs{ss});
    
    analysisBasePath = fullfile(getpref('melSquintAnalysis','melaAnalysisPath'), 'Experiments/OLApproach_Squint/SquintToPulse/DataFiles/', subjectIDs{ss});
    fileName = 'audioTrialStruct_final.mat';
    
    for stimulus = 1:length(stimuli)
        for contrast = 1:length(contrasts)
            if strcmp(group, 'c')
                load(fullfile(analysisBasePath, fileName));
                controlDiscomfort.(stimuli{stimulus}).(['Contrast', num2str(contrasts{contrast})])(end+1) = nanmedian(trialStruct.(stimuli{stimulus}).(['Contrast', num2str(contrasts{contrast})]));
            elseif strcmp(group, 'mwa')
                load(fullfile(analysisBasePath, fileName));
                mwaDiscomfort.(stimuli{stimulus}).(['Contrast', num2str(contrasts{contrast})])(end+1) = nanmedian(trialStruct.(stimuli{stimulus}).(['Contrast', num2str(contrasts{contrast})]));
                
            elseif strcmp(group, 'mwoa')
                load(fullfile(analysisBasePath, fileName));
                mwoaDiscomfort.(stimuli{stimulus}).(['Contrast', num2str(contrasts{contrast})])(end+1) = nanmedian(trialStruct.(stimuli{stimulus}).(['Contrast', num2str(contrasts{contrast})]));
            else
                fprintf('Subject %s has group %s\n', subjectIDs{ss}, group);
            end
        end
    end
    
end


%% Display results
% First by individual migraine group
discomfortRatings = [];
for stimulus = 1:length(stimuli)
    for contrast = 1:length(contrasts)
        discomfortRatings.MwA.(stimuli{stimulus}).(['Contrast', num2str(contrasts{contrast})]) = mwaDiscomfort.(stimuli{stimulus}).(['Contrast', num2str(contrasts{contrast})]);
        discomfortRatings.MwoA.(stimuli{stimulus}).(['Contrast', num2str(contrasts{contrast})]) = mwoaDiscomfort.(stimuli{stimulus}).(['Contrast', num2str(contrasts{contrast})]);
        discomfortRatings.Controls.(stimuli{stimulus}).(['Contrast', num2str(contrasts{contrast})]) = controlDiscomfort.(stimuli{stimulus}).(['Contrast', num2str(contrasts{contrast})]);
    end
end

plotSpreadResults(discomfortRatings, 'yLims', [-0.5, 10], 'yLabel', 'Discomfort Ratings', 'saveName', fullfile(getpref('melSquintAnalysis', 'melaAnalysisPath'), 'melSquintAnalysis', 'discomfortRatings', 'groupAverage.pdf'))

% Next by combine migraineurs
discomfortRatings = [];
for stimulus = 1:length(stimuli)
    for contrast = 1:length(contrasts)
        discomfortRatings.CombinedMigraineurs.(stimuli{stimulus}).(['Contrast', num2str(contrasts{contrast})]) = [mwaDiscomfort.(stimuli{stimulus}).(['Contrast', num2str(contrasts{contrast})]), mwoaDiscomfort.(stimuli{stimulus}).(['Contrast', num2str(contrasts{contrast})])];
        discomfortRatings.Controls.(stimuli{stimulus}).(['Contrast', num2str(contrasts{contrast})]) = controlDiscomfort.(stimuli{stimulus}).(['Contrast', num2str(contrasts{contrast})]);
    end
end

plotSpreadResults(discomfortRatings, 'yLims', [-0.5, 10], 'yLabel', 'Discomfort Ratings', 'saveName', fullfile(getpref('melSquintAnalysis', 'melaAnalysisPath'), 'melSquintAnalysis', 'discomfortRatings', 'groupAverage_combinedMigraineurs.pdf'))

%% summarize discomfort on the basis of median, +/- interquartile range

plotFig = figure; hold on;
[ha, pos] = tight_subplot(1,length(stimuli), 0.08);

% log space x-values, which will represent contrast
x = [1, 2, 3];
stimuli = {'LightFlux', 'Melanopsin', 'LMS'};
for group = 1:3
    
    if group == 1
        
        response = controlDiscomfort;
        color = 'k';
        xOffset = -0.3;
        
    elseif group == 2
        
        response = mwaDiscomfort;
        color = 'b';
        xOffset = 0;
        
    elseif group == 3
        
        response = mwoaDiscomfort;
        color = 'r';
        xOffset = 0.3;
    end
    
    for stimulus = 1:length(stimuli)
        
        axes(ha(stimulus)); hold on;
        
        y = [median(response.(stimuli{stimulus}).Contrast100), median(response.(stimuli{stimulus}).Contrast200), median(response.(stimuli{stimulus}).Contrast400)];
        
        yErrorNeg = [(median(response.(stimuli{stimulus}).Contrast100) - prctile(response.(stimuli{stimulus}).Contrast100, 25)), (median(response.(stimuli{stimulus}).Contrast200) - prctile(response.(stimuli{stimulus}).Contrast200, 25)), (median(response.(stimuli{stimulus}).Contrast400) - prctile(response.(stimuli{stimulus}).Contrast400, 25))];
        yErrorPos = [(prctile(response.(stimuli{stimulus}).Contrast100, 75) - median(response.(stimuli{stimulus}).Contrast100)), (prctile(response.(stimuli{stimulus}).Contrast200, 75) - median(response.(stimuli{stimulus}).Contrast200)), (prctile(response.(stimuli{stimulus}).Contrast400, 75) - median(response.(stimuli{stimulus}).Contrast400))];
        
        errorbar(x+xOffset, y, yErrorNeg, yErrorPos, 'Color', color, 'CapSize', 0);
        plot(x+xOffset,y, '*', 'MarkerSize', 20, 'Color', color);
        
        ylim([-0.5 10.5])
        ylabel('Discomfort Ratings')
        xlim([0.5 3.5])
        xlabel('Contrast')
        xticks([1, 2, 3])
        xticklabels({'100%', '200%', '400%'})
        title(stimuli{stimulus});
        yticks([0 5 10])
        yticklabels({0 5 10})
    end
end

export_fig(plotFig, fullfile(getpref('melSquintAnalysis', 'melaAnalysisPath'), 'melSquintAnalysis', 'discomfortRatings', 'mediansWithIQR.pdf'));

%% summary figrue proposed by geoff:
stimuli = {'LightFlux', 'Melanopsin', 'LMS'};
groups = {'controls', 'mwa', 'mwoa'};

[ discomfortRatingsStruct ] = loadDiscomfortRatings;
[ slope, intercept, meanRating ] = fitLineToResponseModality('discomfortRatings', 'makePlots', false, 'makeCSV', false);

x = [log10(100), log10(200), log10(400)];

counter = 1;
[ha, pos] = tight_subplot(3,3, 0.04);

for stimulus = 1:length(stimuli)
    
    for group = 1:length(groups)
        
        if strcmp(groups{group}, 'controls')
            color = 'k';
        elseif strcmp(groups{group}, 'mwa')
            color = 'b';
        elseif strcmp(groups{group}, 'mwoa')
            color = 'r';
        end
        
        
        axes(ha(counter)); hold on;
        result = discomfortRatingsStruct.([groups{group}]);
        data = [result.(stimuli{stimulus}).Contrast100; result.(stimuli{stimulus}).Contrast200; result.(stimuli{stimulus}).Contrast400];
        
        plotSpread(data', 'xValues', x, 'xNames', {'100%', '200%', '400%'}, 'distributionColors', color)
        set(findall(gcf,'type','line'),'markerSize',13)
        yticks([0 5 10])
        
        if group  == 1
            if stimulus == 1
                ylabel({'{\bf\fontsize{15} Light Flux}'; 'Discomfort Rating'})
            elseif stimulus == 2
                ylabel({'{\bf\fontsize{15} Melanopsin}'; 'Discomfort Rating'})
                
            elseif stimulus == 3
                ylabel({'{\bf\fontsize{15} LMS}'; 'Discomfort Rating'})
                
            end
            
           
            yticks([0 5 10]);
            yticklabels([0 5 10]);
        end
         ylim([0 10.5]);
        
        counter = counter + 1;
        
        
        
    end
end

% add titles to the columns
axes(ha(1));
title({'\fontsize{15} Controls'});
axes(ha(2));
title({'\fontsize{15} MwA'});
axes(ha(3));
title({'\fontsize{15} MwoA'});


% add means
counter = 1;
for stimulus = 1:length(stimuli)
    
    for group = 1:length(groups)
        
        if strcmp(groups{group}, 'controls')
            color = 'k';
        elseif strcmp(groups{group}, 'mwa')
            color = 'b';
        elseif strcmp(groups{group}, 'mwoa')
            color = 'r';
        end
        
        axes(ha(counter)); hold on;
        result = discomfortRatingsStruct.([groups{group}]);
        
        plot(x, [mean(result.(stimuli{stimulus}).Contrast100), mean(result.(stimuli{stimulus}).Contrast200), mean(result.(stimuli{stimulus}).Contrast400)], '.', 'Color', color, 'MarkerSize', 25)
        counter = counter + 1;
    end
end

% add line fits
counter = 1;
for stimulus = 1:length(stimuli)
    
    for group = 1:length(groups)
        
        
        if strcmp(groups{group}, 'controls')
            color = 'k';
            groupName = 'controls';
        elseif strcmp(groups{group}, 'mwa')
            color = 'b';
            groupName = 'mwa';
        elseif strcmp(groups{group}, 'mwoa')
            color = 'r';
            groupName = 'mwoa';
        end
        y = x*mean(slope.(groupName).(stimuli{stimulus})) + mean(intercept.(groupName).(stimuli{stimulus}));
        axes(ha(counter)); hold on;
        plot(x,y, 'Color', color)
        counter = counter + 1;
        
        
    end
end



% to make the markers transparent. for whatever reason, the effect doesn't
% stick so you have to run it manually?
drawnow()
test = findall(gcf,'type','line');
for ii = 1:length(test)
    if strcmp(test(ii).DisplayName, '100%') ||  strcmp(test(ii).DisplayName, '200%') ||  strcmp(test(ii).DisplayName, '400%')
        hMarkers = [];
        hMarkers = test(ii).MarkerHandle;
        hMarkers.EdgeColorData(4) = 75;
    end
end
set(gcf, 'Position', [600 558 1060 620]);
set(gcf, 'Renderer', 'painters');

export_fig(gcf, fullfile(getpref('melSquintAnalysis', 'melaAnalysisPath'), 'melSquintAnalysis', 'discomfortRatings', 'summary_groupxstimulus.pdf'))
