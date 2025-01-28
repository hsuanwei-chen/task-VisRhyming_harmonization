%% count_repaired
% This script calculate the movement, accuracy, and rt for each run. written by Jin Wang 1/3/2021, updated 1/5/2021
% The number of volumes being replaced (the second column) and how many chunks of more than 6 consecutive volumes being
% replaced (the third column) are based on the output of art-repair (in the code main_just_for_movement.m). 
% The acc and rt for each condition of a run are calculated based on the
% documented in ELP/bids/derivatives/func_mv_acc_rt/ELP_Acc_RT_final_2020_12_18.doc

%% Last modified: 01/14/2025 IC
% 01/14/2025 IC: Updated filepaths and reorganzied script to improve readability

%% Specify filepaths
clear; clear

% Define project directory and then add path to processing folder
proj_dir = '/gpfs51/dors2/gpc/JamesBooth/JBooth-Lab/BDL/Isaac/reading-PA-NVIQ';
analysis_dir = fullfile(proj_dir, 'typical_data_analysis', '2preprocessing');  
addpath(genpath(analysis_dir));

% Define bids folder and preprocssing folder
dataset = 'ds001894-1.4.2';
preproc_dir = fullfile(proj_dir, 'preproc', dataset);

%% Define data folder and file parameters for preprocessing
% Create structure CCN
global CCN;

% Define time point
% Define functional data name pattern
CCN.session = 'ses-T1';
CCN.func_pattern = 'sub*_*_task-VVWord*_run*_bold';

%% Specify participants
% Manual entry (e.g.'sub-5004' 'sub-5009')
subjects= {};

% In this excel, there should be a column of subjects with the header (subjects). 
% The subjects should all be sub plus numbers (sub-5002).
data_info = fullfile(proj_dir, 'preproc', 'ds001894-1.4.2', 'subjects_ds001894.csv');

if isempty(subjects)
    M = readtable(data_info);
   subjects = M.subjects;
end

%% Count number of repaired chunks
cd(preproc_dir);
n = 6; %number of consecutive volumes being replaced. no more than 6 consecutive volumes being repaired.

% Initialize variables to save summary values
motion_header = {
    'subject_id', 'run_name', 'repaired_num', 'repaired_perc', ...
    'chunks_num', 'FD_mean', 'FD_num_03', 'FD_perc_03'
};
group_motion_tbl = array2table(zeros(0, length(motion_header)));
group_motion_tbl.Properties.VariableNames = motion_header;

for i = 1:length(subjects)
    
    % Define subject folder and their fMRI task folder
    func_p = [preproc_dir '/' subjects{i}];
    func_f = expand_path([func_p '/[session]/func/[func_pattern]/']);
    
    for j = 1:length(func_f)
                
        % Find all the runs
        run_n = func_f{j}(1:end-1);
        [run_p, run_name] = fileparts(run_n);
        cd(run_n);
        
        %Print what subject session is currently being analyzed
        fprintf('%i. Working on %s ... \n', i, run_name)
        
        % Read in movement data from art_repair
        fileid = fopen('art_repaired.txt');
        m = fscanf(fileid, '%f');
        
        % Size returns number of rows (num_repaired), number of columns (col)
        [repaired_num, col] = size(m);
        
        % Transpose m; test if the difference between each number is equal to 1 
        x = diff(m') == 1;
        
        % Returns each position when difference is equal to 1 after the
        % difference was not equal to 1 (start)
        ii = strfind([0 x 0], [0 1]);
        % Returns each position when difference is equal to 1 before the
        % difference is not equal to 1 (end)
        jj = strfind([0 x 0], [1 0]);
        % Check if a sequence has more than 6 consecutive volumes repaired
        out = ((jj-ii) >= n);
        
        % Determine number of chuncks
        if out == 0
            num_chunks = 0;
        else
            num_chunks = sum(out(:) == 1);
        end
       
        % Locate the motion parameter file
        rp_file = dir('rp*');
        
        % Calculate framewise displacement
        FD = fmri_FD(fullfile(rp_file.folder, rp_file.name));
        FD_mean = mean(FD);
        FD_num_03 = sum(FD >= 0.3); % see Smith et al. 2022
        FD_perc_03 = FD_num_03/length(FD);
        
        % Calcualte percent of repaired volumes
        repaired_perc = repaired_num/length(FD);
        
        % Aggregate motion summary for individual
        motion_sum = {
            subjects{i}, run_name, repaired_num, repaired_perc, ... 
            num_chunks, FD_mean, FD_num_03, FD_perc_03
        };
        motion_tbl = cell2table(motion_sum);
        motion_tbl.Properties.VariableNames = motion_header;
        group_motion_tbl = [group_motion_tbl; motion_sum];
        
        fprintf('Done! \n');   
        
        clear func_p run_n run_p run_name m repaired_num x ii jj ...
            out repair_perc num_chuncks FD FD_mean FD_num_03 FD_perc_03
        
    end
end

%Write output into excel
dest_fname = strcat(preproc_dir, '/count_repaired_ds001894.csv');
writetable(group_motion_tbl, dest_fname)
