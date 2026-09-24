function pts = extractCyclePoints(data, cutoff, order, minStride, prominenceFrac)
%extractCyclePoints Pick the best OUTBOUND gait cycle and its 6 key points.
%
% For the selected cycle, the left and right ankles each contribute 3 points:
% HS (heel-strike / landing), TO (toe-off / lift-off),
% HS2 (next heel-strike of the same foot).
% The 6 points (time, forward-Z) drive computeParamsFromPoints.
%
% IMPORTANT - the 6 points span ~1.5 strides, not one:
% Each foot's triple is measured on that foot's OWN stride, and the L and R
% strides are phase-shifted by half a cycle. Left points live in
% [L.HS, L.HS2], right points in [R.HS, R.HS2] (which starts later and ends
% later). This is required: a single stride window contains only 5 event
% boundaries (L.HS, R.TO_prev, R.HS, L.TO, L.HS2), never a full HS/TO/HS2
% triple for both feet. Per-limb parameters (stride time/length, swing
% velocity) legitimately need each foot's own stride.
%
% Support-phase parameters, in contrast, MUST come from ONE cycle. The
% interleaved event that ends the initial double support is therefore stored
% separately as pts.R.TO_prev - it is NOT pts.R.TO.
%
% CYCLE-SELECTION RULE (single rule, no alternatives):
% the analysed cycle is always taken on the walking-out leg (去程) of the TUG
% (walk out -> turn -> walk back). The walk_out segment is [i_stand, turn_lo]:
% from stand-up complete to the turn start. A candidate is therefore kept only
% when BOTH its start and end lie inside [i_stand, turn_lo] (fully within the
% 去程 straight walk). Among those outbound candidates the best one is picked by
%     score = 2 * (steady location) + (physiological plausibility)
% which keeps the cycle away from the stand-up acceleration, the turn and the
% sit-down braking, and penalises left/right asymmetry and implausible stride
% times. This is the rule used for the manuscript's results.
%
% pts.outbound_ok is false when a trial has NO outbound candidate at all (very
% short walk); the pool then falls back to the whole straight walk so that a
% cycle is still reported.
%
% Returns a struct with L/R.{HS,TO,HS2} = [frame, time_s, forwardZ_m], plus
% window, seg, ankleFwdL/R, relL/R, comF, t, outbound_ok and candidates
% (score / location / physiology of every outbound candidate).

 if nargin < 2, cutoff = 5.0; end
 if nargin < 3, order = 4; end
 if nargin < 4, minStride = 0.6; end
 if nargin < 5, prominenceFrac = 0.04; end

 fs = data.fs; t = data.t;
 % NOTE: segmentTUG signature is (data, cutoff, order, standFrac, minStride).
 % Pass standFrac explicitly (0.5, matches the default) so
 % minStride is not silently shifted into the standFrac slot.
 seg = gait.segmentTUG(data, cutoff, order, 0.5, minStride);
 i_stand = seg.i_stand; i_sit = seg.i_sit;
 turn_lo = seg.turn_lo; turn_hi = seg.turn_hi;

 % NOTE: capture `toL`/`toR` (the full toe-off sequences) here - they are
 % needed later to build pts.toL_all / pts.toR_all (used by stancePhases and
 % the events table). The original code discarded them with `~` and then
 % referenced the undefined variables, which crashed at runtime.
 [hsL, toL, relL, aFL, comF, sgL] = gait.detectFootEventsForward(data, 'AnkleLeft', seg, cutoff, order, minStride, prominenceFrac);
 [hsR, toR, relR, aFR, ~, sgR] = gait.detectFootEventsForward(data, 'AnkleRight', seg, cutoff, order, minStride, prominenceFrac);
 if numel(hsL) < 2, pts = []; return; end

 tug_time = data.N / fs;

 % candidate left-foot cycles [hsL(i), hsL(i+1)] with a right HS inside
 cand = {};
 for i = 1:numel(hsL) - 1
 a = hsL(i); b = hsL(i + 1);
 st = t(b) - t(a);
 if ~(st >= 0.5 && st <= 1.8), continue; end
 if (a >= turn_lo && a <= turn_hi) || (b >= turn_lo && b <= turn_hi), continue; end
 hsR_in = hsR(hsR > a & hsR < b);
 if isempty(hsR_in), continue; end
 r1 = hsR_in(1);
 r2_list = hsR(hsR > r1);
 if isempty(r2_list), continue; end
 r2 = r2_list(1);
 cand{end + 1} = {i, a, b, st, r1, r2};
 end
 if isempty(cand), pts = []; return; end

 candidates = {};

 buildPts = @(a, b, r1, r2) buildPoints(a, b, r1, r2, t, aFL, aFR, sgL, sgR, toR);

 % ---- keep only candidates fully inside the walk_out (去程) segment ----
 % The TUG walk-out leg spans [i_stand, turn_lo]: from stand-up complete to
 % the turn start. A candidate is kept only when BOTH its start and end lie
 % inside this segment, so the analysed cycle always comes from the 去程
 % (outbound straight walk), never from the return leg or the stand-up push.
 outboundOK = true;
 pool = {};
 for m = 1:numel(cand)
 a = cand{m}{2}; b = cand{m}{3};
 if a >= i_stand && b <= turn_lo, pool{end + 1} = cand{m}; end
 end
 if isempty(pool)
 outboundOK = false; % no outbound cycle -> fall back to the whole straight walk
 pool = cand;
 end

 % ---- best outbound cycle: steady location + physiological plausibility ----
 bestC = pool{1}; bestV = -inf;
 for k = 1:numel(pool)
 c = pool{k};
 a = c{2}; b = c{3}; r1 = c{5}; r2 = c{6};
 P = gait.computeParamsFromPoints(buildPts(a, b, r1, r2), tug_time);
 loc = locScoreFcn(c, i_stand, i_sit, turn_lo, turn_hi);
 phys = physioScore(P);
 score = 2.0 * loc + phys;
 candidates(end + 1, :) = {round(score, 3), round(loc, 3), round(phys, 3), a, b};
 if score > bestV, bestV = score; bestC = c; end
 end

 a = bestC{2}; b = bestC{3}; r1 = bestC{5}; r2 = bestC{6};

 P = buildPts(a, b, r1, r2);
 pts = P;
 pts.t = t;
 pts.seg = seg;
 pts.ankleFwdL = aFL; pts.ankleFwdR = aFR;
 pts.relL = relL; pts.relR = relR;
 pts.comF = comF;
 % (/)
 pts.hsL_all = hsL; pts.toL_all = toL;
 pts.hsR_all = hsR; pts.toR_all = toR;
 pts.outbound_ok = outboundOK;
 if ~isempty(candidates), pts.candidates = candidates; end
