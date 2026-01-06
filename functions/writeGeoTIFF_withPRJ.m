function writeGeoTIFF_withPRJ(outTif, Z, X, Y, prjFile)
% R2024b: Write GeoTIFF from Z,X,Y with CRS from a .prj (WKT).
% - Auto-transposes Z if needed to match X,Y
% - Tries to extract EPSG from .prj and sets 'CoordRefSysCode'
% - Uses LZW compression via TiffTags
%
% Inputs:
%   outTif  : "time_mean.tif"
%   Z       : [nY x nX] numeric (single recommended)
%   X, Y    : meshgrid same size as Z (projected meters or lon/lat degrees)
%   prjFile : path to .prj (WKT)

    % ---- Ensure 2-D and match shapes ----
    Z = squeeze(Z);
    if ndims(Z) ~= 2
        error('Z must be 2-D; got size %s.', mat2str(size(Z)));
    end
    if ~isequal(size(Z), size(X)) || ~isequal(size(Z), size(Y))
        if isequal(size(Z), fliplr(size(X)))
            Z = permute(Z, [2 1]);  % swap dims to match X,Y
        else
            error('Size mismatch: size(Z)=%s, size(X)=size(Y)=%s', ...
                  mat2str(size(Z)), mat2str(size(X)));
        end
    end

    % ---- Spacing (assume rectilinear) ----
    dx = mean(diff(X(1,:)));
    dy = mean(diff(Y(:,1)));
    if ~all(isfinite([dx,dy])) || dx == 0 || dy == 0
        error('Could not infer constant nonzero spacing from X/Y.');
    end

    % ---- Build spatial reference (let limits encode row direction) ----
    nrows = size(Z,1);
    ncols = size(Z,2);

    % X limits always west->east; Y order determines row direction
    xlim = [min(X(:)) - 0.5*dx, max(X(:)) + 0.5*dx];
    if dy > 0
        ylim = [min(Y(:)) - 0.5*dy,  max(Y(:)) + 0.5*dy];  % south->north
    else
        ylim = [max(Y(:)) + 0.5*abs(dy), min(Y(:)) - 0.5*abs(dy)]; % north->south
    end

    % Decide projected vs geographic by simple heuristic: degrees vs meters
    isGeographic = max(abs([xlim ylim])) <= 360 && max(abs([dx dy])) <= 5;
    if isGeographic
        R = georefcells();
        R.RasterSize      = [nrows ncols];
        R.LongitudeLimits = xlim;
        R.LatitudeLimits  = ylim;
    else
        R = maprefcells();
        R.RasterSize   = [nrows ncols];
        R.XWorldLimits = xlim;
        R.YWorldLimits = ylim;
    end

    % ---- Read .prj and try to get an EPSG code ----
    wkt = fileread(prjFile);
    epsg = parseEPSGFromWKT(wkt);   % [] if none found

    % ---- TIFF tags (compression) ----
    TT = struct('Compression', Tiff.Compression.LZW);

    % ---- Write GeoTIFF ----
    if ~isempty(epsg)
        geotiffwrite(outTif, Z, R, 'CoordRefSysCode', epsg, 'TiffTags', TT);
    else
        % No EPSG in .prj: write the GeoTIFF without CRS tag,
        % and also drop a sidecar .prj so most GIS can still pick it up.
        geotiffwrite(outTif, Z, R, 'TiffTags', TT);
        try
            [p,f,~] = fileparts(outTif);
            prjOut = fullfile(p, [f '.prj']);
            fid = fopen(prjOut, 'w'); fwrite(fid, wkt); fclose(fid);
            warning('EPSG not found in .prj; wrote TIFF + sidecar .prj: %s', prjOut);
        catch
            warning('EPSG not found and failed to write sidecar .prj.');
        end
    end
end

function epsg = parseEPSGFromWKT(wktText)
% Try common patterns to extract EPSG code from WKT/ESRI WKT.
    epsg = [];
    % AUTHORITY["EPSG","####"]
    tok = regexp(wktText, '(?i)AUTHORITY\["EPSG","(\d+)"\]', 'tokens', 'once');
    if ~isempty(tok), epsg = str2double(tok{1}); return; end
    % AUTHORITY["EPSG",####]
    tok = regexp(wktText, '(?i)AUTHORITY\["EPSG",\s*(\d+)\s*\]', 'tokens', 'once');
    if ~isempty(tok), epsg = str2double(tok{1}); return; end
    % Simple EPSG:#### fallback
    tok = regexp(wktText, '(?i)EPSG[:\s]+(\d+)', 'tokens', 'once');
    if ~isempty(tok), epsg = str2double(tok{1}); end
end
