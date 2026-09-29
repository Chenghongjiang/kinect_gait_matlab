function seg = segmentTUG(data, cutoff, order, standFrac, minStride)
%segmentTUG Automatic Timed-Up-and-Go segmentation: stand-up / walk / turn / sit.
% i_stand, i_sit : first/last frame of the upright (straight-walk) span
% turn_lo, turn_hi : turn window (inclusive); equals [i_stand, i_sit] if no turn
% walk_mask : (N,1) logical, straight-walk (upright & not turning)
%
% Stand-up / sit-down use the vertical SpineBase VELOCITY confirmed by the
% HIP flexion angle (trunk-thigh): the onset is a sustained velocity
% excursion above 3x the seated noise floor, the rise ends when velocity
% returns to zero AND the hip is extended, the descent starts when the hip
% flexes; the stand-up boundary is refined to the first-step onset from
% ankle POSITION. The turn combines the shoulder-width trunk-rotation onset
% with the pelvis travel-heading end (see detectTurn).
 if nargin < 2, cutoff = 5.0; end
 if nargin < 3, order = 4; end
 if nargin < 4, standFrac = 0.5; end
 if nargin < 5, minStride = 0.7; end

 pre = gait.preprocessJoints(data, cutoff, order);
 fs = data.fs; N = data.N;
 y = pre.joints.SpineBase.Y;

 % comF does not depend on i_stand, so the turn-around peak is available
 % BEFORE stand/sit detection (it bounds the rise/descent search windows).
 [f, ~, com0] = gait.buildSubjectFrame(pre);
 comF = comForward(pre, f, com0);
 [~, pk_turn] = max(comF);

 % ankle forward POSITION vs its seated baseline (camera Z): flat while
 % seated, monotone jump at the first step -> used for the step onset.
 % (velocity/acceleration are NOT used for the feet: at 30 fps the double
 % derivative raises ankle noise to ~0.5 m/s and ~7 m/s^2 - worse than the
 % real signal; position noise is only ~2 cm.)
 zL = pre.joints.AnkleLeft.Z;
 zR = pre.joints.AnkleRight.Z;

 % hip flexion angle (deg): 0 ~ standing straight, ~90-100 ~ seated
 [hipDeg, yf] = hipFlexion(pre, fs);

 [i_stand, i_sit, y_thr] = detectStandSit(y, yf, hipDeg, zL, zR, fs, pk_turn, standFrac);
 flV = footVertical(pre, 'FootLeft', com0);
 frV = footVertical(pre, 'FootRight', com0);
 hsL = gait.detectHeelStrikes(flV, fs, minStride);
 hsR = gait.detectHeelStrikes(frV, fs, minStride);
 hsL = hsL(hsL >= i_stand & hsL <= i_sit);
 hsR = hsR(hsR >= i_stand & hsR <= i_sit);

 % Turn: TRAVEL-HEADING reversal of the CoM horizontal (pelvis) trajectory,
 % which rotates ~180 deg at the turnaround. Body-orientation signals
 % (shoulder X distance / trunk yaw) are unreliable with one RGB-D sensor
 % because left/right joint labels flip when the back is turned; heading
 % uses no left/right labels. Fallback: shoulder-width collapse, then
 % heel-strike bracketing.
 dX = abs(pre.joints.ShoulderLeft.X - pre.joints.ShoulderRight.X);
 [turn_lo, turn_hi, T] = detectTurn(dX, pre.joints.SpineBase.X, ...
   pre.joints.SpineBase.Z, pk_turn, i_stand, i_sit, fs, hsL, hsR);

 walk_mask = true(N, 1);
 walk_mask(1:i_stand - 1) = false;
 walk_mask(i_sit + 1:end) = false;
 walk_mask(turn_lo:turn_hi) = false;

 seg = struct('i_stand', i_stand, 'i_sit', i_sit, ...
 'turn_lo', turn_lo, 'turn_hi', turn_hi, ...
 'walk_mask', walk_mask, 'y_thr', y_thr, ...
 'comF', comF, 'comF_peak', pk_turn, ...
 'turn_heading', T.head, 'turn_heading_rel', T.headRel, ...
 'turn_speed', T.speed, 'turn_h_out', T.hOut, 'turn_h_back', T.hBack, ...
 'turn_method', T.method, 'turn_dX', dX);
end

