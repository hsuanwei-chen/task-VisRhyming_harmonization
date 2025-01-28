%% Count reparied and accuracy rt,
%Only for old_reading bids, if need for other bids, need to carefully revise this code for all parts of the events files. 
%This script calculate the movement, accuracy, and rt for each run. written
%by Jin Wang 1/3/2021, updated 1/5/2021
%The number of volumes being replaced (the second column) and how many chunks of more than 6 consecutive volumes being
%replaced (the third column) are based on the output of art-repair (in the code main_just_for_movement.m). 
%The acc and rt for each condition of a run are calculated based on the
%documented in ELP/bids/derivatives/func_mv_acc_rt/ELP_Acc_RT_final_2020_12_18.doc

global CCN;
root='/gpfs51/dors2/gpc/JamesBooth/JBooth-Lab/BDL/jinwang/test/raw'; %data folder
addpath(genpath('/gpfs51/dors2/gpc/JamesBooth/JBooth-Lab/BDL/LabCode/typical_data_analysis/2preprocessing')); %This is the code pathCCN.func_n='sub*Plaus*';
CCN.ses='ses';
n=6; %number of consecutive volumes being replaced. no more than 6 consecutive volumes being repaired.
CCN.func_n='sub*Rhyme*'; % I would recommend run one task at a time otherwise the condition numbers may differ and it will cause the codes to crush.
writefile='accuracy_Rhyme_behavior.txt';
subjects = {}; % if this is empty, it will read data_info.
data_info='/gpfs51/dors2/gpc/JamesBooth/JBooth-Lab/BDL/jinwang/test/subjects.xlsx'; %In this excel, there should be a column of subjects with the header (subjects). The subjects should all be sub plus numbers (sub-5002).
bids_folder='/dors/booth/JBooth-Lab/BDL/old_reading/bids';
if isempty(subjects)
    M=readtable(data_info);
    subjects=M.subjects;
end
hdr='subjects run_name num_repaired chunks cond1 acc1 rt1 cond2 acc2 rt2 cond3 acc3 rt3 cond4 acc4 rt4 cond5 acc5 rt5 cond6 acc6 rt6 cond7 acc7 rt7';
%you should edit this according to your number of conditions for that task.

%%%%%%%%%%%%%%maincode, once settled for one project, do not modify, this is for old_reading %%%%%%%%%%%%%%%%%%%%%%
cd(root);
if exist(writefile)
    delete(writefile);
