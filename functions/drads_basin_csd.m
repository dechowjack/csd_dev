function scaleMap = drads_basin_csd(SCFdata,DEM,fmin,fmax,gamma,xs,ys,shapePath)
    % Jack Dechow UNC Chapel Hill December 2025

    %% Arg Checks       
    if nargin < 8 || isempty(shapePath) 
        disp('No watershed provided; Function call canceled');
        return;
    end 
    if nargin < 7 || isempty(xs) || isempty(ys)
        disp('No lat lon provided; Function call canceled');
        return;
    end
    if nargin < 5 || isempty(gamma) 
        gamma = 1;
    end
    if nargin < 4 || isempty(fmin) || isempty(fmax) 
        fmin = 0.5; fmax = 1.5;
    end
    thresh = 0; 
    %% Read watershed data
    % xs and ys are vectors containing the lon/lat data from the tiff files

    load(shapePath);
    %% Algorithm 

    %% Build a geographic raster reference object R
    nCols = numel(xs);
    nRows = numel(ys);
    
    latlim = [min(ys) max(ys)];
    lonlim = [min(xs) max(xs)];
    
    
    % Confirm your data matches
    assert(all(size(SCFdata)==[nRows nCols]), 'data size mismatch with xs/ys');
    
    % Prepare output
    out = nan(nRows, nCols, 'single');
    isScale = nan(numel(sLL),1);
