%% First level analysis
% written by Jin Wang updated 1/5/2021
% You should define your conditions, onsets, duration, TR.
% The repaired images will be deweighted from 1 to 0.01 in the first level
% estimation (we changed the art_redo.m, which uses art_deweight.txt as default to deweight the scans to art_redo_jin.txt, which we uses the art_repaired.txt to deweight scans).
% The difference between art_deiweghted.txt and art_repaired.txt is to the
% former one is more wide spread. It not only mark the scans which was repaired to be deweighted, but also scans around it to be deweighted.
% The 6 movement parameters we got from realignment is added into the model regressors to remove the small motion effects on data.

% Make sure you run clear all before running this code. This is to clear
% all existing data structure which might be left by previous analysis in
% the work space.

addpath(genpath('/gpfs51/dors2/gpc/JamesBooth/JBooth-Lab/BDL/LabCode/typical_data_analysis/3firstlevel')); % the path of your scripts
spm_path='/gpfs51/dors2/gpc/JamesBooth/JBooth-Lab/BDL/LabCode/typical_data_analysis/spm12'; %the path of spm
addpath(genpath(spm_path));

%define your data path
data=struct();
root='/gpfs51/dors2/gpc/JamesBooth/JBooth-Lab/BDL/jinwang/test';  %your project path
subjects={};
data_info='/gpfs51/dors2/gpc/JamesBooth/JBooth-Lab/BDL/jinwang/test/subjects.xlsx'; 
if isempty(subjects)
    M=readtable(data_info);
    subjects=M.subjects;
end
bids_folder='/gpfs51/dors2/gpc/JamesBooth/JBooth-Lab/BDL/old_reading/bids';
events_file_exist=0; %0 events file not copied to your folder, 1 events file not copied to your folder
analysis_folder='analysis'; % the name of your first level modeling folder
model_deweight='deweight'; % the deweigthed modeling folder, it will be inside of your analysis folder

global CCN
CCN.preprocessed='raw'; % your data folder
CCN.session='ses'; % the time points you want to analyze
CCN.func_pattern='sub*AudRhyme*'; % the name of your functional folders
CCN.file='sub*task*bold.nii'; % the name of your preprocessed data (4d)
CCN.rpfile='rp_*.txt'; %the movement files


%%define your task conditions, be sure it follows the sequence from 0-6.
%in old_reading project, audrhyme task conditions: 0-fixation, 1-o+p+, 2-o-p+, 3-o+p-, 4-o-p-, 5-simp_ctrl, 6-complex_ctrl
conditions{1}={'fixation' 'o+p+' 'o-p+' 'o+p+' 'o-p-' 'simp_ctrl' 'complex_ctrl'};
conditions{2}={'fixation' 'o+p+' 'o-p+' 'o+p+' 'o-p-' 'simp_ctrl' 'complex_ctrl'};

%duration
dur=0; %I think all projects in BDL are event-related, so I hard coded the duration as 0.

%TR
TR=2; %old reading project

%define your contrasts, make sure your contrasts and your weights should be
%matched.
contrasts={'lexical_vs_simpctrl' ...
    'lexical_vs_complexctrl'};
lexical_vs_simpctrl=[0 1 1 1 1 0 -4];
lexical_vs_complexctrl=[0 1 1 1 1 -4 0];

%adjust the contrast by adding six 0s into the end of each session
rp_w=zeros(1,6);
weights={[lexical_vs_simpctrl rp_w lexical_vs_simpctrl rp_w]...
    [lexical_vs_complexctrl rp_w lexical_vs_complexctrl rp_w]};

%%%%%%%%%%%%%%%%%%%%%%%%Do not edit below here%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%check if you define your contrasts in a correct way
if length(weights)~=length(contrasts)
    error('the contrasts and the weights are not matched');
end

% Initialize
%addpath(spm_path);
spm('defaults','fmri');
spm_jobman('initcfg');
spm_figure('Create','Graphics','Graphics');

