%%
%this code is for clean up your firstlevel expanded 3d vs6_wtask*.nii
% files if you used my firstlevel analysis code before July 3rd, 2019

global CCN

subjects={'5003'};
root='/dors/gpc/JamesBooth/JBooth-Lab/BDL/jinwang/ReadingSkill_JW_7-8/preprocessed/';
CCN.session='ses-T1';
CCN.func_pattern='T1*';
CCN.files='vs6_wtask*bold_0*';
addpath(genpath('/dors/gpc/JamesBooth/JBooth-Lab/BDL/jinwang/ReadingSkill_JW_7-8/typical_data_analysis'));

for i=1:length(subjects)
    CCN.functional_f=[root subjects{i} '/[session]/func/[func_pattern]/[files]'];
    functional_files=expand_path(CCN.functional_f);
    for d=1:length(functional_files)
        delete(functional_files{d});
    end
end
