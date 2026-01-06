function B = imgaussfilt_nan(A, sigma)
    % Handle NaN values in Gaussian filtering

    % Replace NaNs with 0
    A0 = A;
    A0(isnan(A0)) = 0;

    % Valid data mask
    M = double(~isnan(A));

    % Apply Gaussian filter to data and mask
    As = imgaussfilt(A0, sigma);
    Ms = imgaussfilt(M, sigma);

    % Normalize
    B = As ./ Ms;

    % Put NaNs back where input was all NaN (to avoid Inf)
    B(Ms==0) = NaN;
end
