%% CoReSSD Generate Mean SCF Files
% Jack Dechow UNC Chapel Hill January 2026
% This script generates the NA_MeanSCF_WYXXXX.nc files used to create the
% precip_scalar.nc files for use later in the Blender/CoReSSD pipeline.
% File i/o paths are hardcoded for NASA NCCS Discover cluster.
% Assumes WY string has already been passed in master script

%% 0 Set up file paths

% Assign full WY path
try
    yearPath = strcat('WY',WY);
catch
    warning("Water year variable not assigned!")
    WY = input("Please enter requested water year as a string:");
    yearPath = strcat('WY',WY);
end

% Generate i/o dir paths
inPath = '/discover/nobackup/projects/coressd/Blender/Inputs';
fDir_i = [inPath '/' yearPath '/'];
fDir_o = '/discover/nobackup/projects/coressd/csd_dev/aux_data/MeanSCF/';

% Generate i/o file paths
inFile =    [fDir_i 'SCF.nc'];
outFile =   [fDir_o 'NA_MeanSCF_' yearPath '.tif'];


%% Check if file exists
if ~isfile(outFile)
    %% 1 Set options + run functions
    % Chunk size for computeMean function to work over
    dx = 100; dy = dx;
    disp('Starting Mean Annual SCF Computation now:')
    avgSCF = computeMeanSCF_NA(inFile,dx,dy);
    
    %% 2 Mask ocean
    
    load('./aux_data/scf_mask.mat')
    avgSCF = pagetranspose(avgSCF); % Dimensions are flipped
    avgSCF(mask) = nan;
    %% 3 Load XY data and write file
    
    x = ncread(inFile,'x'); y = ncread(inFile,'y');
    [X,Y] = meshgrid(x,y);
    pathToPRJ = './aux_data/MODIS_SINUSOIDAL_fixed.prj';
    Z = avgSCF'; % Have to flip back to write
    writeGeoTIFF_withPRJ(outFile, Z, X, Y, pathToPRJ);
else
    disp('MeanSCF file already exists! Moving to next script.')
end