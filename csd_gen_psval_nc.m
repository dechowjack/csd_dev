%% CoReSSD Precip Scalar Script'
% Jack Dechow Chapel Hill January 2026
% This script generates the precip_scalar.nc file for a given water year.
% The WY var should be fed to MATLAB from the top level bash script on
% discover. This script assumes fixed directories on Discover and thus are
% all hardcoded.


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
xyPath = './discover/nobackup/projects/coressd/Blender/Inputs';
inPath = './discover/nobackup/projects/coressd/Process/aux_data/MeanSCF';
outPath = './discover/nobackup/projects/coressd/PrecipScalarFiles';
fDir_xy = [xyPath '/' yearPath '/'];
fDir_i = [inPath '/'];
fDir_o = [outPath '/' yearPath '/'];

% Check that output dir exists
if ~exist(fDir_o, 'dir')
    mkdir(fDir_o);
end

% Generate i/o file paths
xyFile =    [fDir_xy 'SCF.nc'];
inFile =    [fDir_i 'NA_MeanSCF_' yearPath '.tif'];
outFile =   [fDir_o 'precip_scalar.nc'];

%% 1 Read in data

% Read DEM
DEM_file = './aux_data/MODDEM1KM_fixed.tif';
[tmpDEM,~] = geotiffread(DEM_file);
DEM = flip(tmpDEM); clear tmpDEM;

% Read SCF
avgSCF = flip(geotiffread(inFile));

%% 3. Read target grid
[targetGrid.lat, targetGrid.lon, targetGrid.latName, targetGrid.lonName] = readLatLonStrict(xyFile);

%% 4 Run algorithm

scaleMap = drads_main_csd(avgSCF,DEM,targetGrid.lon,targetGrid.lat);

%% 5 Write output

writeScalarNC(scaleMap,xyFile);

movefile('precip_scalar.nc', outFile);
