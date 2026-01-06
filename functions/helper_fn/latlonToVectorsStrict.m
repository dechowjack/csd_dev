function [lat, lon] = latlonToVectorsStrict(LAT, LON)
LAT = squeeze(LAT);
LON = squeeze(LON);

if isvector(LAT) && isvector(LON)
    lat = LAT(:);
    lon = LON(:);
    return
end

% If gridded (2-D), only accept rectilinear grids:
%   - lon varies across columns but is (nearly) constant down rows
%   - lat varies down rows but is (nearly) constant across columns
if ndims(LAT) ~= 2 || ndims(LON) ~= 2
    error("Lat/Lon are not 1-D or 2-D. Rejecting.");
end

% Tolerance for floating noise
tol = 1e-10;

% Check lon constant down rows (each column should be constant over rows)
lonColSpread = max(LON,[],1) - min(LON,[],1);
if any(abs(lonColSpread) > tol)
    error("Gridded lon is not rectilinear (lon changes down rows). Rejecting.");
end

% Check lat constant across columns (each row should be constant over columns)
latRowSpread = max(LAT,[],2) - min(LAT,[],2);
if any(abs(latRowSpread) > tol)
    error("Gridded lat is not rectilinear (lat changes across columns). Rejecting.");
end

lon = LON(1,:).';
lat = LAT(:,1);
end