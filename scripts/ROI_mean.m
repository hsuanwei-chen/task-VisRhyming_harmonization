% Clean workspace and variables
clear; clc

% Script for deriving mean in ROI
proj_dir = '/Users/isaac938/Library/CloudStorage/Box-Box/BDL/Member_Folders/Isaac/2_project/task-VisRhyme_harmonization/';
proc_dir = fullfile(proj_dir, 'preproc'); 
left_fusiform = fullfile(proj_dir, 'mask', 'left_fusiform.nii');
left_STG = fullfile(proj_dir, 'mask', 'left_IFG.nii');
left_IFG = fullfile(proj_dir, 'mask', 'left_STG.nii');

% Excel output file
outputFile = fullfile(proc_dir, 'reading_ROR_mean.xlsx');
header = {'dataset', 'subject', 'left_fusiform_mean', 'left_STG_mean', 'left_IFG_mean', 'X', 'Y', 'Z'};

% Initialize data storage
outputData = {};

% List all dataset folders in the base directory
datasets = dir(fullfile(proc_dir, 'ds00*')); % Replace 'dataset*' if your folder naming is different
datasets = datasets([datasets.isdir]); % Keep only directories

% Loop through each dataset folder
for i = 1:length(datasets)
    datasetPath = fullfile(proc_dir, datasets(i).name);
    
    % List all 'sub-*' folders within the dataset folder
    subFolders = dir(fullfile(datasetPath, 'sub-*'));
    subFolders = subFolders([subFolders.isdir]); % Keep only directories
    
    for j = 1:length(subFolders)
        subPath = fullfile(datasetPath, subFolders(j).name);
        
        % Path to the "analysis" folder
        analysisPath = fullfile(subPath, 'analysis');
        
        % Find the fMRI data file in the "analysis" folder
        contastFile = dir(fullfile(analysisPath, '*.nii')); % Adjust '*.nii' if a different format is used
        
        if ~isempty(contastFile)
            % Full path to the fMRI data file
            fMRIFilePath = fullfile(analysisPath, contastFile.name);
            
            % Read the fMRI data using SPM
            fprintf('Reading fMRI data from: %s\n', fMRIFilePath);
            hdr = spm_vol(fMRIFilePath); % Load header information
            img = spm_read_vols(hdr);    % Load the actual image data
            
            % Compute mean contrast in each ROI
            left_fusiform_mean = Extract_ROI_Data(left_fusiform, fMRIFilePath);
            left_STG_mean = Extract_ROI_Data(left_STG, fMRIFilePath);
            left_IFG_mean = Extract_ROI_Data(left_IFG, fMRIFilePath);

            % Define subject-levle output
            outputData = [outputData; {datasets(i).name, subFolders(j).name, left_fusiform_mean, left_STG_mean, left_IFG_mean, size(img,1), size(img,2), size(img,3)}];

            % Perform operations with the loaded fMRI data
            % (For now, simply display the size of the image)
            fprintf('Data size: %s\n', mat2str(size(img)));
        else
            fprintf('No fMRI file found in: %s\n', analysisPath);
        end
    end
end

% Write data to Excel file
if ~isempty(outputData)
    % Convert to table and write to Excel
    outputTable = cell2table(outputData, 'VariableNames', header);
    writetable(outputTable, outputFile);
    fprintf('Data written to: %s\n', outputFile);
else
    fprintf('No data found to write to Excel.\n');
end

disp('Processing completed.');

function ROI_data = Extract_ROI_Data(ROI, Contrast)

    Y = spm_read_vols(spm_vol(ROI),1);
    indx = find(Y>0);
    [x,y,z] = ind2sub(size(Y), indx);

    XYZ = [x y z]';

    ROI_data = nanmean(spm_get_data(Contrast, XYZ),2);

end

