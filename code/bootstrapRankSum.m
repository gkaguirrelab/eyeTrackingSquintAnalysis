sampleSize = 20;
alpha = 0.05;


%effectSizeScalarRange = 1.01:0.01:1.5;
effectSizeScalarRange = 0:0.001:0.25;
%effectSizeScalarRange = 0.07:0.001:0.075;
nBootstrapIterations = 1000;
%hypothesisTest = 't-test';
%hypothesisTest = 'rankSum';
hypothesisTest = 'labelPermutation';

powerDistribution = [];
for effectSizeScalar = effectSizeScalarRange
    probabilityDistribution = [];
    
    for ii = 1:nBootstrapIterations
        
        bootstrapIndicesControls = datasample(1:length(percentPersistentDistribution), sampleSize);
        bootstrapIndicesPatients = datasample(1:length(percentPersistentDistribution), sampleSize);

        percentPersistentControls = percentPersistentDistribution(bootstrapIndicesControls)-effectSizeScalar/2;
        percentPersistentPatients = percentPersistentDistribution(bootstrapIndicesPatients)+effectSizeScalar/2;
        
        % enforce max percentPersistent of 100%
        percentPersistentPatients(percentPersistentPatients>1) = 1;
        percentPersistentControls(percentPersistentControls<0) = 0;


        if strcmp(hypothesisTest, 'rankSum')
            probability = ranksum(percentPersistentControls, percentPersistentPatients, 'tail', 'left');
        elseif strcmp(hypothesisTest, 't-test')
            [~, probability] = ttest2(percentPersistentControls, percentPersistentPatients, 'tail', 'left');
        elseif strcmp(hypothesisTest, 'labelPermutation')
            [probability] = evaluateSignificanceOfMedianDifference(percentPersistentPatients, percentPersistentControls);
        end

        probabilityDistribution = [probabilityDistribution, probability];
    end
    falseNegativeRate = (sum(probabilityDistribution > alpha)/nBootstrapIterations);
    power = 1 - falseNegativeRate;
    powerDistribution = [powerDistribution, power];
end

figure;
plot(effectSizeScalarRange, powerDistribution)
title(['N = ', num2str(sampleSize), ', ', hypothesisTest]);
ylabel('Power')
xlabel('Effect Size (Patients = Controls + Effect Size)')
hold on;
line([0 0.25], [0.8, 0.8], 'Color', 'r', 'LineStyle', '-')

indicesInWhichPowerSurpassesThreshold = find(powerDistribution>0.8);
minimumDetectableEffectSize = (effectSizeScalarRange(indicesInWhichPowerSurpassesThreshold(1)) + effectSizeScalarRange(indicesInWhichPowerSurpassesThreshold(1)-1))/2;
minimumDetectableEffectSize
