
% Created by Robert F Cooper 2018-09-06
%

clear;


NUMTRIALS=6;
CRITICAL_TIME = 0:70;
START_IND=7;

CELL_OF_INTEREST = [];

if isempty(CELL_OF_INTEREST)
    close all force;
end

if ~exist('stimRootDir','var')
    stimRootDir = uigetdir(pwd, 'Select the directory containing the densitometry profiles');
end

profileSDataNames = read_folder_contents(stimRootDir,'mat');

% For structure:
% /stuff/id/date/wavelength/time/intensity/location/data/Profile_Data

% [remain kid] = getparent(stimRootDir); % data
% [remain stim_loc] = getparent(remain); % location 
% [remain stim_intensity] = getparent(remain); % intensity 
% [remain stim_time] = getparent(remain); % time
% [remain stimwave] = getparent(remain); % wavelength
% % [remain sessiondate] = getparent(remain); % date
% [~, id] = getparent(remain); % id
% outFname = [id '_' stimwave '_' stim_intensity '_' stim_time  '_' stim_loc '_' num2str(length(profileSDataNames)) '_single_cone_signals'];



%% Code for determining variance across all signals at given timepoint

THEwaitbar = waitbar(0,'Loading profiles...');

max_index=0;

load(fullfile(stimRootDir, profileSDataNames{1}));
stim_coords = ref_coords;

if ~isempty(CELL_OF_INTEREST)
    stim_cell_reflectance = cell(length(profileSDataNames),1);
end
stim_cell_reflectance_nonorm = cell(length(profileSDataNames),1);
stim_time_indexes = cell(length(profileSDataNames),1);
stim_cell_prestim_mean = cell(length(profileSDataNames),1);

for j=1:length(profileSDataNames)

    waitbar(j/length(profileSDataNames),THEwaitbar,'Loading profiles...');
    
    ref_coords=[];
    profileSDataNames{j}
    load(fullfile(stimRootDir,profileSDataNames{j}));
    
    if ~isempty(CELL_OF_INTEREST)
        stim_cell_reflectance_nonorm{j} = cell_reflectance;
    end
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

% The coordinate lists must the same length,
% otherwise it's not likely they're from the same set.

allcoords = stim_coords;


%% Aggregation of all trials

percentparula = parula(101);

numstimcoords = size(stim_coords,1);

fitAmp = nan(numstimcoords,1);

hz = 17.75;
i=1;

% Create the fit we're going to use. This is what is outlined in Ram's
% paper.
ft = fittype( 'c-a*exp(-x/b)', 'independent', 'x', 'dependent', 'y' );
opts = fitoptions( 'Method', 'NonlinearLeastSquares' );
opts.Display = 'Off';
opts.Lower = [0 0 0];
opts.Upper = [1 Inf 1];
opts.StartPoint = [0.4 0.4 0.7];
        
for i=1:numstimcoords
    waitbar(i/size(stim_coords,1),THEwaitbar,'Processing signals...');

    numtrials = 0;
    all_times_ref = nan(length(profileSDataNames), max_index);
    all_times = nan(length(profileSDataNames), max_index);
    for j=1:length(profileSDataNames)
        
        if ~isempty(stim_cell_reflectance{j}{i})
           
            numtrials = numtrials+1;

            all_times_ref(j, stim_time_indexes{j}{i} ) = stim_cell_reflectance{j}{i};
            all_times(j, stim_time_indexes{j}{i}) = stim_time_indexes{j}{i}/hz;
        end              
    end
    stim_trial_count(i) = numtrials;
    
    if stim_trial_count(i)>=NUMTRIALS
        all_times = all_times(:,START_IND:end);
        all_times_ref = all_times_ref(:,START_IND:end);

        % Fit the model from Ram's paper to the data.
        vect_ref = all_times_ref(~isnan(all_times));
        vect_times = all_times(~isnan(all_times));
        vect_times = vect_times-min(vect_times);
        [fitresult, gof] = fit( vect_times, vect_ref, ft, opts );

        
        criticalfit = fitresult(CRITICAL_TIME/hz);
        fitAmp(i) = max(criticalfit)-min(criticalfit);
        
        if any(i==CELL_OF_INTEREST) %|| (fitAmp(i) <0.12 && fitAmp(i) >0.08)
            figure(1); clf; hold on;        
            plot(vect_times,vect_ref,'.');
            plot(CRITICAL_TIME/hz, criticalfit);
            xlabel('Time index'); ylabel('Standardized Response');
            title(['Cell #:' num2str(i) ', Amplitude: ' num2str(fitAmp(i))]);
            axis([0 CRITICAL_TIME(end)/hz 0 1.5]);
            hold off;
            drawnow;

            pause;
        end
    end

end
close(THEwaitbar);
valid = (stim_trial_count >= NUMTRIALS);

%% Analyze the fitted amplitudes

histogram(fitAmp,40);
xlabel('Fitted amplitude'); ylabel('Number of cones');