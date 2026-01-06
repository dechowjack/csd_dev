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
    s = shaperead(shapePath);
    info = shapeinfo(shapePath);
    p1 = info.CoordinateReferenceSystem;
    fn = fieldnames(p1);
    
   
    % Filter Hawaii PR etc - Extract SCF Corners
    minLat = min(ys(:)); maxLat = max(ys(:));
    minLon = min(xs(:)); maxLon = max(xs(:));
    
    % Extract Bounding Box from Shapefile
    BB = reshape([s.BoundingBox], 2, 2, []);   % -> 2x2xN
    minLon_f = squeeze(BB(1,1,:)); minLat_f = squeeze(BB(1,2,:));
    maxLon_f = squeeze(BB(2,1,:)); maxLat_f = squeeze(BB(2,2,:)); 

    % Check if shapefile is projected or not
    if ismember("LengthUnit", fn)
        [tmpMinLat,tmpMinLon] = projinv(p1, minLon_f, minLat_f);
        [tmpMaxLat,tmpMaxLon] = projinv(p1, maxLon_f, maxLat_f);

        clear minLon_f; clear minLat_f; 
        clear maxLon_f; clear maxLat_f;
        
        minLon_f = tmpMinLon; clear tmpMinLon;
        minLat_f = tmpMinLat; clear tmpMinLat;
        maxLon_f = tmpMaxLon; clear tmpMaxLon;
        maxLat_f = tmpMaxLat; clear tmpMaxLat;

    end
    % Get mask

    fullyInside = (minLon_f >= minLon & maxLon_f <= maxLon & ...
               minLat_f >= minLat & maxLat_f <= maxLat);

    mask = fullyInside;            % or centroidInside, or fullyInside

    lon_c = 0.5*(minLon_f + maxLon_f);
    lat_c = 0.5*(minLat_f + maxLat_f);
    centroidInside = (lon_c >= minLon & lon_c <= maxLon & ...
                  lat_c >= minLat & lat_c <= maxLat);

    mask = centroidInside;   
    tmp = s(mask); 
    clear s; s = tmp; clear tmp;
    
    sLL = struct();

    for i = 1 : numel(s)
        if ismember("LengthUnit", fn)
            x = s(i).X; y = s(i).Y;
            [sLL(i).Lat, sLL(i).Lon] = projinv(p1, x, y);
        else
            sLL(i).Lat =  s(i).Y ;
            sLL(i).Lon =  s(i).X ;
        end
    end

    clear minX; clear maxX; clear minY; clear maxY; clear BB;
    clear minLon_f; clear maxLon_f; clear minLat_f; clear maxLat_f;
    clear fullyInside; clear mask; %clear s;

    %% Algorithm 

    %% Build a geographic raster reference object R
nCols = numel(xs);
nRows = numel(ys);

latlim = [min(ys) max(ys)];
lonlim = [min(xs) max(xs)];
R = georefpostings(latlim, lonlim, [nRows nCols]);

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
        [xI, yI] = geographicToIntrinsic(R, latv(i1:i2), lonv(i1:i2));

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

    % One tight global window for the polygon (clip to raster)
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
 

    % Run your algorithm on masked pixels only
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
