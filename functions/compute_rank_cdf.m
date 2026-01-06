function B_cdf = compute_rank_cdf(B, threshold)
     %% MANUAL - Compute Empirical (Ranked) CDF
     % This function computes the empirical (ranked percentile) cumulative
     % distribution function (CDF) of snow cover fraction (SCF) data used in
     % the CoReSSD precipitation scaling algorithm. This is a sub-function and
     % is called directly in the precip scaling algorithm function 
     % precipScaleAlg(). This function includes an optional flag
     % $threshold which sets a minimum value to include in the ranked CDF.
     % If no input for $threshold is supplied, the function defaults to
     % $threshold = 0. This ranks all positive finite values. The SCF
     % values input are the MEAN SCF of a pixel over the course of an
     % entire year. 
     %
     % PARAMETERS
     % =================
     %
     % B: [x y] array of meanSCF values for domain
     %      -> i.e. for [x y t] array grid size [x y] over t = 365 days
     %      -> compute arithmatic mean over 365 days for any pixel [i j]
     % threshold: minimum value to filter valid meanSCF values
     %      -> default value $threshold = 0


    %% METHOD - compute_rank_cdf()

    % % 1. Check for missing/error inputs
    
    % 1.1 if no input, rank all finite positive values
    if nargin < 2
        threshold = 0;  
    end

    % 1.2  Break if threshold set incorrectly
    if threshold >= 1
        disp('Error! Threshold value set too high; Must be < 1 (default = 0')
        return
    end

    % % 2. Manipulate Arrays 

    % 2.1 Flatten array to column vector and get non-finite value indices
    B_flat = B(:);
    is_valid = isfinite(B_flat) & B_flat >= threshold;

    % 2.2 Remove invalid indices and sort
    B_valid = B_flat(is_valid);
    [~, sortIdx] = sort(B_valid);

    % 2.3 Sort all valid values
    ranks = zeros(size(B_valid));
    ranks(sortIdx) = linspace(0, 1, numel(B_valid));

    % 2.4 Recreate original coln vector with nan in place of invalid idx
    B_cdf_flat = nan(size(B_flat));

    % 2.5 Insert ranked valid values into new coln vector
    B_cdf_flat(is_valid) = ranks;

    % % 3 Reshape to match original shape
    B_cdf = reshape(B_cdf_flat, size(B));
    
end