% Dependency and sanity checks
if verLessThan('matlab','R2013a')
    error('Matlab version is %s but R2013a or higher is required',version)
end

req_spm_ver = 'SPM12 (6225)';
spm_ver = spm('version');
if ~strcmp( spm_ver,req_spm_ver )
    error('SPM version is %s but %s is required',spm_ver,req_spm_ver)
end

%Start to analyze the data from here
try
    for i=1:length(subjects)
        fprintf('work on subject %s', subjects{i});
        CCN.subject=[root '/' CCN.preprocessed '/' subjects{i}];
        %specify the outpath,create one if it does not exist
        out_path=[CCN.subject '/' analysis_folder];
        if ~exist(out_path)
            mkdir(out_path)
        end
         
        %specify the deweighting spm folder, create one if it does not exist
        model_deweight_path=[out_path '/' model_deweight];
        if exist(model_deweight_path,'dir')~=7
            mkdir(model_deweight_path)
        end
        
        %find folders in func
        CCN.functional_dirs='[subject]/[session]/func/[func_pattern]/';
        functional_dirs=expand_path(CCN.functional_dirs);
        
        %re-arrange functional_dirs so that run-01 is always before run-02
        %if they are the same task. This part will only correct ELP bids
        %which likely mess up. Other bids should be fine. 
        func_dirs_rr=functional_dirs;
%         for rr=1:length(functional_dirs)
%             if rr<length(functional_dirs)
%             [~, taskrunname1]=fileparts(fileparts(functional_dirs{rr}));
%             taskname1=taskrunname1(21:25);
%             taskrun1=str2double(taskrunname1(end-5:end-5));
%             [~, taskrunname2]=fileparts(fileparts(functional_dirs{rr+1}));
%             taskname2=taskrunname2(21:25);
%             taskrun2=str2double(taskrunname2(end-5:end-5));
%             if strcmp(taskname1,taskname2) && taskrun1>taskrun2
%                 func_dirs_rr{rr}=functional_dirs{rr+1};
%                 func_dirs_rr{rr+1}=functional_dirs{rr};
%             end
%             end
%         end
                
        %load the functional data, 6 mv parameters, and event onsets
        mv=[];
        swfunc=[];
        P=[];
        onsets=[];
        for j=1:length(func_dirs_rr)
             swfunc{j}=expand_path([func_dirs_rr{j} '[file]']);
            %load the event onsets
            if events_file_exist==1
                [p,run_n]=fileparts(func_dirs_rr{j}(1:end-1));
                event_file=[func_dirs_rr{j} run_n(1:end-4) 'events.tsv'];
            elseif events_file_exist==0
                [p,run_n]=fileparts(func_dirs_rr{j}(1:end-1));
                [q,session]=fileparts(fileparts(p));
                [~,this_subject]=fileparts(q);
                event_file=[bids_folder '/' this_subject '/func/' run_n(1:end-4) 'events.tsv']; %%here is different from firstlevel code of ELP project
                rp_file=[p '/' run_n '/rp_a' run_n '.txt'];%%here is different from firstlevel code of ELP project
            end
            event_data=tdfread(event_file);
            cond=unique(event_data.trial_type,'row');
            for k=1:size(cond,1)
            onsets{j}{k}=event_data.onset(event_data.trial_type==cond(k)); %here is different from firstlevel code of ELP project
            end
            mv{j}=load(rp_file); 
        end
        data.swfunc=swfunc;
        
        
        %pass the experimental design information to data
        data.conditions=conditions;
        data.onsets=onsets;
        data.dur=dur;
        data.mv=mv;
        
        %run the firstlevel modeling and estimation (with deweighting)
        mat=firstlevel_4d(data, out_path, TR, model_deweight_path);
        origmat=[out_path '/SPM.mat'];
        %run the contrasts
        contrast_f(origmat,contrasts,weights);
        contrast_f(mat,contrasts,weights);
        
    end
    
catch e
    rethrow(e)
    %display the errors
end