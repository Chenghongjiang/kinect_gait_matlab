function [hs, to, relF, ankleFwd, comF, sg] = detectFootEventsForward(data, side, seg, cutoff, order, minStride, prominenceFrac)
%detectFootEventsForward Gait events from the ankle forward (depth) trajectory.
%
% Uses the ankle coordinate along the walking direction, relative to the centre
% of mass: relF = ankleFwd - comF. Heel-strike (HS, foot lands ahead of body) is
% a local MAXIMUM of relF; toe-off (TO, foot pushes off behind body) is a local
% MINIMUM. For a Timed-Up-and-Go (out-and-back) walk the sign of "ahead" flips on
% the return leg, so a direction-independent signal sg = relF .* sign(CoM forward
% velocity) is used: HS = peak of sg, TO = trough of sg.
%
% Event indices are restricted to the upright straight-walk segment (segmentTUG).
 if nargin < 3 || isempty(seg)
   % NOTE the argument slots: segmentTUG(data, cutoff, order, standFrac, minStride).
   % Passing minStride as the 4th argument would silently overwrite standFrac
   % (0.5) with 0.6 and leave minStride at its 0.7 default, so the stand-up
   % threshold and the heel-strike separation filter would both be wrong.
   seg = gait.segmentTUG(data, cutoff, order, 0.5, minStride);
 end
 if nargin < 4, cutoff = 5.0; end
 if nargin < 5, order = 4; end
 if nargin < 6, minStride = 0.6; end
 if nargin < 7, prominenceFrac = 0.04; end

 pre = gait.preprocessJoints(data, cutoff, order);
 fs = data.fs; t = data.t; N = data.N;
 [f, l, com0] = gait.buildSubjectFrame(pre);

 J = pre.joints.(side);
 p = [J.X - com0(1), J.Y - com0(2), J.Z - com0(3)];
 ankleFwd = p(:, 1) * f(1) + p(:, 3) * f(2); % ankle forward (depth) coordinate

 comF = comForward(pre, f, com0);
 relF = ankleFwd - comF;

 % direction-independent signal
 comvel = gradient(comF, 1 / fs);
 sgn = sign(movmean(comvel, max(3, round(0.3 * fs))));
 sg = relF .* sgn;

 rng = max(sg) - min(sg);
 prom = prominenceFrac * rng;
 % floor to match int(min_stride * fs) (integer floor) exactly
 dist = floor(minStride * fs);
 % returns 1-based indices (second output), matching the standard find-peaks semantics
 [~, hs] = gait.findpeaksGait(sg, dist, prom);
 [~, to] = gait.findpeaksGait(-sg, dist, prom);

 % keep only events inside the straight-walk segment (exclude stand/sit/turn)
 i_stand = seg.i_stand; i_sit = seg.i_sit;
 turn_lo = seg.turn_lo; turn_hi = seg.turn_hi;
 keep = @(idx) idx >= i_stand & idx <= i_sit & ~(idx >= turn_lo & idx <= turn_hi);
 hs = hs(keep(hs));
 to = to(keep(to));
end

function comF = comForward(pre, f, com0)
 N = pre.N;
 com = zeros(N, 3); cnt = 0;
 for j = {'SpineBase', 'HipLeft', 'HipRight'}
 if isfield(pre.joints, j{1})
 com(:, 1) = com(:, 1) + pre.joints.(j{1}).X;
 com(:, 2) = com(:, 2) + pre.joints.(j{1}).Y;
 com(:, 3) = com(:, 3) + pre.joints.(j{1}).Z;
 cnt = cnt + 1;
 end
 end
 com = com / cnt;
 comF = (com(:, 1) - com0(1)) * f(1) + (com(:, 3) - com0(3)) * f(2);
end
