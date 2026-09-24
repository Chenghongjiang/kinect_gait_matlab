function seg = segmentTUG(data, cutoff, order, standFrac, minStride)
%segmentTUG Automatic Timed-Up-and-Go segmentation: stand-up / walk / turn / sit.
% i_stand, i_sit : first/last frame of the upright (straight-walk) span
% turn_lo, turn_hi : turn window (inclusive); equals [i_stand, i_sit] if no turn
% walk_mask : (N,1) logical, straight-walk (upright & not turning)
%
% Stand/sit uses SpineBase_Y crossing a sit->stand threshold; the turn window is
% the CoM forward-displacement peak bracketed by the left/right last/first
% heel-strikes (a single TUG has one turn).
 if nargin < 2, cutoff = 5.0; end
 if nargin < 3, order = 4; end
 if nargin < 4, standFrac = 0.5; end
 if nargin < 5, minStride = 0.7; end

 pre = gait.preprocessJoints(data, cutoff, order);
 fs = data.fs; t = data.t; N = data.N;
 y = pre.joints.SpineBase.Y;
 ymin = min(y); ymax = max(y);
 y_thr = ymin + standFrac * (ymax - ymin);
 up = find(y > y_thr);
 if isempty(up)
 i_stand = 1; i_sit = N;
 else
 i_stand = up(1); i_sit = up(end);
 end

 [f, l, com0] = gait.buildSubjectFrame(pre);
 comF = comForward(pre, f, com0);
 flV = footVertical(pre, 'FootLeft', com0);
 frV = footVertical(pre, 'FootRight', com0);
 hsL = gait.detectHeelStrikes(flV, fs, minStride);
 hsR = gait.detectHeelStrikes(frV, fs, minStride);
 hsL = hsL(hsL >= i_stand & hsL <= i_sit);
 hsR = hsR(hsR >= i_stand & hsR <= i_sit);

 seg_c = comF(i_stand:i_sit);
 [~, pkrel] = max(seg_c);
 pk = i_stand + pkrel - 1;
 lb = [hsL(hsL < pk); hsR(hsR < pk)];
 fa = [hsL(hsL > pk); hsR(hsR > pk)];
 if isempty(lb), turn_lo = i_stand; else turn_lo = max(lb); end
 if isempty(fa), turn_hi = i_sit; else turn_hi = min(fa); end
 if turn_hi <= turn_lo
 turn_lo = i_stand; turn_hi = i_sit; % no clear turn -> keep whole walk
 end

 walk_mask = true(N, 1);
 walk_mask(1:i_stand - 1) = false;
 walk_mask(i_sit + 1:end) = false;
 walk_mask(turn_lo:turn_hi) = false;

 seg = struct('i_stand', i_stand, 'i_sit', i_sit, ...
 'turn_lo', turn_lo, 'turn_hi', turn_hi, ...
 'walk_mask', walk_mask, 'y_thr', y_thr, ...
 'comF', comF, 'comF_peak', pk);
end

% CoM forward displacement (subject frame)
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

% Foot vertical coordinate (subject frame) = Y relative to initial CoM
function v = footVertical(pre, name, com0)
 v = pre.joints.(name).Y - com0(2);
end
