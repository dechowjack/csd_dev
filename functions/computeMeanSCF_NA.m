function avgSCF = computeMeanSCF_NA(fname,dx,dy)
%% MANUAL - computeMeanSCF_NA
% Jack Dechow UNC Chapel Hill July 2025
% Compute pixelwise mean for MODIS SCF over entire year. Reads the ncdata
% in as [dx dy 365] chunks to avoid memory issues
%
% PARAMETERS
% ==============
% fname: ncfile path
% dx: chunk size in X (default 100)
% dy: chunk size in Y (default 100)
%


    if nargin < 3 || isempty(dx) || isempty(dx)
        dx = 100; dy = 100;
    end

    vname = 'SCF';

    % Read in var info
    info = ncinfo(fname,vname);
    ny = info.Size(1); nx = info.Size(2); nt = info.Size(3);
    NODATA = info.FillValue;

    % Create output array - single nan cuts mem size down
    avgSCF = nan(ny,nx,'single');
    nTilesY = ceil(ny / dy);
    nTilesX = ceil(nx / dx);
    
    % Main Loop
   
    for i = 1:nTilesY
        if mod(i,5) == 0 
            fprintf('Done with %d tile rows \n',i)
        end   
        yStart = (i-1)*dy + 1;
        yCount = min(dy, ny - yStart + 1);
        
        for j = 1: nTilesX
            xStart = (j-1)*dx + 1;
            xCount = min(dx, nx - xStart + 1);

            % Actual read
            start = [yStart, xStart, 1];
            count = [yCount, xCount, nt];

            % Read as single to save memory
            tileSCF = single(ncread(fname, vname, start, count));
            SCF_smooth = smoothSCF(tileSCF,14,nt,'median');
            tileMeanSCF = mean(SCF_smooth, 3, 'omitnan'); 

            % Write output array
            avgSCF(yStart:yStart+yCount-1, xStart:xStart+xCount-1) = tileMeanSCF;

        end
    end
end