end

% -------------------------------------------------------------------------
function P = buildPoints(a, b, r1, r2, t, aFL, aFR, sgL, sgR, toR_all)
 % Left 3 points; TO = global minimum of sg within the step window (= true lift-off)
 toL = a - 1 + find(sgL(a:b) == min(sgL(a:b)), 1);
 tL1 = t(a); zL1 = aFL(a);
 tL3 = t(b); zL3 = aFL(b);
 tL2 = t(toL); zL2 = aFL(toL);
 % Right 3 points
 toR = r1 - 1 + find(sgR(r1:r2) == min(sgR(r1:r2)), 1);
 tR1 = t(r1); zR1 = aFR(r1);
 tR2 = t(toR); zR2 = aFR(toR);
 tR3 = t(r2); zR3 = aFR(r2);

 % R.TO_prev = the right-foot toe-off that ends THIS cycle's initial double
 % support: the first right TO in [L.HS, R.HS). It is a DIFFERENT event from
 % R.TO above (which is the right foot's own lift-off in [R.HS, R.HS2], one
 % half-step later). Support-phase metrics must use TO_prev, not TO.
 toR_prev = a;
 if nargin >= 10 && ~isempty(toR_all)
   in = toR_all(toR_all >= a & toR_all < r1);
   if ~isempty(in), toR_prev = in(1); end
 end

 P.L.HS = [a, tL1, zL1];
 P.L.TO = [toL, tL2, zL2];
 P.L.HS2 = [b, tL3, zL3];
 P.R.HS = [r1, tR1, zR1];
 P.R.TO = [toR, tR2, zR2];
 P.R.HS2 = [r2, tR3, zR3];
 P.R.TO_prev = [toR_prev, t(toR_prev), aFR(toR_prev)];
 P.window = [a, b];
end

function s = locScoreFcn(c, i_stand, i_sit, turn_lo, turn_hi)
 m = (c{2} + c{3}) / 2;
 d_stand = m - i_stand;
 d_sit = i_sit - m;
 if m < turn_lo
   d_turn = turn_lo - m;
 elseif m > turn_hi
   d_turn = m - turn_hi;
 else
   d_turn = 0;
 end
 walk_span = max(1, i_sit - i_stand);
 s = min(d_stand, min(d_sit, d_turn)) / (0.5 * walk_span);
end

function sc = physioScore(P)
 cycle = P.Stride_time;
 asym = abs(P.stride_time_L - P.stride_time_R);
 asym_frac = asym / cycle;
 ds_dev = abs(P.Double_support_per_stride - 25) / 25;
 slow = max(0, cycle - 1.30) / 1.30;
 fast = max(0, 0.85 - cycle) / 0.85;
 gap = P.Double_swing_gap / 100;
 sc = -(3 * asym_frac + ds_dev + slow + fast + 0.5 * gap);
end
