%% Write Scalar Files for NA Runs
close all; clear all; clc;
writeF = 1;
WY = 'WY17'
addpath('Functions')
addpath('/Users/jldechow/Documents/Projects/OSU/Blender/ERA5_Procssing/drads/helper_fn/')
gridFile = ['fullData/' WY '/SCF.nc'];
src_nc = ['fullData/' WY '/SWE_tavg.nc'];
x = ncread(gridFile,'x'); y = ncread(gridFile,'y');
dataDir = '/Users/jldechow/Documents/Projects/UNC/CoReSSD_Tiffs/MeanSCF/';
[X,Y] = meshgrid(x,y);
[scaleMap,~] = generateScaleMap_NA(dataDir,WY,'huc8');

scfData = ncread(gridFile,'SCF',[1,1,183],[inf,inf,1]);

sweData = ncread(src_nc,'SWE_tavg',[1,1,183],[inf,inf,1]);

tmpOut = scaleMap';
mask1 = isnan(tmpOut) & ~isnan(sweData); 
mask2 = isnan(tmpOut) & ~isnan(scfData); 
tmpOut(mask1) = 1; tmpOut(mask2) = 1;
%tmpOut(isnan(tmpOut)) = 1;

% figure(1); clf
% h = pcolor(X,Y,scfData'); set(h,'LineStyle','none')
% 
% figure(2); clf
% h = pcolor(X,Y,sweData'); set(h,'LineStyle','none')
% 
% figure(3); clf
% h = pcolor(X,Y,tmpOut'); set(h,'LineStyle','none')

    Z = tmpOut';
    writeName = ['NA_PrecipScalar_' WY '.tif']
    pathToPRJ = ['/Users/jldechow/Data/MODIS_PROJECTION/MODIS_SINUSOIDAL_fixed.prj']
    writeGeoTIFF_withPRJ(writeName,Z , X, Y, pathToPRJ);
%% Write NC
%% Fast compressed NetCDF writer (single, NaNs preserved, time-chunk=1)

% --- CONFIG ---
src_nc  = ['fullData/' WY '/SWE_tavg.nc'];   % source to mirror coords/time
out_nc  = 'precip_scalar.nc';            % output file
out_var = 'precip_scalar';               % variable name

writeScalarNC(tmpOut,src_nc)

