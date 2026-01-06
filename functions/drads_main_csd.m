function [outMap] = drads_main_csd(avgSCF_data,DEM_data,x,y)
    %% MANUAL - drads_main()
    % This is a modified version of the D-RADS main function specifically for
    % the CoReSSD project. The only change made to this version against the
    % original is the ability to read two disparate shapefiles (one for the
    % US and one for CA) to create a unified output map for all HUC8 basins
    % in NA. This was done due to differences in basin shapefiles from the
    % WBD dataset and the Canadian equivalent. There is no difference in 
    % the functionality of the algorithm in this version.
    %
    % INPUTS
    % ========
    % avgSCF    - Mean Annual SCF array
    % DEM_data  - DEM used 
    % x         -  column vector of longitude values from scf data
    % y         -  column vector of latitude values from scf data
    
    %% 1. Fix data types

    if ~isa(avgSCF_data,'single')
        avgSCF_data = single(avgSCF_data);
    end

    if ~isa(DEM_data,'single')
        DEM_data = single(DEM_data);
    end
    % Assign shapefile paths and read in

    sNameUS = 'aux_data/HUC8_US/WBD_National_GPKG.shp';
    sNameCA = 'aux_data/HUC8_CA/rhn_nhn_decoupage.shp';

    % Set scaling parameters
    fmin = 0.5;
    fmax = 1.5;
    gamma = 1.6;
    
    
    %% Scaling Algorithm    

    scaleMap_US = drads_basin_csd(avgSCF_data,DEM_data,fmin,fmax,gamma,x,y,sNameUS);
    scaleMap_CA = drads_basin_csd(avgSCF_data,DEM_data,fmin,fmax,gamma,x,y,sNameCA);

    % Merge
    combined = scaleMap_US;
    isCA = ~isnan(scaleMap_CA);
    combined(isCA) = scaleMap_CA(isCA);

    % Smooth output
    outMap = imgaussfilt_nan(combined,.5);
end
