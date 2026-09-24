function P = computeParamsFromPoints(pts, tug_time)
%computeParamsFromPoints Spatiotemporal gait parameters from 6 key points.
%
% TWO FAMILIES OF PARAMETERS, TWO DIFFERENT TIME WINDOWS
% ------------------------------------------------------
% (A) Per-limb parameters - each foot measured on its OWN stride:
%     stride_len_L/R, stride_time_L/R, swing_dist_L/R -> Step_Speed, Cadence,
%     Stride_length, Stride_time, Swing_velocity.
%     These legitimately use the 6 points as extracted (left triple on the
%     left stride, right triple on the right stride). Do NOT collapse them
%     onto one window: swing velocity in particular needs each foot's own TO.
%
% (B) Support-phase parameters - measured on ONE cycle, the LEFT stride
%     [L.HS, L.HS2], from the interleaved events of both feet:
%       t0 = L.HS       left foot lands            (cycle start)
%       t1 = R.TO_prev  right foot lifts off       (end of initial DS)
%       t2 = R.HS       right foot lands           (end of left single support)
%       t3 = L.TO       left foot lifts off        (end of terminal DS)
%       t4 = L.HS2      left foot lands again      (end of right single support)
%
%     NOTE: t1 must be R.TO_prev, NOT R.TO. R.TO is the right foot's own
%     lift-off inside [R.HS, R.HS2], i.e. one cycle later; using it made the
%     "double support" collapse to the terminal double support alone and made
%     the normalisation window (union) exceed the stride time.
%
%     The four intervals tile [t0, t4] exactly, so
%       Left_single_support + Right_single_support
%         + (initial DS + terminal DS) == 100%.
%
% Double_support reports the TOTAL double support on the cycle (initial +
% terminal). Double_support_per_stride re-expresses the same quantity per
% stride through the stance fraction D = stance/stride measured on these same
% 6 points: DS% = (2D-1)*100. One stride contains TWO double-support
% intervals, so the per-stride value is the smaller of the two by construction.

 L = pts.L; R = pts.R;
 tL1 = L.HS(2); tL2 = L.TO(2); tL3 = L.HS2(2);
 tR1 = R.HS(2); tR2 = R.TO(2); tR3 = R.HS2(2);
 zL1 = L.HS(3); zL2 = L.TO(3); zL3 = L.HS2(3);
 zR1 = R.HS(3); zR2 = R.TO(3); zR3 = R.HS2(3);

 stride_time_L = tL3 - tL1;
 stance_L = tL2 - tL1; % left foot on ground (land -> lift)
 swing_L = tL3 - tL2;
 stride_len_L = abs(zL3 - zL1);
 swing_dist_L = abs(zL3 - zL2);

 stride_time_R = tR3 - tR1;
 stance_R = tR2 - tR1;
 swing_R = tR3 - tR2;
 stride_len_R = abs(zR3 - zR1);
 swing_dist_R = abs(zR3 - zR2);

 % ---- (B) support phases: single-cycle interleaved-event decomposition ----
 if isfield(R, 'TO_prev')
   tR0 = R.TO_prev(2);
 else
   tR0 = tL1; % no initial double support (very fast cadence)
 end
 e = [tR0; tR1; tL2];
 for k = 1:3
   e(k) = min(max(e(k), tL1), tL3);
 end
 e(2) = max(e(2), e(1));
 e(3) = max(e(3), e(2));

 union = max(1e-9, tL3 - tL1); % the reference cycle = left stride
 init_ds = max(0, e(1) - tL1);
 left_ss = max(0, e(2) - e(1));
 term_ds = max(0, e(3) - e(2));
 right_ss = max(0, tL3 - e(3));
 overlap = init_ds + term_ds; % total double support on the cycle
 gap = max(0, union - (init_ds + left_ss + term_ds + right_ss));

 ds_pct = overlap / union * 100;
 ssL_pct = left_ss / union * 100;
 ssR_pct = right_ss / union * 100;
 gap_pct = gap / union * 100;

 cycle = 0.5 * (stride_time_L + stride_time_R); % mean stride (for cadence)
 speed = 0.5 * (stride_len_L / stride_time_L + stride_len_R / stride_time_R);
 cadence = 120 / cycle;
 stride_len = 0.5 * (stride_len_L + stride_len_R);
 stride_time = cycle;
 swing_vel = 0.5 * (swing_dist_L / swing_L + swing_dist_R / swing_R);

 % The analysed window is ONE stride, so "double support per cycle" and "double
 % support per stride" are the SAME quantity: report the event-based value
 % (initial + terminal DS, normalised by the stride). The stance fraction
 % D = stance/stride is exported separately as a diagnostic. The earlier
 % (2D-1)*100 identity is exact only for symmetric gait and produced impossible
 % >50% values on slow/asymmetric cycles, so it is dropped here.
 stance_frac = 0.5 * ((stance_L / stride_time_L) + (stance_R / stride_time_R));
 ds_per_stride = min(50, max(0, ds_pct));

 % swing phase percentages (per-limb, on each foot's own stride)
 swing_pct_L = swing_L / stride_time_L * 100;
 swing_pct_R = swing_R / stride_time_R * 100;

 % averaged support / swing phases (left-right mean)
 avg_single_support = 0.5 * (ssL_pct + ssR_pct);
 avg_double_support = 0.5 * ds_pct;       % mean of initial + terminal DS
 avg_swing_phase    = 0.5 * (swing_pct_L + swing_pct_R);

 P = struct();
 P.Step_Speed = speed;
 P.Cadence = cadence;
 P.Stride_length = stride_len;
 P.Left_single_support = ssL_pct;
 P.Right_single_support = ssR_pct;
 P.Single_support = ssL_pct + ssR_pct;
 P.Double_support = ds_pct;
 P.Double_support_per_stride = ds_per_stride;
 P.Stride_time = stride_time;
 P.Swing_velocity = swing_vel;
 P.TUG_time = tug_time;
 P.Avg_single_support = avg_single_support;
 P.Avg_double_support = avg_double_support;
 P.Avg_swing_phase = avg_swing_phase;
 P.Double_swing_gap = gap_pct;
 P.stance_fraction = stance_frac;
 P.ds_check_sum = ssL_pct + ssR_pct + ds_pct;
 P.stance_L = stance_L; P.stance_R = stance_R;
 P.stride_time_L = stride_time_L; P.stride_time_R = stride_time_R;
 P.overlap = overlap; P.union = union; P.gap = gap;
 % phase durations + boundaries (all on the left stride [L.HS, L.HS2])
 P.init_ds = init_ds; P.left_ss = left_ss;
 P.term_ds = term_ds; P.right_ss = right_ss;
 P.ds_init = [tL1, tL1 + init_ds];
 P.ds_term = [e(2), e(3)];
 P.cycle_bounds = [tL1, tL3];
 P.right_cycle_bounds = [tR1, tR3];
end
