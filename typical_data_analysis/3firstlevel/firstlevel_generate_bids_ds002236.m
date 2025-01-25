%% First level analysis, written by Jin Wang 3/15/2019
% You should define your conditions, onsets, duration, TR.
% The repaired images will be deweighted from 1 to 0.01 in the first level
% estimation (we changed the art_redo.m, which uses art_deweight.txt as default to deweight the scans to art_redo_jin.txt, which we uses the art_repaired.txt to deweight scans).
% The difference between art_deiweghted.txt and art_repaired.txt is to the
% former one is more wide spread. It not only mark the scans which was repaired to be deweighted, but also scans around it to be deweighted.
% The 6 movement parameters we got from realignment is added into the model regressors to remove the small motion effects on data.

% Make sure you run clear all before running this code. This is to clear all existing data structure which might be left by previous analysis in the work space.

% This code is for ELP project specifically to deal with its repeated runs and run-<> is after acq- that would cause run-01 is after run-02 when specifying the model.

%% Last modified: 2025/01/23 IC
% 2025/01/23 IC: Updated filepaths and reorganzied script to improve readability

%% Specify filepaths
clear; clc;

% Define project directory
proj_dir = '/gpfs51/dors2/gpc/JamesBooth/JBooth-Lab/BDL/Isaac/task-VisRhyme_harmonization';

% Define analysis directory
analysis_dir = fullfile(proj_dir, 'typical_data_analysis', '3firstlevel');  
addpath(genpath(analysis_dir)); 

% Define SPM directory
spm_path = '/dors/booth/JBooth-Lab/BDL/LabCode/typical_data_analysis/spm12'; 
addpath(genpath(spm_path));

% Define first-level modeling folder
analysis_folder = 'analysis';

% Define deweighted modleing folder
model_deweight = 'deweight';

% Define data path
data = struct();

% 1 means you did copy the events.tsv into your preprocessed folder
% 0 means you cleaned the events.tsv in your preprocessed folder
events_file_exist=0;

% Define BIDS folder
% If you assign 0 to events_file_exist, then you mask fill in this path, so it can read events.tsv file for individual onsets from bids folder
bids_folder = '/gpfs51/dors2/gpc/JamesBooth/JBooth-Lab/BDL/Isaac/reading-PA-NVIQ/bids';

%% Define data folder and file parameters for preprocessing
% Create structure CCN
global CCN

% Define folder with preprocessed data
% Define dataset
% Define time point
% Define functional folder name pattern
% Define preprocessed data suffix
% Define movement file after slice time correction
CCN.preprocessed = 'preproc';
CCN.dataset = 'ds002236-1.1.1';
%CCN.session = 'ses-T1';
CCN.func_pattern = 'sub*';
CCN.file = 'vs6_wasub*bold.nii';
CCN.rpfile = 'rp_asub*.txt';

%% Specify participants
% Manual entry (e.g.'sub-5004' 'sub-5009')
subjects= {};

% In this excel, there should be a column of subjects with the header (subjects). 
% The subjects should all be sub plus numbers (sub-5002).
data_info = fullfile(proj_dir, 'preproc', 'ds002236-1.1.1', 'subjects_ds002236.csv');

if isempty(subjects)
    M = readtable(data_info);
    subjects = M.subjects;
end
 
%% Specify Task Conditions
% Define your task conditions, each run is a cell
conditions = []; %start with an empty conditions.
conditions{1} = {'0', '1', '2', '3', '4', '5', '6'};
conditions{2} = {'0', '1', '2', '3', '4', '5', '6'};

% Duration = 0, if design is event-related
dur = 0;

% TR
TR = 2;

% Define your contrasts, make sure your contrasts and your weights should be matched.
% Rows - 'null ''O+P+' 'O-P+' 'O+P-' 'O-P-' 'Single Symbols' 'Triple Symbols' 'X' 'Y' 'Z 'Pitch' 'Roll' 'Yaw'
contrasts = {'Lexical_vs_Fixation'};
lexical_fix = [-1 1 1 1 1 0 0 0 0 0 0 0 0];
weights = {lexical_fix};

%%%%%%%%%%%%%%%%%%%%%%%%Do not edit below here%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Check if you define your contrasts in a correct way
if length(weights)~=length(contrasts)
    error('the contrasts and the weights are not matched');
end

% Initialize
spm('defaults','fmri');
spm_jobman('initcfg');
spm_figure('Create','Graphics','Graphics');

