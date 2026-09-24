function hs = detectHeelStrikes(footV, fs, minStride, prominenceFrac)
%detectHeelStrikes Heel-strike = local minimum of the foot vertical trajectory.
% footV : (N,1) foot vertical coordinate (subject frame). Returns 1-based indices.
 if nargin < 3, minStride = 0.6; end
 if nargin < 4, prominenceFrac = 0.04; end
 rng = max(footV) - min(footV);
 prom = prominenceFrac * rng;
 % floor (not round) to match int(min_stride * fs) (integer floor) exactly; they differ
 % whenever min_stride * fs is not an integer (e.g. 0.55 * 30 = 16.5 -> 16 vs 17).
 dist = floor(minStride * fs);
 % returns 1-based indices (second output), matching the standard find-peaks semantics
 [~, hs] = gait.findpeaksGait(-footV, dist, prom);
end
