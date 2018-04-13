%% test for calibration tracking


%% setup the basic path params

% get data and analysis directory prefs
projectName = 'melSquintAnalysis';
MELA_dataBasePath =  getpref(projectName,'melaDataPath', MELA_dataBasePath);
MELA_analysisBasePath = getpref(projectName,'melaAnalysisPath');

basePathParams.dataSourceDirFull = fullfile(MELA_dataBasePath,'Experiments','OLApproach_Squint','SquintToPulse','DataFiles');
basePathParams.dataOutputDirFull = fullfile(MELA_analysisBasePath,'Experiments','OLApproach_Squint','SquintToPulse','DataFiles');


%% Parameters common to all subjects
intrinsicCameraMatrix =  [1347.76, 0, 658.90;...
                          0, 1345.48, 365.68;...
                          0, 0, 1];
sensorResolution = [1280 720];      
radialDistortionVector = [0.21524, -1.5616];
verbosity = 'full';
useParallel = true;


%% analyze each subject

% Subject parameters
subject = 'HERO_HMM';
session = '2018-03-29_session_1';
runName = 'calibration_001_ HERO_HMM';
observedIrisDiamPixels = 550;

% Estimate camera depth from iris diameter
sceneGeometry = createSceneGeometry(...
    'intrinsicCameraMatrix', intrinsicCameraMatrix, ...
    'radialDistortionVector',radialDistortionVector);
[cameraDepthMean, cameraDepthSD] = depthFromIrisDiameter( sceneGeometry, observedIrisDiamPixels );

% Set up scene parameter bounds
sceneParamsLB = [-15; 1; -5; cameraDepthMean-2*cameraDepthSD; .75; 0.9];
sceneParamsLBp = [-12; 1.5; -4; cameraDepthMean-1*cameraDepthSD; .85; 0.95];
sceneParamsUBp = [-8; 2; -3; cameraDepthMean+1*cameraDepthSD; 1.15; 1.05 ];
sceneParamsUB = [-5; 2.5; -2; cameraDepthMean+2*cameraDepthSD; 1.25; 1.10];

% Set up path params for this video
pathParams.dataSourceDirFull = fullfile(basePathParams.dataSourceDirFull, subject, 'pupilCalibration');
pathParams.dataOutputDirFull = fullfile(basePathParams.dataOutputDirFull, subject, 'pupilCalibration');
pathParams.runName = runName;

% Run the video pipeline for the calibration video
runVideoPipeline(pathParams,...
    'useParallel', useParallel,...
    'verbosity', verbosity, ...
    'sceneParamsLB',sceneParamsLB, 'sceneParamsUB',sceneParamsUB, ...
    'sceneParamsLBp',sceneParamsLBp,'sceneParamsUBp',sceneParamsUBp,...
    'intrinsicCameraMatrix', intrinsicCameraMatrix, ...
    'sensorResolution', sensorResolution, ...
    'radialDistortionVector',radialDistortionVector, ...
    'constraintTolerance',0.03, ...
    'eyeLaterality','left');