%% Loop polygons (fixed bbox per polygon + robust guards)
for ii = 1:numel(sLL)
    latv = sLL(ii).Lat(:);
    lonv = sLL(ii).Lon(:);
    if isempty(latv) || isempty(lonv), continue; end

    % Split multipart on NaNs
    brk = isnan(latv) | isnan(lonv);
    edges = [0; find(brk); numel(latv)+1];

    % Adaptive thresholds (in pixels)
    pxTallMin = 50;                              % parts shorter than this are suspicious
    pxWideMin = max(150, round(nCols*0.07));     % very wide if >= ~7% of raster width
    fillMin   = 0.10;                            % min fill fraction of its own bbox
    areaMin   = 250;                             % min connected component size (px)

    % First pass: keep only valid parts & track global bbox
    keptParts = {};   % each entry is [xI, yI] intrinsic coords
    xmin = inf; xmax = -inf; ymin = inf; ymax = -inf;

    for p = 1:numel(edges)-1
        i1 = edges(p)+1; i2 = edges(p+1)-1;
        if i2 < i1 || (i2 - i1 + 1) < 3, continue; end

        % Geographic -> intrinsic (columns=xI, rows=yI)
        [xI, yI] = latlon_to_intrinsic(xs, ys, lonv(i1:i2), latv(i1:i2));


        % ---------------- Guard 1: flat & wide ----------------
        h = max(yI) - min(yI);
        w = max(xI) - min(xI);
        if (h < pxTallMin) && (w > pxWideMin)
            continue
        end

        % ---------------- Guard 2: density (per-part bbox) ----------------
        cmin_p = max(floor(min(xI)), 0.5);
        cmax_p = min( ceil(max(xI)), double(nCols)+0.5);
        rmin_p = max(floor(min(yI)), 0.5);
        rmax_p = min( ceil(max(yI)), double(nRows)+0.5);

        c1p = max(1, floor(cmin_p+0.5));  c2p = min(nCols, ceil(cmax_p-0.5));
        r1p = max(1, floor(rmin_p+0.5));  r2p = min(nRows, ceil(rmax_p-0.5));
        winHp = r2p - r1p + 1;  winWp = c2p - c1p + 1;
        if winHp <= 0 || winWp <= 0, continue, end

        xIp = xI - (c1p-1);
        yIp = yI - (r1p-1);
        partMaskSmall = poly2mask(xIp, yIp, winHp, winWp);

        fillFrac = nnz(partMaskSmall) / numel(partMaskSmall);
        if fillFrac < fillMin
            continue
        end

        % ---------------- Guard 3: min connected area ----------------
        CC = bwconncomp(partMaskSmall);
        if CC.NumObjects == 0 || max(cellfun(@numel, CC.PixelIdxList)) < areaMin
            continue
        end

        % Keep this part
        keptParts{end+1} = [xI(:), yI(:)]; %#ok<AGROW>
        xmin = min(xmin, min(xI)); xmax = max(xmax, max(xI));
        ymin = min(ymin, min(yI)); ymax = max(ymax, max(yI));
    end

    if isempty(keptParts)
        continue % nothing usable in this polygon
    end

    % global window for the polygon (clip to raster)
    cmin = max(floor(xmin), 0.5);
    cmax = min( ceil(xmax), double(nCols)+0.5);
    rmin = max(floor(ymin), 0.5);
    rmax = min( ceil(ymax), double(nRows)+0.5);
    if ~(cmax>cmin && rmax>rmin), continue, end

    col1 = max(1, floor(cmin+0.5));  col2 = min(nCols, ceil(cmax-0.5));
    row1 = max(1, floor(rmin+0.5));  row2 = min(nRows, ceil(rmax-0.5));
    winH = row2 - row1 + 1;  winW = col2 - col1 + 1;

    % Rasterize all kept parts into this fixed window
    windowMask = false(winH, winW);
    for k = 1:numel(keptParts)
        xy = keptParts{k};
        xWin = xy(:,1) - (col1-1);
        yWin = xy(:,2) - (row1-1);
        windowMask = windowMask | poly2mask(xWin, yWin, winH, winW);
    end
    if ~any(windowMask,'all'), continue, end

    % Slice this window from data
    tileSCF = SCFdata(row1:row2, col1:col2);
    tileDEM = DEM(row1:row2, col1:col2);
    %tileY = DEM(row1:row2, col1:col2);
 

    % Run algorithm on masked pixels only
    tmpSCF = tileSCF(windowMask);
    tmpDEM = tileDEM(windowMask);
    % Pre algo checks
    numPix = length(tmpSCF(:));
    numZero = length(find(tmpSCF(:)<0.01));
    val = scaleAlgoSubRoutine(tmpSCF,tmpDEM);
    max_tileSCF = max(tmpSCF(:));
    gate = 1;
    if (numZero/numPix)>0.90 %&& max_tileSCF < 0.15
        gate = 0 ;
    elseif (numZero/numPix)>0.75 && max_tileSCF < 0.1
        gate = 0 ;
    end
    if val==3
        if min(latv(:)) > 55
            val = 4;
        end
    end
        
    % Run algo
    if gate > 0
        if val == 0 || val == 3
            scalar = single(precipScaleAlg(tmpSCF,gamma,fmin,fmax,thresh));
            isScale(ii) = 1;
        elseif val == 1 
            scalar = single(precipScaleAlg(tmpSCF,gamma,0.75,1.25,thresh));
            isScale(ii) = 1;
        elseif val == 2 
            scalar = single(ones(size(tmpSCF)));
            isScale(ii) = 0;
        elseif val == 4
            scalar = single(precipScaleAlg(tmpSCF,gamma,0.5,1.5,thresh));
            isScale(ii) = 1;
        end
    else
        scalar = single(ones(size(tmpSCF)));
        isScale(ii) = 0;
    end

    if numel(scalar) ~= numel(tmpSCF)
        error('Output size mismatch on basin %d', ii);
    end

    % Write back
    tile_out = out(row1:row2, col1:col2);
    tile_out(windowMask) = single(scalar);
    out(row1:row2, col1:col2) = tile_out;
end


scaleMap = out;

end


function [xI, yI] = latlon_to_intrinsic(xs, ys, lon, lat)
% xs: 1xnCols longitudes at pixel centers (increasing)
% ys: 1xnRows latitudes at pixel centers (may increase or decrease)
% lon, lat: vectors of polygon vertices (same size)
% Returns intrinsic coords where xI=column, yI=row (1-based), matching poly2mask use
% Was forced to add this to get around issues with discover matlab mapping
% toolbox licenses
% 7 Jan 2026

xs = double(xs(:).');   % row
ys = double(ys(:).');   % row
lon = double(lon(:));
lat = double(lat(:));

nCols = numel(xs);
nRows = numel(ys);

% Assume approximately uniform spacing
dlon = median(diff(xs));

% Handle ys direction
dlat = median(diff(ys));
ys0  = ys(1);

if dlat > 0
    % south -> north as row increases 
    yI = 1 + (lat - ys0) / dlat;
else
    % north -> south as row increases 
    dlat = abs(dlat);
    yI = 1 + (ys0 - lat) / dlat;
end

xI = 1 + (lon - xs(1)) / dlon;

% clamp a bit to avoid extreme out-of-range numerics
xI = min(max(xI, 0.5), nCols + 0.5);
yI = min(max(yI, 0.5), nRows + 0.5);
end
