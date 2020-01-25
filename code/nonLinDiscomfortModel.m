discomfortStruct = loadDiscomfortRatings();

groups = {'control','mwa','mwoa'};
colors = {'k','b','r'};
params = {'melScale','minkowski','slope','intercept'};
BinWidths = [0.025,0.1,0.1,0.25];
yLims = {[0 1],[0 4],[0 6],[0 6]};
yLabels = {'alpha','beta','slope','offset'};
nBoots = 1000;
figure
options = optimset('fmincon');
options.Display = 'off';

p =[];
pB = [];

for ii = 1:length(groups)
    
    dVeridcal = [];
    Mc = [];
    Lc = [];
    
    % Assemble the melanopsin and cone contrasts for each discomfort rating.
    % We treat light flux stimuli as having equal contrast on the mel and LMS
    % photoreceptor pools.
    McFull = [ ...
        repmat(100,1,20); ...
        repmat(200,1,20); ...
        repmat(400,1,20); ...
        repmat(0,1,20); ...
        repmat(0,1,20); ...
        repmat(0,1,20); ...
        repmat(100,1,20); ...
        repmat(200,1,20); ...
        repmat(400,1,20); ...
        ];
    
    Mc = reshape(McFull,1,180);
    
    LcFull = [ ...
        repmat(0,1,20); ...
        repmat(0,1,20); ...
        repmat(0,1,20); ...
        repmat(100,1,20); ...
        repmat(200,1,20); ...
        repmat(400,1,20); ...
        repmat(100,1,20); ...
        repmat(200,1,20); ...
        repmat(400,1,20); ...
        ];
    
    Lc = reshape(LcFull,1,180);
    
    % Assemble the discomfort ratings
    groupField = [groups{ii} 'Discomfort'];
    dVeridical = [ ...
        discomfortStruct.(groupField).Melanopsin.Contrast100; ...
        discomfortStruct.(groupField).Melanopsin.Contrast200; ...
        discomfortStruct.(groupField).Melanopsin.Contrast400; ...
        discomfortStruct.(groupField).LMS.Contrast100; ...
        discomfortStruct.(groupField).LMS.Contrast200; ...
        discomfortStruct.(groupField).LMS.Contrast400; ...
        discomfortStruct.(groupField).LightFlux.Contrast100; ...
        discomfortStruct.(groupField).LightFlux.Contrast200; ...
        discomfortStruct.(groupField).LightFlux.Contrast400; ...
        ];
    
    % Anonymous functions for the model
    myModel = @(k) ((k(1).*Mc).^k(2) + Lc.^k(2)).^(1/k(2));
    myMedianModel = @(k) ((k(1).*median(McFull,2)).^k(2) + median(LcFull,2).^k(2)).^(1/k(2));    
    myLogLinFit = @(k,m) m(1).*log10(myModel(k))+m(2);
        
    %% Bootstrap
    for bb = 1:nBoots
        
        % Resample across columns (subjects) with replacement
        d = dVeridical(:,datasample(1:20,20));
                
        % Reshape the values into a vector
        d = reshape(d,1,180);

        % L1 objective function to optimize for the median
