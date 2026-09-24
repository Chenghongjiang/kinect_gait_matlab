function [pks, locs] = findpeaksGait(x, dist, prom)
%findpeaksGait Self-contained peak detection (local maxima, distance, prominence).
%
% Implements the standard find-peaks pipeline from scratch so that no Signal
% Processing Toolbox is required:
%   1. local maxima      - plateau reported at its middle sample
%   2. distance filter   - a peak is dropped only when its distance to an
%                          already-kept, taller peak is STRICTLY less than dist
%   3. prominence filter - walk outwards until a higher sample; prominence =
%                          peak height minus the higher of the two running minima
%
% The distance test uses strict-less-than (|delta| < dist) so that a peak
% exactly dist samples away survives - this differs from MATLAB's built-in
% findpeaks, which drops it, and was confirmed to affect heel-strike counts
% on real TUG trials.
%
% Input
%   x    : (N,1) signal
%   dist : minimum peak separation in samples
%   prom : minimum prominence, absolute units
% Output
%   pks  : peak values   (x(locs))
%   locs : peak indices, 1-based, ascending

 x = x(:);
 n = numel(x);
 pks = []; locs = [];
 if n < 2, return; end

 % ---------------- 1. local maxima ----------------
 % A plateau is reported at its middle sample.
 cand = zeros(n, 1);
 m = 0;
 i = 2;
 while i <= n - 1
   if x(i - 1) < x(i)
     ia = i + 1;
     while ia <= n && x(i) == x(ia)
       ia = ia + 1;
     end
     if ia <= n && x(i) > x(ia)
       m = m + 1;
       cand(m) = floor((i + (ia - 1)) / 2);
       i = ia;
     elseif ia > n
       break;
     else
       i = ia;
     end
   else
     i = i + 1;
   end
 end
 if n > 1 && x(n - 1) < x(n)
   if m == 0 || cand(m) ~= n
     m = m + 1; cand(m) = n;
   end
 end
 cand = cand(1:m);
 if isempty(cand), return; end

 % ---------------- 2. distance filter ----------------
 % Peaks are resolved by height priority; a peak is dropped only when its
 % distance to an already-kept, taller peak is strictly less than dist.
 if nargin >= 2 && ~isempty(dist) && dist > 0 && numel(cand) > 1
   prio = x(cand);
   [~, ord] = sort(prio, 'ascend');      % stable: ties -> lower index first
   ord = flipud(ord(:));                 % decreasing height; ties -> higher index first
   keepD = true(numel(cand), 1);
   for t = 1:numel(ord)
     j = ord(t);
     if ~keepD(j), continue; end
     lo = cand(j) - dist;
     hi = cand(j) + dist;
     % A neighbour is removed only when its distance is STRICTLY less than
     % dist (|delta| < dist); a neighbour exactly dist away survives.
     k = j - 1;
     while k >= 1 && cand(k) > lo
       keepD(k) = false; k = k - 1;
     end
     k = j + 1;
     while k <= numel(cand) && cand(k) < hi
       keepD(k) = false; k = k + 1;
     end
   end
   cand = cand(keepD);
 end
 if isempty(cand), return; end

 % ---------------- 3. prominence -----------------
 % Walk outwards from the peak, tracking the running minimum, and stop at the
 % FIRST strictly higher sample. prominence = x(peak) - max(leftMin, rightMin).
 pr = zeros(numel(cand), 1);
 for k = 1:numel(cand)
   p = cand(k); xp = x(p);
   lm = xp; i = p;
   while i > 1
     i = i - 1;
     if x(i) > xp, break; end
     if x(i) < lm, lm = x(i); end
   end
   rm = xp; i = p;
   while i < n
     i = i + 1;
     if x(i) > xp, break; end
     if x(i) < rm, rm = x(i); end
   end
   pr(k) = xp - max(lm, rm);
 end

 if nargin >= 3 && ~isempty(prom)
   keepP = pr >= prom;
   cand = cand(keepP);
 end
 locs = cand;
 pks = x(locs);
end