% -------------------------------------------------------------------------
function [turn_lo, turn_hi, T] = detectTurn(dX, cx, cz, pk, i_stand, i_sit, fs, hsL, hsR)
%detectTurn Turn window: trunk-rotation onset + travel-heading end.
% The trunk starts rotating before the travel path bends, so the two edges
% use different physical signals:
%   turn_lo : sustained drop of the shoulder L-R X distance below 80 % of
%             its upright baseline - the onset of trunk rotation (the
%             paper's turning signal; robust to single-sensor label flips,
%             which affect the sign but not the collapse);
%   turn_hi : first frame after the CoM peak whose pelvis TRAVEL HEADING is
%             within 30 deg of the walk-back median while horizontal speed
%             exceeds 0.2 m/s - straight walking has clearly resumed (the
%             shoulder width often stays reduced while "turning while
%             walking", so it cannot mark the end).
% The heading reversal must exceed 120 deg to be accepted. Fallbacks:
% heading-only onset, first heel-strike end, heel-strike brackets, whole walk.
 head = travelHeading(cx, cz, fs);
 spd  = headingSpeed(cx, cz, fs);
 g1 = round(1.5 * fs); g2 = round(1.0 * fs);
 rOut  = i_stand:max(i_stand, pk - g1);
 rBack = min(i_sit, pk + g2):i_sit;
 hOut  = median(head(rOut));
 hBack = median(head(rBack));
 T = struct('head', head, 'headRel', unwrap(head - hOut), 'speed', spd, ...
            'hOut', hOut, 'hBack', hBack, 'method', 'shoulder+heading');

 angOn = 30*pi/180; spdOn = 0.2;
 holdF = max(5, round(0.17 * fs));
 headingOK = abs(wrapPi(hBack - hOut)) > 120*pi/180;

 % --- turn_lo: trunk-rotation onset (shoulder-width collapse) ------------
 base = median(dX(i_stand:pk));
 thr = 0.80 * base;
 holdS = max(3, round(0.10 * fs));
 b = min(numel(dX), pk + round(0.5 * fs));
 turn_lo = [];
 s = findRun(dX(i_stand:b) < thr, holdS);
 if ~isempty(s)
   s = i_stand + s - 1;
   e = find(dX(i_stand:s) >= thr, 1, 'last');
   if ~isempty(e), turn_lo = i_stand + e - 1; end
 end
 if isempty(turn_lo) && headingOK  % heading-onset fallback
   k = find(abs(wrapPi(head(i_stand:pk) - hOut)) > angOn, 1, 'last');
   if ~isempty(k), turn_lo = i_stand + k - 1; T.method = 'heading'; end
 end

 % --- turn_hi: heading settled on the walk-back direction ----------------
 turn_hi = [];
 if headingOK
   n = pk:i_sit;
   settled = abs(wrapPi(head(n) - hBack)) < angOn & spd(n) > spdOn;
   k = findRun(settled, holdF);
   if ~isempty(k), turn_hi = pk + k - 1; end
 end
 if isempty(turn_hi)  % first heel-strike after the peak
   hsAfter = sort([hsL(hsL > pk); hsR(hsR > pk)]);
   if ~isempty(hsAfter), turn_hi = hsAfter(1); end
   if ~isempty(turn_lo) && headingOK, T.method = 'shoulder+heelstrike'; end
 end

 % --- last-resort: heel-strike brackets, then the whole walk -------------
 if isempty(turn_lo) || isempty(turn_hi) || turn_hi <= turn_lo
   T.method = 'heelstrike';
   lb = sort([hsL(hsL < pk); hsR(hsR < pk)]);
   fa = sort([hsL(hsL > pk); hsR(hsR > pk)]);
   if isempty(turn_lo)
     if isempty(lb), turn_lo = i_stand; else turn_lo = lb(end); end
   end
   if isempty(turn_hi) || turn_hi <= turn_lo
     if isempty(fa), turn_hi = i_sit; else turn_hi = fa(1); end
   end
 end
 if turn_hi <= turn_lo
   T.method = 'whole_walk';
   turn_lo = i_stand; turn_hi = i_sit;
 end
end

% -------------------------------------------------------------------------
function head = travelHeading(cx, cz, fs)
%travelHeading Smoothed travel direction atan2(vx, vz) of a horizontal path.
% 3 Hz low-pass (positions are already 5 Hz smoothed); the angle is averaged
% circularly so pivot frames with near-zero velocity do not cause wraps.
 [b, a] = butter(3, 3 / (fs / 2));
 x = filtfilt(b, a, cx(:)); z = filtfilt(b, a, cz(:));
 vx = gradient(x) * fs; vz = gradient(z) * fs;
 hs = filtfilt(b, a, sin(atan2(vx, vz)));
 hc = filtfilt(b, a, cos(atan2(vx, vz)));
 head = unwrap(atan2(hs, hc));
end

function spd = headingSpeed(cx, cz, fs)
 [b, a] = butter(3, 3 / (fs / 2));
 x = filtfilt(b, a, cx(:)); z = filtfilt(b, a, cz(:));
 spd = sqrt((gradient(x)*fs).^2 + (gradient(z)*fs).^2);
end

% -------------------------------------------------------------------------
function a = wrapPi(a)
%wrapPi Wrap angle(s) to (-pi, pi] without the Mapping Toolbox.
 a = mod(a + pi, 2*pi) - pi;
end

% -------------------------------------------------------------------------
function i = findRun(tf, k)
%findRun First index where tf stays true for >= k consecutive samples.
 i = []; n = numel(tf);
 if n < k, return; end
 c = conv(double(tf(:)'), ones(1, k), 'valid');  % c(s) = sum(tf(s:s+k-1))
 s = find(c >= k, 1, 'first');
 if isempty(s), return; end
 back = find(~tf(1:s), 1, 'last');
 if isempty(back), i = 1; else i = back + 1; end
end

% -------------------------------------------------------------------------
function [i_stand, i_sit, y_thr] = detectStandSit(y, yf, hipDeg, zL, zR, fs, pk_turn, standFrac)
%detectStandSit Stand-up / sit-down instants (vertical velocity + hip angle).
%
% The boundary follows the physics of the vertical SpineBase motion:
% acceleration peaks at force onset, velocity peaks mid-movement, and the
% POSITION plateau is reached exactly when the VELOCITY RETURNS TO ZERO.
% Velocity (4 Hz low-pass) is the primary signal; the motion threshold is
% ADAPTIVE at 3x the seated-velocity RMS (3-sigma rule). The HIP FLEXION
% ANGLE (trunk-thigh, ~0 deg standing / ~90-100 deg seated) confirms the
% posture so that trunk bends without a real sit/stand cannot trigger:
%   - rise onset : first sustained vy > 3*noise (>=15 cm gain);
%   - rise end   : |vy| < 0.08 m/s AND hip extended (< 35 deg), sustained;
%   - i_stand    : first-step onset from ankle POSITION, else the rise end;
%   - sit onset  : sustained vy < -3*noise (>=15 cm drop) AND hip flexing
%                  (> 40 deg within 0.5 s), after the turn.
% Curvature knees / threshold crossing remain as fallbacks.
 N = numel(y);
 vy = gradient(yf) * fs;
 ay = gradient(vy) * fs;
 kappa = abs(ay) ./ (1 + vy.^2).^1.5; % curvature of the (t, y) curve

 % rise flank geometry (threshold kept for the overview figure / fallback)
 yPre = y(1:pk_turn);
 ymin = min(yPre); [ymax, pkY] = max(yPre);
 rng = max(ymax - ymin, eps);
 y_thr = ymin + standFrac * rng;

 % adaptive velocity thresholds from the seated-still prefix
 n0 = min(N, max(15, round(0.5 * fs)));
 sN = sqrt(mean(vy(1:n0).^2));   % seated vertical-velocity RMS
 vOn  = max(0.10, 3 * sN);       % motion-onset level (m/s)
 vEnd = 0.08;                    % "body at rest" level (m/s)
 kOn  = max(3, round(0.10 * fs));
 kEnd = max(5, round(0.17 * fs));
 hipExt = 35;                    % deg, standing hip-extension gate
 hipFlex = 40;                   % deg, sitting hip-flexion gate

 % --- rise onset: sustained upward velocity + confirmed height gain -----
 i_up0 = [];
 r = findRun(vy(n0+1:pk_turn) > vOn, kOn);
 if ~isempty(r)
   b = n0 + r;
   win = min(N, b + round(1.5 * fs));
   if max(yf(b:win)) - yf(b) >= 0.15
     i_up0 = b;
   end
 end
 if isempty(i_up0) % curvature fallback: bottom knee of the rise
   i_lo = find(y(1:pkY) <= ymin + 0.2 * rng, 1, 'last');
   if isempty(i_lo), i_lo = 1; end
   kl = i_lo:pkY; kl = kl(y(kl) < y_thr);
   if isempty(kl), i_up0 = i_lo; else [~, q] = max(kappa(kl)); i_up0 = kl(q); end
 end

 % --- rise end: velocity at rest AND hip extended (upright reached) ------
 seg = i_up0:pk_turn;
 [~, iv] = max(vy(seg)); iv = seg(iv);
 rest = abs(vy(iv:pk_turn)) < vEnd & hipDeg(iv:pk_turn) < hipExt;
 r = findRun(rest, kEnd);
 if isempty(r)
   r2 = findRun(abs(vy(iv:pk_turn)) < vEnd, kEnd);  % hip gate unavailable
   if isempty(r2), i_upEnd = pkY; else i_upEnd = iv + r2 - 1; end
 else
   i_upEnd = iv + r - 1;
 end
 i_stand = i_upEnd;

 % --- first-step onset: sustained ankle POSITION displacement -----------
 % (velocity/acceleration unusable for the feet at 30 fps - see main fcn)
 baseL = median(zL(1:i_up0)); baseR = median(zR(1:i_up0));
 dMax = max(abs(zL - baseL), abs(zR - baseR));
 dThr = 0.12;  % m, a real step displaces the ankle >> 12 cm
 dHold = 0.08; % m, must stay beyond this for nHold frames (no transient)
 dLow = 0.05;  % m, quiet-foot level for walking the onset back
 nHold = 5;    % frames (~0.17 s)
 step = find(dMax(i_up0:pk_turn) > dThr, 1, 'first');
 if ~isempty(step)
   b = i_up0 + step - 1;
   if b + nHold - 1 <= N && all(dMax(b:b+nHold-1) > dHold)
     quiet = find(dMax(i_up0:b) < dLow, 1, 'last');
     if ~isempty(quiet)
       i_stand = i_up0 + quiet - 1; % last quiet frame before the step
     end
   end
 end

 % --- sit-down onset: downward velocity + hip flexion after the turn ----
 sN2 = sqrt(mean(vy(max(1, N-n0+1):N).^2)); % seated-again noise floor
 vOn2 = max(0.10, 3 * sN2);
 i_sit = [];
 down = vy(pk_turn:N) < -vOn2;
 r = findRun(down, kOn);
 while ~isempty(r)
   b = pk_turn + r - 1;
   win = min(N, b + round(1.5 * fs));
   wHip = min(N, b + round(0.5 * fs));
   heightOK = yf(b) - min(yf(b:win)) >= 0.15;
   hipOK = max(hipDeg(b:wHip)) > hipFlex;  % trunk is actually flexing to sit
   if heightOK && hipOK
     i_sit = b; break;
   end
   nxt = findRun(down(r + kOn:end), kOn); % try the next downward excursion
   if isempty(nxt), break; end
   r = r + kOn - 1 + nxt;
 end
 if isempty(i_sit) % curvature fallback: top knee of the descending flank
   yPost = y(pk_turn:end);
   ymin2 = min(yPost); ymax2 = max(yPost);
   rng2 = max(ymax2 - ymin2, eps);
   j_hi = find(y(pk_turn:end) >= ymax2 - 0.2 * rng2, 1, 'last') + pk_turn - 1;
   j_lo_rel = find(y(j_hi:end) <= ymin2 + 0.2 * rng2, 1, 'first');
   if ~isempty(j_hi) && ~isempty(j_lo_rel)
     j_lo = j_hi + j_lo_rel - 1;
     flank = j_hi:j_lo;
     knee = flank(y(flank) >= ymin2 + standFrac * rng2);
     if ~isempty(knee), [~, q] = max(kappa(knee)); i_sit = knee(q); end
   end
 end
 if isempty(i_sit) % last-resort threshold crossing
   up = find(y > y_thr);
   if isempty(up), i_sit = N; else i_sit = up(end); end
 end
end

% -------------------------------------------------------------------------
function [hipDeg, yf] = hipFlexion(pre, fs)
%hipFlexion Trunk-thigh (hip) flexion angle in degrees, 4 Hz low-pass.
% Angle between the downward trunk vector (SpineShoulder -> SpineBase) and
% the mean thigh vector (hip -> knee); ~0 deg standing, ~90-100 deg seated.
% Also returns the 4 Hz-filtered SpineBase height for stable derivatives.
 J = pre.joints;
 [b, a] = butter(3, 4 / (fs / 2));
 tvx = J.SpineBase.X - J.SpineShoulder.X;
 tvy = J.SpineBase.Y - J.SpineShoulder.Y;
 tvz = J.SpineBase.Z - J.SpineShoulder.Z;
 qvx = (J.KneeLeft.X + J.KneeRight.X - J.HipLeft.X - J.HipRight.X) / 2;
 qvy = (J.KneeLeft.Y + J.KneeRight.Y - J.HipLeft.Y - J.HipRight.Y) / 2;
 qvz = (J.KneeLeft.Z + J.KneeRight.Z - J.HipLeft.Z - J.HipRight.Z) / 2;
 cs = tvx.*qvx + tvy.*qvy + tvz.*qvz;
 nt = sqrt(tvx.^2 + tvy.^2 + tvz.^2);
 nq = sqrt(qvx.^2 + qvy.^2 + qvz.^2);
 hipDeg = filtfilt(b, a, acosd(max(-1, min(1, cs ./ (nt .* nq)))));
 yf = filtfilt(b, a, J.SpineBase.Y);
end

% -------------------------------------------------------------------------
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