%        myObj = @(p) sum(abs(d - myLogLinFit(p(1:2),p(3:4))));

        % L2 objective function to optimize for the mean
        myObj = @(p) sqrt(sum( (d - myLogLinFit(p(1:2),p(3:4))).^2 ));

        % Fit that sucker
        pB(ii,bb,:) = fmincon(myObj,[1 1 1 1],[],[],[],[],[0.1 1 0 -10],[2 5 Inf 10],[],options);
       
    end
    
    % Obtain the median param values and plot these
    p = median(squeeze(pB(ii,:,:)));    
    subplot(1,3,ii);  hold on
    %h = scatter(log10(myModel(p(1:2))),reshape(dVeridical,1,180),'o','MarkerFaceColor',colors{ii},'MarkerEdgeColor','none');
    
    dVeridical_reshaped = reshape(dVeridical,1,180);
    
    ipRGCContrastValues = unique(log10(myModel(p(1:2))));
    ipRGCContrastValues_Mel = [ipRGCContrastValues(1), ipRGCContrastValues(4), ipRGCContrastValues(7)];
    ipRGCContrastValues_LMS = [ipRGCContrastValues(2), ipRGCContrastValues(5), ipRGCContrastValues(8)];
    ipRGCContrastValues_LightFlux = [ipRGCContrastValues(3), ipRGCContrastValues(6), ipRGCContrastValues(9)];
    
    melResponses = dVeridical(1:3,:);
    lmsResponses = dVeridical(4:6,:);
    LFResponses = dVeridical(7:9,:);
    
    m = scatter(repmat(ipRGCContrastValues_Mel, 1, 20), melResponses(:), '^', 'MarkerFaceColor',colors{ii},'MarkerEdgeColor','none');
    m.MarkerFaceAlpha = .2;
    
    lms = scatter(repmat(ipRGCContrastValues_LMS, 1, 20), lmsResponses(:), 's', 'MarkerFaceColor',colors{ii},'MarkerEdgeColor','none');
    lms.MarkerFaceAlpha = .2;
    
    lf = scatter(repmat(ipRGCContrastValues_LightFlux, 1, 20), LFResponses(:), 'o', 'MarkerFaceColor',colors{ii},'MarkerEdgeColor','none');
    lf.MarkerFaceAlpha = .2;
    
   
    
    % Add the median discomfort ratings across subjects
    % plot(log10(myMedianModel(p(1:2))),median(dVeridical,2),['o' colors{ii}],'MarkerSize',14)
    melMedian = plot(ipRGCContrastValues_Mel, [median(discomfortStruct.(groupField).Melanopsin.Contrast100), median(discomfortStruct.(groupField).Melanopsin.Contrast200), median(discomfortStruct.(groupField).Melanopsin.Contrast400)], ['^' colors{ii}],'MarkerSize',14);
    lmsMedian = plot(ipRGCContrastValues_LMS, [median(discomfortStruct.(groupField).LMS.Contrast100), median(discomfortStruct.(groupField).LMS.Contrast200), median(discomfortStruct.(groupField).LMS.Contrast400)], ['s' colors{ii}],'MarkerSize',16);
    LFMedian = plot(ipRGCContrastValues_LightFlux, [median(discomfortStruct.(groupField).LightFlux.Contrast100), median(discomfortStruct.(groupField).LightFlux.Contrast200), median(discomfortStruct.(groupField).LightFlux.Contrast400)], ['o' colors{ii}],'MarkerSize',14);

    
    % Add the model fit line
    reflineHandle = refline(p(3),p(4));
    reflineHandle.Color = colors{ii};
    ylim([0 10]);
    xlim([1.5 3]);
    xticks([log10(50) log10(100) log10(200) log10(400) log10(800)])
    xticklabels({'0.5','1','2','4','8'})
    title(groups{ii});
    
    if ii == 1
        [legendHandle, icons] = legend([melMedian, lmsMedian, LFMedian], 'Melanopsin', 'Cones', 'LightFlux', 'Location', 'NorthWest', 'box', 'off');
        icons(5).MarkerSize = 7;
        icons(7).MarkerSize = 7;
        icons(9).MarkerSize = 7;
    end
    
end

% Convert the intercept into the response at log(200%)
pB(:,:,4) = pB(:,:,4)+pB(:,:,3).*log10(200);
params = {'melScale','minkowski','slope','amplitudeAt200'};

% Plot the median and 95% CI of the parameters
figure
for pp=1:4
    subplot(1,4,pp);
    outline = [params{pp} ' [95 CI] --- '];
    for ii = 1:3
        vals = sort(squeeze(pB(ii,:,pp)));
        p = median(vals);        
        p95low = vals(round(nBoots*0.025));
        p95hi = vals(round(nBoots*0.925));
        plot(ii,p,['o',colors{ii}]);
        hold on
        plot([ii ii],[p95low p95hi],['-',colors{ii}]);
        outline = sprintf([outline groups{ii} ': %2.2f [%2.2f - %2.2f]; '],p,p95low,p95hi);
        if ii>1
            df=20;
            controlVals = sort(squeeze(pB(1,:,pp)));
            meanC = mean(controlVals);
            meanV = mean(vals);
            sdC = sqrt(std(controlVals));
            sdV = sqrt(std(vals));
            sdPooled = sqrt( ((df-1)*sdC^2 + (df-1)*sdV^2)/(df*2-2) );
            se = sdPooled * sqrt( 1/df + 1/df);
            t = (meanV - meanC)/se;
            prob = 2*tpdf(t,df*2-2);
            outline = sprintf([outline groups{ii} '-control, p=%.2d; '],prob);
        end
    end
    xlim([0 4]);
    ylim(yLims{pp});
    ylabel(yLabels{pp});
    fprintf([outline '\n']);
end

% Plot the median parameter value and 
