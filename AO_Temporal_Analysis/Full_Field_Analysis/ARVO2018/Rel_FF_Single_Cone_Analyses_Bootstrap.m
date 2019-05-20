% function [fitCharacteristics]=Rel_FF_Single_Cone_Analyses(stimRootDir, controlRootDir)
% [fitCharacteristics]=Rel_FF_Single_Cone_Analyses(stimRootDir, controlRootDir)
%
%   Calculates pooled variance across a set of pre-analyzed 
%   signals from a single cone's stimulus and control trials, performs 
%   the subtraction between its standard deviations, and performs a
%   piecewise fit of the subtraction.
%
%   This script is designed to work with FULL FIELD datasets- that is, each
%   dataset (mat file) contains *only* control or stimulus data.
%
%   Normally, the user doesn't need to select a stimulus or control root
%   directory (that will be found automatically by
%   "FF_Aggregate_Multi_Trial_Run.m"), but if the software is run by
%   itself it will prompt the user for the folders containing the
%   pre-analyzed mat files generated by Rel_FF_Temporal_Reflectivity_Analysis.m.
%
% Inputs:
%       stimRootDir: The folder path of the pre-analyzed (.mat) stimulus
%       trials. Each mat file must contain valid stimulus signals.
%
%       controlRootDir: The folder path of the pre-analyzed (.mat) control
%       trials. Each mat file must contain valid control signals.
%
%
% Outputs:
%       fitCharacteristics: Information extracted from the mat files and
%       the fitted subtracted signal.
%
% Created by Robert F Cooper 2017-10-31
%


clear;
close all;




CUTOFF = 26;
RERUNS = 200;
NUM_COMPONENTS=3;
CRITICAL_REGION = 66:100;

if ~exist('stimRootDir','var')
    close all force;
    stimRootDir = uigetdir(pwd, 'Select the directory containing the stimulus profiles');

end

profileSDataNames = read_folder_contents(stimRootDir,'mat');


% For structure:
% /stuff/id/date/wavelength/time/intensity/location/data/Profile_Data

[remain kid] = getparent(stimRootDir); % data
[remain stim_loc] = getparent(remain); % location 
[remain stim_intensity] = getparent(remain); % intensity 
[remain stim_time] = getparent(remain); % time
[remain stimwave] = getparent(remain); % wavelength
% [remain sessiondate] = getparent(remain); % date
[~, id] = getparent(remain); % id


%% Code for determining variance across all signals at given timepoint

THEwaitbar = waitbar(0,'Loading stimulus profiles...');

max_index=0;

load(fullfile(stimRootDir, profileSDataNames{1}));
stim_coords = ref_coords;

stim_cell_reflectance = cell(length(profileSDataNames),1);
stim_time_indexes = cell(length(profileSDataNames),1);
stim_cell_prestim_mean = cell(length(profileSDataNames),1);

for j=1:length(profileSDataNames)

    waitbar(j/length(profileSDataNames),THEwaitbar,'Loading stimulus profiles...');
    
    ref_coords=[];
    profileSDataNames{j}
    load(fullfile(stimRootDir,profileSDataNames{j}));
    
    stim_cell_reflectance{j} = norm_cell_reflectance;
    stim_time_indexes{j} = cell_times;
    stim_cell_prestim_mean{j} = cell_prestim_mean;
    
    thesecoords = union(stim_coords, ref_coords,'rows');
    
    % These all must be the same length! (Same coordinate set)
    if size(ref_coords,1) ~= size(thesecoords,1)
        error('Coordinate lists different between mat files in this directory. Unable to perform analysis.')
    end
    
    for k=1:length(cell_times)
        max_index = max([max_index max(cell_times{k})]);
    end
    
end

allcoords = stim_coords;


%% Aggregation of all trials

rng('shuffle');

percentparula = parula(101);

stim_cell_var = single(nan(size(stim_coords,1), max_index, RERUNS));
stim_cell_median = single(nan(size(stim_coords,1), max_index, RERUNS));
stim_trial_count = (zeros(size(stim_coords,1),RERUNS,'uint8'));

% stim_prestim_means=[];

parfor i=1:size(stim_coords,1)
%     waitbar(i/size(stim_coords,1),THEwaitbar,'Processing stimulus signals...');
%     tic;
    for k=1:RERUNS
        
        numtrials = 0;
        all_times_ref = nan(length(profileSDataNames), max_index);
        fileIndices = randi(length(profileSDataNames),1,length(profileSDataNames));

        for j=1:length(profileSDataNames)

            if ~isempty(stim_cell_reflectance{fileIndices(j)}{i}) && ...% ~all(isnan(stim_cell_reflectance{fileIndices(j)}{i}))...
                sum(stim_time_indexes{fileIndices(j)}{i} >= 67 & stim_time_indexes{fileIndices(j)}{i} <=99) >= CUTOFF

%                 if all(isnan(stim_cell_reflectance{fileIndices(j)}{i}))
%                    disp('Wut'); 
%                 end

                numtrials = numtrials+1;
                all_times_ref(j, stim_time_indexes{fileIndices(j)}{i} ) = stim_cell_reflectance{fileIndices(j)}{i};
            end
        end 
        stim_trial_count(i,k) = numtrials;


        for t=1:max_index
            nonan_ref = all_times_ref(~isnan(all_times_ref(:,t)), t);
            refcount = sum(~isnan(all_times_ref(:,t)));            
            refmedian = median(nonan_ref);
            if ~isnan(refmedian)
                stim_cell_median(i,t,k) = refmedian;
                stim_cell_var(i,t,k) = ( sum((nonan_ref-mean(nonan_ref)).^2)./ (refcount-1) );
            end
        end
    
    end
