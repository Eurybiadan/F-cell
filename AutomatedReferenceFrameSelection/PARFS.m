% Rob Cooper 06-30-2017
%
% This script is an moderately modified implementation of the algorithm outlined by Salmon et
% al 2017: "An Automated Reference Frame Selection (ARFS) Algorithm for 
% Cone Imaging with Adaptive Optics Scanning Light Ophthalmoscopy".
%
% At UPenn, we have decided to call it "PARFS: Pretty Accurate Reference
% Frame Selection"

clear;
close all;


NUM_REF_OUTPUT = 3;
MODALITIES = {'confocal','split_det','avg'}; % The modalities to search for.
MODALITY_WEIGHTS = [1/3 1/3 1/3]; % The weights applied to each modality. Adjust these values if you want the first modality (say, confocal) to carry more weight in the reference frame choice.
STRIP_SIZE = 40; % The size of the strip at which we'll analyze the distortion
BAD_STRIP_THRESHOLD = 0; % Having more bad strips than this will result in a frame's removal from consideration.
MIN_NUM_FRAMES_PER_GROUP=5; % A group must have more than this number of frames otherwise it will be dropped from consideration

locInd=1; % Location index
fNames=[];
mov_path=[];
addanother=1;

while addanother ~= 0

    sel_path = uigetdir(pwd,'Select the folder containing the movies you wish to examine:');

    if sel_path == 0
       break; 
    end
    
    names = read_folder_contents(sel_path,'avi');
    
    for f=1:length(names)
        names{f} = fullfile(sel_path, names{f});        
    end
    
    fNames = [fNames; names];
    mov_path = [mov_path; {sel_path}];
    
    
    choice = questdlg('Would you like to select another folder?','','Yes!','No, thank you.','Yes!');
    
    addanother = strcmp(choice,'Yes!');
end
clear names;

found = zeros(length(MODALITIES),1);
dataSummary = cell(1,1);
dataSummary{1} = 'Input Data Summary:';

stack_fname = cell(length(fNames), length(MODALITIES));
for f=1:length(fNames)
    if ~isempty(fNames{f})
        searchind = fNames{f}(end-8:end);        
        samevideos = sort(fNames(~cellfun(@isempty, strfind(fNames, searchind)))); 

        for m = 1:length(MODALITIES)

            matchmode= ~cellfun(@isempty, strfind(samevideos, MODALITIES{m}));
            if any(matchmode)
                stack_fname{f,m} = samevideos{matchmode};
                % Remove it from consideration if we found a match.
                fNames{~cellfun(@isempty, strfind(fNames, samevideos{matchmode}))} = '';
            end

        end
    end
end

for i=1:size(stack_fname,1)
    keep_row(i) = any(~cellfun(@isempty,stack_fname(i,:)));    
end
stack_fname = stack_fname(keep_row,:);

[dmb_fname, dmb_path]=uigetfile(fullfile(pwd,'*.mat'),'Select DEWARP file:');

load(fullfile(dmb_path,dmb_fname),'vertical_fringes_desinusoid_matrix');

desinusoid_matrix = vertical_fringes_desinusoid_matrix';


% [stack_fname, mov_path] = uigetfile(fullfile(dmb_path,'*.avi'),'Select movies from single timepoint:', 'MultiSelect', 'on');

% stack_fname = {stack_fname};
% mov_path = mov_path;
h=waitbar(0,'Finding reference frames...');

bestrefs=zeros(size(stack_fname,1), 11);

delete(fullfile(mov_path{1},'Reference_Frames.csv'));

%% Analyze the list.
refs = cell(size(stack_fname));

for f=1 : size(stack_fname,1)
    waitbar(f/size(stack_fname,1),h,['Processing video #' num2str(stack_fname{f,1}(end-7:end-4)) '...']);
    
    try
        for m=1 : size(stack_fname,2) 
            tic;

            refs{f,m} = extract_candidate_reference_frames(stack_fname{f,m}, desinusoid_matrix, STRIP_SIZE, BAD_STRIP_THRESHOLD, MIN_NUM_FRAMES_PER_GROUP);

            toc;
        end
    catch
        warn(['Failed to find a reference frame in:' stack_fname{f,m}])
    end
    
    % Look for correspondence between all of the modalities.
    
    %% NEED TO ADD GROUP SUPPORT!
    intersected = refs{f,1};
    for m=2 : size(stack_fname,2)  
        intersected = union(intersected, refs{f,m});    
    end
    
    intersected(intersected==-1) = [];

    average_rank = nan(length(intersected),1);
    for r=1:length(intersected)
        of_interest = intersected(r);

        whichind = size(stack_fname,2)*ones(size(stack_fname,2) ,1); % Weight heavily against a reference frame if it doesn't show in all modalities.
        for m=1 : size(stack_fname,2) 
            rank = find( refs{f,m}==of_interest );
            if ~isempty(rank)
                whichind(m) = rank*MODALITY_WEIGHTS(m);
            end
        end
        average_rank(r) = sum(whichind);
    end

    [rankings, rankinds ] = sort(average_rank,2,'ascend');

    intersected = intersected(rankinds);

    vidnum = stack_fname{f,1}(end-7:end-4);
    bestrefs(f,:) = [str2double(vidnum) intersected(1:10)'];
    
    dlmwrite(fullfile(mov_path{1},'Reference_Frames.csv'), bestrefs(f,:), 'delimiter',',','-append');
end
close(h);




