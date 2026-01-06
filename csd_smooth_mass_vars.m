function csd_smooth_mass_vars(inPath,outPath,massVar,WY,sigma_pixels)
% Apply Gaussian smoothing to CoReSSD mass inputs (SWE and Snowfall).
% Smoothing is applied with imgaussfilt_nan(). This function was written
% with the expectation that unsmoothed inputs and smoothed outputs are kept
% in separate folders. Vars inPath and outPath expect top level directory 
% holding subdirectories for each year of data. Output vars are written
% with format file_name_smooth.nc and need to be processed later with bash
% scripts to fix broken metadata and then renamed to match the original
% file_name.nc for CoReSSD main algorithm to read them correctly. For this
% reason they are kept in separate directories from original inputs.
%
% Variables
% ==========
% inPath        - top level directory for input data (unsmoothed)   #string
% outPath       - top level directory for output data (smoothed)    #string
% massVar       - variable to smooth opts: SWE | Snowf              #string
% WY            - Water year to apply smoothing to eg. '2016'       #string
% sigma_pixels  - Radius to use for Gauss smoothing                 #double
% 
% written by Jack Dechow January 2026

%% 0 Config

% Generate i/o dir paths
yearPath = strcat('WY',WY);
fDir_i = [inPath '/' yearPath '/'];
fDir_o = [outPath '/' yearPath '/'];

% Check that output dir exists
if ~exist(fDir_o, 'dir')
    mkdir(fDir_o);
end

% Assign full var name from input mass var declaration
if strcmp(massVar,'SWE')
    varName = 'SWE_tavg';
elseif strcmp(massVar,'Snowf')
    varName = 'Snowf_tavg';
end

% Generate i/o file paths
inFile =    [fDir_i varName '.nc'];
outFile =   [fDir_o varName '_smooth.nc'];

% Assign other vars to write nc
xName = 'x'; yName = 'y'; tName = 'time';

% ui16 flag
keepUInt16    = true;        % true: write back as uint16 with 65535 nodata
                             % false: write as single with NaN nodata
                            
% nc write options
chunkXY       = [1024 512 1];
deflate       = 4; shuffle       = true;

%% 1 Inspect input
infoV = ncinfo(inFile, varName);
nx = infoV.Size(1); ny = infoV.Size(2); nt = infoV.Size(3);

x  = ncread(inFile, xName);
y  = ncread(inFile, yName);
t  = ncread(inFile, tName);
if numel(t) ~= nt, error('time length mismatch'); end

% Pull data var attributes (to replicate)
vAttrs = struct('Name',{},'Value',{});
try
    vInfo = ncinfo(inFile, varName);
    vAttrs = vInfo.Attributes;
catch
end

% Determine nodata for output from input attributes (default 65535)
nodata_uint16 = uint16(65535);
for a = 1:numel(vAttrs)
    if strcmp(vAttrs(a).Name, '_FillValue')
        nodata_uint16 = uint16(vAttrs(a).Value);
    end
end

%% 2 Create output file
if exist(outFile,'file'), delete(outFile); end

% Coords first (single like your file); use netcdf4 for compression
nccreate(outFile, xName, 'Dimensions', {xName numel(x)}, 'Datatype', 'single', 'Format', 'netcdf4');
nccreate(outFile, yName, 'Dimensions', {yName numel(y)}, 'Datatype', 'single');
nccreate(outFile, tName, 'Dimensions', {tName numel(t)}, 'Datatype', class(t));

ncwrite(outFile, xName, single(x));
ncwrite(outFile, yName, single(y));
ncwrite(outFile, tName, t);

% Copy coord attrs (best effort)
copyVarAttrs(inFile, xName, outFile, xName);
copyVarAttrs(inFile, yName, outFile, yName);
copyVarAttrs(inFile, tName, outFile, tName);

% Copy globals
copyGlobalAttrs(inFile, outFile);

% Data var: SAME NAME
if keepUInt16
    outType = 'uint16';
else
    outType = 'single';
end

nccreate(outFile, varName, ...
    'Dimensions', {xName nx, yName ny, tName nt}, ...
    'Datatype', outType, ...
    'ChunkSize', chunkXY, ...
    'DeflateLevel', deflate, ...
    'Shuffle', shuffle);

% Copy data var attributes, then adjust _FillValue/missing_value appropriately
copyVarAttrs(inFile, varName, outFile, varName);

if keepUInt16
    % Ensure uint16 nodata attributes
    try 
        ncwriteatt(outFile, varName, '_FillValue', nodata_uint16);
    end
    try 
        ncwriteatt(outFile, varName, 'missing_value', nodata_uint16);
    end
else
    % Switch to NaN-based nodata for single
    try 
        ncwriteatt(outFile, varName, '_FillValue', single(NaN));
    end
    try 
        ncwriteatt(outFile, varName, 'missing_value', single(NaN));
    end
end
% Add history
try
    ncwriteatt(outFile, varName, 'history', [datestr(now,'yyyy-mm-dd HH:MM:SS') ' gaussian smoothing']);
end

fprintf('Processing %s: %dx%dx%d -> %s (%s)\n', varName, nx, ny, nt, outFile, outType);

%% 3 Loop over full year
start = [1 1 1];
count = [nx ny 1];

for k = 1:nt
    if k==1 || k==nt || mod(k,10)==0
        fprintf('  Day %d/%d\n', k, nt);
    end
    start(3) = k;

    % Read one slice (uint16)
    A_u16 = ncread(inFile, varName, start, count);

    % Build a NaN mask + convert to single for filtering
    mask_valid = (A_u16 ~= nodata_uint16);
    A = single(A_u16);
    A(~mask_valid) = NaN;  % turn nodata into NaN

    % Apply gauss filter
    F = imgaussfilt_nan(A,sigma_pixels);  % same as default imgaussfilt with added nan awareness

    % Enforce original nodata locations to remain NaN
    F(~mask_valid) = NaN;

    % Write back in requested dtype
    if keepUInt16
        % Replace NaN with nodata_uint16; clip to [0, 65534] before cast; round
        Fw = F;
        Fw(isnan(Fw)) = -inf;  % will become nodata after next step
        Fw = round(Fw);
        Fw(Fw < 0)   = 0;
        Fw(Fw > 65534) = 65534;
        outSlice = uint16(Fw);
        outSlice(~mask_valid) = nodata_uint16;  % restore nodata code
    else
        outSlice = single(F);  % keep NaNs
    end

    ncwrite(outFile, varName, outSlice, start);
end

fprintf('Done. Output: %s\n', outFile);

end

%% Helper functions
function copyVarAttrs(inFile, inVar, outFile, outVar)
    try
        info = ncinfo(inFile, inVar);
        for a = 1:numel(info.Attributes)
            att = info.Attributes(a);
            % overwrite FillValue/missing_value later as needed
            if strcmp(att.Name,'history')  % append later
                continue
            end
            try
                ncwriteatt(outFile, outVar, att.Name, att.Value);
            catch
                % skip weird attr types
            end
        end
    catch
    end
end

function copyGlobalAttrs(inFile, outFile)
    try
        info = ncinfo(inFile);
        for a = 1:numel(info.Attributes)
            att = info.Attributes(a);
            try ncwriteatt(outFile, '/', att.Name, att.Value); catch, end
        end
    catch
    end
end