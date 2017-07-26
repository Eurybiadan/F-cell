

clear;
close all;
clc

[distortfile, distortpath]=uigetfile('*.mat','Select the desinusoid file for this dataset.');

load(fullfile(distortpath,distortfile),'horizontal_fringes_indices_minima');

static_grid_distortion = Static_Distortion_Repair(horizontal_fringes_indices_minima);

motion_path = uigetdir(pwd);

fNames = read_folder_contents(motion_path,'avi');

for i=1:length(fNames)
    Eye_Motion_Distortion_Repair(motion_path, fNames{i}, static_grid_distortion);
end