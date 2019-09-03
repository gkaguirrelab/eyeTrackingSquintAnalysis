function transcriptionWrapper(subjectNumber)

load(fullfile(getpref('melSquintAnalysis', 'melaProcessingPath'), 'Experiments/OLApproach_Squint/SquintToPulse/DataFiles/', 'subjectListStruct.mat'));

subjectIDs = fieldnames(subjectListStruct);

transcribeAudioResponses(subjectIDs{subjectNumber}, 'sessions', subjectListStruct.(subjectIDs{subjectNumber}));

end