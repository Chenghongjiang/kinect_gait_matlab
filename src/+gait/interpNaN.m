function y = interpNaN(x)
%interpNaN Linear-interpolate NaN gaps, clamping exterior NaNs to edge values.
% Interior NaNs are filled by linear interpolation between neighbouring good
% points; exterior NaNs (before the first / after the last good point) are
% clamped to the nearest edge value (no extrapolation). A single good point
% fills the whole vector with that value.
% This must leave NO NaN/Inf behind, otherwise downstream filtfilt fails.
 x = double(x(:));          % force column vector
 n = numel(x);
 if ~any(isnan(x))
 y = x;
 return;
 end
 idx = (1:n)';
 good = ~isnan(x);
 xp = idx(good);
 yp = x(good);
 y = x;
 y(~good) = interp1(xp, yp, idx(~good), 'linear', 'extrap');  % interior + linear extrap
 % clamp exterior points to edge values (no linear extrapolation)
 lo = xp(1);
 hi = xp(end);
 y(idx < lo) = yp(1);
 y(idx > hi) = yp(end);
 % defensive: any residual non-finite (e.g. 0 good points) -> 0
 bad = ~isfinite(y);
 if any(bad), y(bad) = 0; end
end