% Dependency and sanity checks
% Check MATLAB version
if verLessThan('matlab','R2013a')
    error('Matlab version is %s but R2013a or higher is required',version)
end

% Check SPM12 version
req_spm_ver = 'SPM12 (6225)';
spm_ver = spm('version');
if ~strcmp( spm_ver,req_spm_ver )
    error('SPM version is %s but %s is required',spm_ver,req_spm_ver)
end

%Start to preprocess data from here
disp('==Job start=='); 
tic; 
count = 1;

%Start to analyze the data from here
try
    for i=1:length(subjects)

        fprintf('\n%i. Working on %s from %s ...\n', count, subjects{i}, CCN.dataset); 

        CCN.subject=[proj_dir '/' CCN.preprocessed '/' CCN.dataset '/' subjects{i}];
        
        % Specify the outpath,create one if it does not exist
        out_path=[CCN.subject '/' analysis_folder];
        if ~exist(out_path)
            mkdir(out_path)
        end
         
        % Specify the deweighting spm folder, create one if it does not exist
        model_deweight_path=[out_path '/' model_deweight];
        if exist(model_deweight_path,'dir')~=7
            mkdir(model_deweight_path)
        end
        
        % Find folders in func
        CCN.functional_dirs='[subject]/func/[func_pattern]/';
        functional_dirs=expand_path(CCN.functional_dirs);

        %re-arrange functional_dirs so that run-01 is always before run-02
        %if they are the same task. This is only for ELP project. modified
        %1/7/2021
        func_dirs_rr=functional_dirs;
        for rr=1:length(functional_dirs)
            if rr<length(functional_dirs)
            [~, taskrunname1]=fileparts(fileparts(functional_dirs{rr}));
            sessionname1=taskrunname1(10:15);
            taskname1=taskrunname1(21:25);
            taskrun1=str2double(taskrunname1(end-5:end-5));
            [~, taskrunname2]=fileparts(fileparts(functional_dirs{rr+1}));
            sessionname2=taskrunname2(10:15);
            taskname2=taskrunname2(21:25);
            taskrun2=str2double(taskrunname2(end-5:end-5));
            if strcmp(sessionname1,sessionname2) && strcmp(taskname1,taskname2) && taskrun1>taskrun2
                func_dirs_rr{rr}=functional_dirs{rr+1};
                func_dirs_rr{rr+1}=functional_dirs{rr};
            end
            end
        end
        
        % Load the functional data, 6 mv parameters, and event onsets
        mv=[];
        swfunc=[];
        P=[];
        onsets=[];
        
        for j=1:length(func_dirs_rr)
             swfunc{j}=expand_path([func_dirs_rr{j} '[file]']);
            
            % Load the event onsets
            if events_file_exist==1
                [p,run_n]=fileparts(func_dirs_rr{j}(1:end-1));
                event_file=[func_dirs_rr{j} run_n(1:end-4) 'events.tsv'];
            
            elseif events_file_exist==0
                [p,run_n]=fileparts(func_dirs_rr{j}(1:end-1));
                [q,session]=fileparts(fileparts(p));
                [~, this_subject]=fileparts(q);
                event_file=[bids_folder '/' CCN.dataset '/' session '/func/' run_n(1:end-4) 'events.tsv'];
                
                % Load the movement file with an -a suffix (after slice time correction)
                rp_file=[p '/' run_n '/rp_a' run_n '.txt'];
            
            end
            
            event_data=tdfread(event_file);
            cond=unique(event_data.trial_type, 'row');
            
            [~,len]=size(cond);

            for k=1:size(cond,1)  
                onsets{j}{k}=event_data.onset(event_data.trial_type==cond(k,:)==len);
            end
            
            mv{j}=load(rp_file);
            
        end
                
        % Pass the experimental design information to data
        data.swfunc=swfunc;
        data.conditions=conditions;
        data.onsets=onsets;
        data.dur=dur;
        data.mv=mv;
        
        % Run the firstlevel modeling and estimation (with deweighting)
        mat=firstlevel_4d(data, out_path, TR, model_deweight_path);
        origmat = [out_path '/SPM.mat'];
        
        % Run the contrasts
        contrast_f(origmat,contrasts,weights);
        contrast_f(mat,contrasts,weights);
        
    end
    
catch e
    rethrow(e)
    %display the errors
end

fprintf('\n==Job Done==\n');
toc;