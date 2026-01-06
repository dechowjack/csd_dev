function [lat, lon, latName, lonName] = readLatLonStrict(ncfile)
%READLATLONSTRICT Read lat/lon vectors from NetCDF.
% - Handles 1-D lat/lon OR 2-D gridded lat/lon (rectilinear only)
% - Rejects projected datasets (x/y in meters, grid_mapping, crs, etc.)

info = ncinfo(ncfile);

% 1) Reject projected datasets early
rejectIfProjected(info);

% 2) Find candidate lat/lon variable names (common conventions + CF attrs)
[varLat, varLon] = findLatLonVars(info);

latName = varLat;
lonName = varLon;

% 3) Read
LAT = ncread(ncfile, latName);
LON = ncread(ncfile, lonName);

% 4) Convert to vectors if needed
[lat, lon] = latlonToVectorsStrict(LAT, LON);
end











