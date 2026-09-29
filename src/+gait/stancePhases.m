function S = stancePhases(pts)
%stancePhases Decompose a selected gait cycle into the four standard phases.
%
% On a left-ankle cycle [L.HS -> L.HS2]:
% t0 = L.HS left foot lands
% t1 = R.TO_prev right foot of the previous step pushes off
% t2 = R.HS right foot lands
% t3 = L.TO left foot pushes off
% t4 = L.HS2 left foot lands again
%
% NOTE t1 is R.TO_prev, i.e. the right toe-off inside [L.HS, R.HS). It is a
% different event from pts.R.TO, which is the right foot's own lift-off in
% [R.HS, R.HS2] and lies one cycle later. Both this function and
% computeParamsFromPoints read the same field, pts.R.TO_prev, so the phase
% boundaries and the reported single/double-support percentages cannot drift
% apart.
%
% Phases:
% [t0,t1] = Initial double support
% [t1,t2] = Left single support
% [t2,t3] = Terminal double support
% [t3,t4] = Right single support
%
% The four phase durations sum to the stride time (ideal: 100%).

 t = pts.t;
 aFrame = pts.L.HS(1);
 bFrame = pts.L.HS2(1);
 t0 = t(aFrame);
 t4 = t(bFrame);

 rHsFrame = pts.R.HS(1);
 if isfield(pts.R, 'TO_prev')
   t1 = pts.R.TO_prev(2); % single source of truth (see note above)
 else
   toR = pts.toR_all;
   between = toR(toR >= aFrame & toR < rHsFrame);
   if isempty(between)
     t1 = t0; % no initial double support (fast cadence)
   else
     t1 = t(between(1));
   end
 end
 t2 = pts.R.HS(2);
 t3 = pts.L.TO(2);

 % clamp into [t0,t4] and enforce monotonic
 bounds = [min(max(t1, t0), t4); min(max(t2, t0), t4); min(max(t3, t0), t4)];
 for i = 2:3
 bounds(i) = max(bounds(i), bounds(i - 1));
 end
 t1 = bounds(1); t2 = bounds(2); t3 = bounds(3);

 cycle = max(1e-9, t4 - t0);

 S.order = {'initial_DS', 'left_SS', 'terminal_DS', 'right_SS'};
 S.phases.initial_DS = [t0, t1];
 S.phases.left_SS = [t1, t2];
 S.phases.terminal_DS = [t2, t3];
 S.phases.right_SS = [t3, t4];

 S.labels.initial_DS = 'Initial double support';
 S.labels.left_SS = 'Left single support';
 S.labels.terminal_DS = 'Terminal double support';
 S.labels.right_SS = 'Right single support';

 S.colors.initial_DS = '#FDD835';
 S.colors.left_SS = '#64B5F6';
 S.colors.terminal_DS = '#FF9800';
 S.colors.right_SS = '#EF5350';

 S.durations.initial_DS = max(0, t1 - t0);
 S.durations.left_SS = max(0, t2 - t1);
 S.durations.terminal_DS = max(0, t3 - t2);
 S.durations.right_SS = max(0, t4 - t3);

 S.pct.initial_DS = 100 * S.durations.initial_DS / cycle;
 S.pct.left_SS = 100 * S.durations.left_SS / cycle;
 S.pct.terminal_DS = 100 * S.durations.terminal_DS / cycle;
 S.pct.right_SS = 100 * S.durations.right_SS / cycle;

 S.cycle_s = cycle;
 S.gap_s = max(0, cycle - (S.durations.initial_DS + S.durations.left_SS + S.durations.terminal_DS + S.durations.right_SS));
 S.window_frames = [aFrame - 1, bFrame - 1];   % 0-based, for reporting only
end
