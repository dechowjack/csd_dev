function writeScalarNC(src_data,src_nc)

%% Write a single-day NetCDF with one 2-D slice (single, NaNs preserved)

% --- CONFIG ---
%src_nc  = 'fullData/WY16/SWE_tavg.nc';   % source to mirror coords/time attrs
out_nc  = 'precip_scalar.nc';      % output file
out_var = 'precip_scalar';               % variable name
nt1     = 1;                              % time length = 1
% --- LOAD COORDS/TIME FROM SOURCE ---

[y, x, latName,lonName] = readLatLonStrict(src_nc);   
nx = numel(x);
ny = numel(y);
tvec = ncread(src_nc,'time');           % keep source time value for compatibility
t1   = tvec(1);                         % first time value

% --- YOUR 2-D FIELD (tmpOut) -> [nx x ny] ---
S = src_data;                               % [nx x ny] or [ny x nx]
if isequal(size(S), [ny nx]), S = S.'; end
if ~isequal(size(S), [nx ny])
    error('tmpOut must be [%d x %d] or [%d x %d], got [%d x %d].', ...
          nx, ny, ny, nx, size(S,1), size(S,2));
end
slab = single(S);                         % preserve NaNs

fprintf('nx=%d ny=%d | size(slab)=[%d %d]\n', nx, ny, size(slab,1), size(slab,2));

% Define chunking that never exceeds the variable size
chunkX = min(512, nx);
chunkY = min(512, ny);
chunkT = 1;                     % time chunking of 1 is usually fine

% --- CREATE OUTPUT (NETCDF4) ---
if isfile(out_nc), delete(out_nc); end
nccreate(out_nc,'x',    'Dimensions',{'x',nx},      'Datatype','single', 'Format','netcdf4');
nccreate(out_nc,'y',    'Dimensions',{'y',ny},      'Datatype','single');
% match source time dtype if possible
time_dtype = class(tvec); if ~ismember(time_dtype, {'single','double'}), time_dtype='single'; end
nccreate(out_nc,'time', 'Dimensions',{'time',nt1},  'Datatype', time_dtype);

% data var: single + light compression + chunked by day (time=1)
nccreate(out_nc, out_var, ...
  'Dimensions', {'x',nx,'y',ny,'time',nt1}, ...
  'Datatype','single', ...
  'DeflateLevel', 3, ...
  'Shuffle', true, ...
  'ChunkSize', [chunkX chunkY chunkT]);

% --- COPY ATTRIBUTES FROM SOURCE COORD VARS  ---
srcX = findCoordVar(src_nc,'x');
srcY = findCoordVar(src_nc,'y');
srcT = findCoordVar(src_nc,'time');

copyAttrs(src_nc, srcX, out_nc, 'x');
copyAttrs(src_nc, srcY, out_nc, 'y');
copyAttrs(src_nc, srcT, out_nc, 'time');


% Provide minimal coords/time if source lacked them
if ~any(strcmpi({ncinfo(out_nc,'x').Attributes.Name}, 'units'))
    ncwriteatt(out_nc,'x','units','degree_east');
end
if ~any(strcmpi({ncinfo(out_nc,'y').Attributes.Name}, 'units'))
    ncwriteatt(out_nc,'y','units','degree_north');
end

% Optional globals
ncwriteatt(out_nc,'/','Conventions','CF-1.7');
ncwriteatt(out_nc,'/','history',sprintf('Created %s by MATLAB; one-day file.', datestr(now)));

% --- WRITE COORDS/TIME ---
ncwrite(out_nc,'x',x);
ncwrite(out_nc,'y',y);
ncwrite(out_nc,'time', t1);              % single time entry from source

% --- WRITE DATA (use low-level API for robustness) ---
ncid = netcdf.open(out_nc,'NC_WRITE');
vid  = netcdf.inqVarID(ncid,out_var);
try, netcdf.endDef(ncid); catch, end
netcdf.putVar(ncid, vid, [0 0 0], [nx ny 1], slab);
netcdf.close(ncid);

disp('Done. Wrote a single-day NetCDF with one 2-D slice (single, compressed).');

% --- POSTCHECK (optional) ---
info = ncinfo(out_nc, out_var);
fprintf('Var "%s" dims: [%d %d %d]\n', out_var, info.Size);
end

function vname = findCoordVar(ncfile, kind)
info = ncinfo(ncfile);
vars = info.Variables;
names = lower({vars.Name});

switch lower(kind)
    case 'x'
        nameHints = {'x','lon','longitude','long','xl','xc','nav_lon'};
        unitHints = {'degrees_east','degree_east'};
        stdHints  = {'longitude'};
    case 'y'
        nameHints = {'y','lat','latitude','yl','yc','nav_lat'};
        unitHints = {'degrees_north','degree_north'};
        stdHints  = {'latitude'};
    case 'time'
        nameHints = {'time','time_counter','t'};
        unitHints = {};
        stdHints  = {'time'};
    otherwise
        vname = "";
        return
end

% 1) direct name match
for i = 1:numel(nameHints)
    idx = find(strcmp(names, nameHints{i}), 1);
    if ~isempty(idx)
        vname = vars(idx).Name;
        return
    end
end

% 2) CF metadata match
for i = 1:numel(vars)
    at = vars(i).Attributes;
    units = "";
    stdnm = "";
    for k = 1:numel(at)
        if strcmpi(at(k).Name,'units'), units = lower(string(at(k).Value)); end
        if strcmpi(at(k).Name,'standard_name'), stdnm = lower(string(at(k).Value)); end
    end
    if any(strcmp(units,unitHints)) || any(strcmp(stdnm,stdHints))
        vname = vars(i).Name;
        return
    end
end

vname = "";  % not found
end

function copyAttrs(src_nc, src_var, dst_nc, dst_var)
if strlength(src_var)==0, return; end
try
    at = ncinfo(src_nc, char(src_var)).Attributes;
catch
    return
end

for k = 1:numel(at)
    nm = at(k).Name;
    if any(strcmpi(nm, {'_FillValue','missing_value'})), continue; end
    ncwriteatt(dst_nc, dst_var, nm, at(k).Value);
end
end