%     toc;
end

close all force;
% save bootstraphalfway.mat

%% Calculate the analyses
std_dev_sub = nan(size(allcoords,1), max_index, RERUNS);
median_sub = nan(size(allcoords,1), max_index, RERUNS);

StddevResp = nan(size(allcoords,1), RERUNS);
MedianResp = nan(size(allcoords,1), RERUNS);

% Subtract off the average response from each cone
load('control_avgs.mat')
load('450nW.mat','std_dev_coeff','median_coeff','std_dev_explained','median_explained');

std_dev_explained=std_dev_explained(1:NUM_COMPONENTS);
median_explained=median_explained(1:NUM_COMPONENTS);

k=1;
for i=1:size(allcoords,1)
i
    
    for k=1:RERUNS
                
        if ~all( isnan(stim_cell_var(i,:,k)) ) && stim_trial_count(i,k)>=20
        
            % Std dev
            std_dev_sub(i,:,k) = sqrt(stim_cell_var(i,:,k)) - allcontrolstd;
            norm_nonan_ref = std_dev_sub(i,CRITICAL_REGION,k);            
            projected_ref = (norm_nonan_ref-mean(norm_nonan_ref,2,'omitnan'))*std_dev_coeff(:,1:NUM_COMPONENTS);
            StddevResp(i,k) = sum(projected_ref.*std_dev_explained')./sum(std_dev_explained);
            
            % Median
            median_sub(i,:,k) = stim_cell_median(i,:,k) - allcontrolmed;
            norm_nonan_ref = median_sub(i,CRITICAL_REGION,k);            
            projected_ref = (norm_nonan_ref-mean(norm_nonan_ref,2,'omitnan'))*median_coeff(:,1:NUM_COMPONENTS);
            MedianResp(i,k) = sum(projected_ref.*median_explained')./sum(median_explained);
            
        end
       
    end
end
%%
valid_boots = sum(~isnan(StddevResp),2) > RERUNS/2;

Avg_StddevResp = mean(StddevResp,2,'omitnan');
Std_StddevResp = std(StddevResp,[],2,'omitnan');
Avg_MedianResp = mean(abs(MedianResp),2,'omitnan');
Std_MedianResp = std(abs(MedianResp),[],2,'omitnan');
Avg_Resp = mean(StddevResp+abs(MedianResp),2,'omitnan');
Std_Resp = std(StddevResp+abs(MedianResp),[],2,'omitnan');



%% Output
save([ stim_intensity '_bootstrapped.mat'],'Avg_StddevResp','Std_StddevResp','Avg_MedianResp','Std_MedianResp',...
     'Avg_Resp', 'Std_Resp','valid_boots','allcoords','ref_image');
%% Plots
figure(1);
plot(Avg_StddevResp(valid_boots), Std_StddevResp(valid_boots),'.'); xlabel('Std Dev Response Average'); ylabel('Std Dev Response RMSE')

figure(2);
plot(Avg_MedianResp(valid_boots), Std_MedianResp(valid_boots),'.'); xlabel('Median Response Average'); ylabel('Median Response RMSE')

figure(3);
plot(Avg_Resp(valid_boots),Std_Resp(valid_boots),'.'); xlabel('Response Average'); ylabel('Response RMSE');
saveas(gcf, [ stim_intensity '_avg_vs_error.png']);

%% Area plots
for i=1:size(allcoords,1)
    if valid_boots(i) && Avg_Resp(i)<1
        i
        mean_std_dev_sub = squeeze(mean(std_dev_sub(i,:,:),3,'omitnan'));
        std_std_dev_sub = squeeze(std(std_dev_sub(i,:,:),[],3,'omitnan'));

        figure(4); clf; hold on;
        area(mean_std_dev_sub+std_std_dev_sub,-2,'FaceColor',[.85 .85 .85],'EdgeColor',[.85 .85 .85]);
        area(mean_std_dev_sub,-2,'FaceColor',[.85 .85 .85]);
        area(mean_std_dev_sub-std_std_dev_sub,-2,'FaceColor',[1 1 1], 'EdgeColor',[1 1 1]);
        title(['Std Dev Mean Response: ' num2str(mean(StddevResp(i,:),2,'omitnan')) ...
                        ' Std dev: ' num2str(std(StddevResp(i,:),[],2,'omitnan')) ...
                        ' Percentage: ' num2str(100*std(StddevResp(i,:),[],2,'omitnan')./mean(StddevResp(i,:),2,'omitnan')) ]);
        axis([2 166 -1 9]);
        
        mean_median_sub = squeeze(mean(median_sub(i,:,:),3,'omitnan'));
        std_median_sub = squeeze(std(median_sub(i,:,:),[],3,'omitnan'));

        figure(5); clf; hold on;
        area(mean_median_sub+std_median_sub,-5,'FaceColor',[.85 .85 .85],'EdgeColor',[.85 .85 .85]);
        area(mean_median_sub,-5,'FaceColor',[.85 .85 .85]);
        area(mean_median_sub-std_median_sub,-5,'FaceColor',[1 1 1], 'EdgeColor',[1 1 1]);
        title(['Median Mean Response: ' num2str(mean(MedianResp(i,:),2,'omitnan')) ...
                        ' Std dev: ' num2str(std(MedianResp(i,:),[],2,'omitnan')) ...
                        ' Percentage: ' num2str(100*std(StddevResp(i,:),[],2,'omitnan')./mean(StddevResp(i,:),2,'omitnan')) ]);
        axis([2 166 -5 5]);
        pause;
    end
end