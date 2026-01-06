function scaleMap = precipScaleAlg( B, gamma, fmin, fmax, thresh )

    %% MANUAL - CoReSSD Precip Scaling Algorithm
    % Jack Dechow UNC Chapel Hill August 2025
    % This algorithm computes the scaling factor for the CoReSSD dataset.
    % The LIS Open Loop prior which is the base of the CoReSSD dataset was
    % run at 1 km grid spacing. In general, the OL Prior has the correct
    % total mass of snow in an area, but the spatial distribution is not
    % great. This algorithm computes the empirical CDF of remotely sensed
    % Snow Cover Fraction (SCF) and assigns a a percentile rank to any
    % pixel/cell in domain. All pixels in a domain are assigned a scaling
    % value between [$fmin $fmax]. Input $gamma (γ) is an optional secondary
    % scaling parameter for the CDF. It changes the percentile-scaling
    % relationship from linear to non-linear. The scaling function relies
    % on computed array B_cdf, which is computed with sub-function
    % compute_rank_cdf(). The scaling function is presented below:
    %
    % FUNCTION
    % =================
    % scaleMap = fmin + (fmax - fmin) * B_cdf^gamma
    %
    % PARAMETERS
    % =================
    %
    % B: [x y] array of meanSCF values for domain
    %      -> i.e. for [x y t] array grid size [x y] over t = 365 days
    %      -> compute arithmatic mean over 365 days for any pixel [i j]
    % gamma: optional secondary scaling parameter to move relationship from
    %        linear to non-linear
    % fmax: max value for scaling algorithm
    %      -> default value $fmax = 2
    % fmin: minimum value for scaling algorithm
    %      -> default value $fmin = 0
    % B_cdf: [x y] array of ranked CDF percentile values of mean pixel SCF
    %      -> this array is computed with compute_rank_cdf()
    %      -> valid value range [0 1]

    %% METHOD - precipScaleAlg()

    % 1. Compute Ranked CDF of pixel mean SCF values
        B_cdf = compute_rank_cdf(B, thresh);

    % 2. Compute scaling value array
        scaleMap = single( fmin + (fmax - fmin) * (B_cdf .^ gamma) );

end