end
fid=fopen(writefile,'w'); 
fprintf(fid, '%s', hdr);
fprintf(fid, '\n');
for i=1:length(subjects)
    func_p=[root '/' subjects{i}];
    func_f=expand_path([func_p '/[ses]/func/[func_n]/']);
    for j=1:length(func_f)
        run_n=func_f{j}(1:end-1);
        [run_p, run_name]=fileparts(run_n);
        %get the movement data from art_repair
        cd(run_n);
        fileid=fopen('art_repaired.txt');
        m=fscanf(fileid, '%f');
        [num_repaired, col]=size(m);
        N=n; %N=(n-1); it is no more than 6 consecutive volumes repaired described in the paper. This is wrong, corrected by Jin 6/21/2020
        x=diff(m')==1;
        ii=strfind([0 x 0], [0 1]);
        jj=strfind([0 x 0], [1 0]);
        %idx=max(jj-ii);
        %out=(idx>=N);
        out=((jj-ii)>=N);
        if out==0
            chunks=0;
        else
            %chunks=length(out); This is wrong. corrected on 5/1/2020 by
            %Jin Wang
            chunks=sum(out(:)==1);
        end
 
        
      %%%%%%%%%%%%%%%%%%%%%%should be careful about the variables and format in the events files, they differ from bids to bids %%%%%%%%%%%%%%%%%%%%%  
        %get accuracies and rt from events.tsv. akes sure these variables
        %match your bids events file. I used %%%edit to mark the places
        %needed to check
        run_name_e=run_name(1:end-4);
        datafile=[bids_folder '/' subjects{i} '/func/' run_name_e 'events.tsv'];
        data=tdfread(datafile);
        conditions=unique(data.trial_type,'row');
        acc_by_condition=[];
        rt_by_condition=[];
        rt_allvalue=[];
        rt_all_correcttrials=data.response_time(data.accuracy==1, :); %%%%edit
        for jj=1: size(rt_all_correcttrials,1)
            if ~contains(num2str(rt_all_correcttrials(jj,:)), 'n/a')
                if isa(rt_all_correcttrials(jj,:),'double')
                    rt_allvalue=[rt_allvalue; rt_all_correcttrials(jj,:)];
                else
                    rt_allvalue=[rt_allvalue; str2double(rt_all_correcttrials(jj,:))];
                end
            end
        end
        M=mean(rt_allvalue);
        SD3=3*std(rt_allvalue);
        min1=M-SD3;
        min2=0.25;
        mini=max([min1; min2]);
        maxi=M+SD3;
        for ii=1:size(conditions,1)
            thiscondition=conditions(ii,:);
            acc_thiscond=data.accuracy(data.trial_type==thiscondition); %%%edit
            rt_thiscond=data.response_time((data.trial_type==thiscondition),:); %%%edit            
            rt_thiscond_new_count=0;
            rt_thiscond_new_value=[];
            for mm=1: size(rt_thiscond,1)
                if ischar(rt_thiscond(mm,:)) && ~contains(rt_thiscond(mm,:),'n/a')
                    cur_rt=str2double(rt_thiscond(mm,:));
                    if acc_thiscond(mm)==1 && cur_rt>mini && cur_rt<maxi
                        rt_thiscond_new_count=rt_thiscond_new_count+1;
                        rt_thiscond_new_value=[rt_thiscond_new_value; cur_rt];
                    end
                elseif ~ischar(rt_thiscond(mm,:))
                    cur_rt=rt_thiscond(mm,:);
                    if acc_thiscond(mm)==1 && cur_rt>mini && cur_rt<maxi
                        rt_thiscond_new_count=rt_thiscond_new_count+1;
                        rt_thiscond_new_value=[rt_thiscond_new_value; cur_rt];
                    end
                end
                
            end
            average_rt=sum(rt_thiscond_new_value)/rt_thiscond_new_count;
            average_acc=sum(acc_thiscond)/size(acc_thiscond,1);
            acc_by_condition=[acc_by_condition; average_acc];
            rt_by_condition=[rt_by_condition; average_rt];
        end
        
%        old_reading does not have acquisition date in json files.  
%         get the shifted dates of acquisition date for each run
%         fname=[bids_folder '/' subjects{i} '/func/' run_name '.json'];
%         if exist(fname)
%             val=jsondecode(fileread(fname));
%             shifted_data_acq=val.ShiftedAquisitionDate;
%         else
%             shifted_data_acq='NaN';
%         end
%         


 %%%%%%%%save all the values to txt (you should know the number of conditions you have and modify this part accordingly)%%%%%%%%%%%%%%%%%%%%%%%
        fprintf(fid,'%s %s %d %d %d %.4f %.6f %d %.4f %.6f %d %.4f %.6f %d %.4f %.6f %d %.4f %.6f %d %.4f %.6f %d %.4f %.6f\n', ...
            subjects{i}, run_name, num_repaired, chunks, conditions(1), acc_by_condition(1,:), rt_by_condition(1,:), ...
            conditions(2), acc_by_condition(2,:), rt_by_condition(2,:), conditions(3), acc_by_condition(3,:), rt_by_condition(3,:),...
            conditions(4), acc_by_condition(4,:), rt_by_condition(4,:), conditions(5), acc_by_condition(5,:), rt_by_condition(5,:), ...
            conditions(6), acc_by_condition(6,:), rt_by_condition(6,:), conditions(7), acc_by_condition(7,:), rt_by_condition(7,:));
    end
end

