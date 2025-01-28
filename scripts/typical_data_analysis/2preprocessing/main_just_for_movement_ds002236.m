%% This script will be used for the first time screening of the data (only give you movement info)
% This script was created by Professor Baxter Rogeres (VUIIS), but is
% heavily modified based on our lab pipeline by Jin Wang updated 1/5/2021
% (1) realignment to mean, reslice the mean. This realignement is by run. 
% (5) Art_global. It calls the realignmentfile (the rp_*.txt) to do the interpolation. This step identifies the bad volumes(by setting scan-to-scan movement
%    mv_thresh = 1.5mm and global signal intensity deviation Percent_thresh = 4 percent, any volumes movement to reference volume, which is the mean, >5mm) and repair
%    them with interpolation. This step uses art-repair art_global.m function (the subfunctions within it are art_repairvol, which does repairment, and art_climvmnt, which identifies volumes movment to reference.

%% Last modified: 11/20/2024 IC
% 11/20/2024 IC: Updated filepaths and reorganzied script to improve readability

%% Specify filepaths
clear; clc;

% Define project directory
proj_dir = '/gpfs51/dors2/gpc/JamesBooth/JBooth-Lab/BDL/Isaac/reading-PA-NVIQ';

% Define analysis directory
analysis_dir = fullfile(proj_dir, 'typical_data_analysis', '2preprocessing');  
addpath(genpath(analysis_dir)); 

% Define SPM directory
spm_path = '/gpfs51/dors2/gpc/JamesBooth/JBooth-Lab/BDL/LabCode/typical_data_analysis/spm12'; 
addpath(genpath(spm_path));

%% Define data folder and file parameters for preprocessing
% Create structure CCN
global CCN;

% Define folder with preprocessed data
% Define dataset
% Define time point
% Define Functional folder name pattern
% Define Functional data name pattern
% Define Anatomical data name pattern
CCN.preprocessed_folder = 'preproc'; 
CCN.dataset = 'ds002236-1.1.1';
%CCN.session = 'ses-T1';
CCN.func_folder = 'sub*';
CCN.func_pattern = 'sub*_task-VisRhyme*_run*_bold.ni*';
CCN.anat_pattern = '*_T1w*.nii';

%% Specify participants
% Manual entry (e.g.'sub-5004' 'sub-5009')
subjects= {};

%In this excel, there should be a column of subjects with the header (subjects). 
% The subjects should all be sub plus numbers (sub-5002).
data_info = fullfile(proj_dir, 'preproc', 'ds002236-1.1.1', 'subjects_ds002236.csv');

if isempty(subjects)
    M = readtable(data_info);
    subjects = M.subjects;
end

%% Run realignment and check for motion
% Initialize
spm('defaults','fmri');
spm_jobman('initcfg');
spm_figure('Create','Graphics','Graphics');

% Dependency and sanity checks
if verLessThan('matlab','R2013a')
    error('Matlab version is %s but R2013a or higher is required',version)
end

% SPM version
req_spm_ver = 'SPM12 (6225)';
spm_ver = spm('version');
if ~strcmp( spm_ver,req_spm_ver )
    error('SPM version is %s but %s is required',spm_ver,req_spm_ver)
end

%Start to preprocess data from here
disp('==Job start=='); 
tic; 
count = 1;
try
    for i = 1:length(subjects)
        
        fprintf('\n%i. Working on %s from %s ...\n', count, subjects{i}, CCN.dataset); 
        
        % Locate functional images
        CCN.subj_folder = [proj_dir '/' CCN.preprocessed_folder '/' CCN.dataset '/' subjects{i}];
        out_path = [CCN.subj_folder];
        CCN.func_f = '[subj_folder]/func/[func_folder]/';
        func_f = expand_path(CCN.func_f);
        func_file = [];
        
        for m = 1:length(func_f)
            func_file{m} = expand_path([func_f{m} '[func_pattern]']);
        end
        
        % Define parameters
        Percent_thresh= 4; %global signal intensity change
        mv_thresh = 1.5; % scan-to-scan movement
        MVMTTHRESHOLD = 100; % movement to reference, see in art_clipmvmt
        
        % Expand 4d functional data to 3d data
        for x = 1:length(func_file)
            
            % Run motion correction
            [rfunc_file, rp_file] = realignment_byrun_4d(char(func_file{x}), out_path); %this will run the realignment by run by run
            [func_p, func_n, func_e] = fileparts(rfunc_file);
            swfunc_file = rfunc_file;
            swfunc_vols = cellstr(spm_select('ExtFPList',func_p,['^' func_n func_e '$'],inf));
            
            % Third parameter is HeadMaskType 4 = automask
            % Fourth parameter is RepairType 1 = ArtifactRepair alone (0.5 movement and add margin)
            art_global_jin(char(swfunc_vols), rp_file, 4, 1, Percent_thresh, mv_thresh, MVMTTHRESHOLD);
            [p,n,ext] = fileparts(swfunc_file);
            
            delete([p '/v' n ext]);
            delete([p '/mean' n ext]);
            %delete([p '/rp_' n '.txt']); %keep rp file for FD calculation
            delete([p,'/' n,'.mat']);
            
        end
        count = count + 1;
    end
    
catch e
    rethrow(e)
    %display the errors
end

fprintf('\n==Job Done==\n');
toc;
%%