discomfortStruct = loadDiscomfortRatings();

groups = {'controlDiscomfort','mwaDiscomfort','mwoaDiscomfort'};
colors = {'k','b','r'};
figure

options = optimset('fmincon');
options.Display = 'off';

p =[];
iqrs=[];

for ii = 1:length(groups)
    
    dVeridcal = [];
    Mc = [];
    Lc = [];
    
    % Assemble the melanopsin and cone contrasts for each discomfort rating.
    % We treat light flux stimuli as having equal contrast on the mel and LMS
    % photoreceptor pools.
    Mc = [ ...
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
    
    Mc = reshape(Mc,1,180);
    
    Lc = [ ...
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
    
    Lc = reshape(Lc,1,180);
    
    % Assemble the discomfort ratings
    dVeridical = [ ...
        discomfortStruct.(groups{ii}).Melanopsin.Contrast100; ...
        discomfortStruct.(groups{ii}).Melanopsin.Contrast200; ...
        discomfortStruct.(groups{ii}).Melanopsin.Contrast400; ...
        discomfortStruct.(groups{ii}).LMS.Contrast100; ...
        discomfortStruct.(groups{ii}).LMS.Contrast200; ...
        discomfortStruct.(groups{ii}).LMS.Contrast400; ...
        discomfortStruct.(groups{ii}).LightFlux.Contrast100; ...
        discomfortStruct.(groups{ii}).LightFlux.Contrast200; ...
        discomfortStruct.(groups{ii}).LightFlux.Contrast400; ...
        ];
    
    %% Bootstrap
    pB = [];
    for bb = 1:1000
        
        % Resample across columns (subjects) with replacement
        d = dVeridical(:,datasample(1:20,20));
        
        % Reshape d to a vector
        d = reshape(d,1,180);
        
        % Anonymous functions for the model
        myModel = @(k) ((k(1).*Mc).^k(2) + Lc.^k(2)).^(1/k(2));
        myLogLinFit = @(k,m) m(1).*log10(myModel(k))+m(2);
        myObj = @(p) sqrt(sum( (d - myLogLinFit(p(1:2),p(3:4))).^2 ));
        
        % Fit that sucker
        pB(bb,:) = fmincon(myObj,[1 1 1 1],[],[],[],[],[0.1 1 0 -10],[2 Inf Inf 10],[],options);
    end
    
    % Obtain the mean and 95% CI on the p values
    p(ii,:) = median(pB);
    iqrs(ii,:)=iqr(pB);
    
    subplot(1,3,ii)
    plot(log10(myModel(p(ii,1:2))),d,['*' colors{ii}])
    hold on
    refline(p(ii,3),p(ii,4))
    ylim([0 10]);
    
end
