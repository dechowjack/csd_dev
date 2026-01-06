%% CoReSSD Main Preprocessing script
% Top level script to run all CoReSSD preprocessing.
clear all
addpath(genpath('functions'));
clc
%% 0 Get Water Year from User
try
    yearPath = strcat('WY',WY);
catch
    warning("Water year variable not assigned!")
    WY = input("Please enter requested 4 digit water year :");
    if isnumeric(WY)
        WY = num2str(WY);
    end
    yearPath = strcat('WY',WY);
end


%% 1 Run csd_gen_mean_scf_files

run('csd_gen_mean_scf_files.m')

%% 2 Run csd_gen_psval_nc

run('csd_gen_psval_nc.m')

%% 3 Run Gauss smoother

inPath = './discover/nobackup/projects/coressd/Blender/Inputs';
outPath = './discover/nobackup/projects/coressd/Blender/SmoothedInputs';
sigma_pixels = 0.5;

% 3.1 Snowf
csd_smooth_mass_vars(inPath,outPath,'Snowf',WY,sigma_pixels)

% 3.2 SWE
csd_smooth_mass_vars(inPath,outPath,'SWE',WY,sigma_pixels)