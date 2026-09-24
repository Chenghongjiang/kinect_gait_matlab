%% example_gait_analysis One-shot TUG gait analysis pipeline.
% Runs the 6-point method (best cycle of the OUTBOUND walking leg) and writes
% CSVs + figures to ../outputs.
%
% Outputs:
% outputs/cycle6_points.csv 6 key points + double-support range
% outputs/gait_parameters.csv 8 final gait parameters
% outputs/stance_phases.csv 4 standard support phases
% outputs/tug_segments.csv 5 whole-trial TUG stages (sit/walk out/turn/walk back/sit down)
% outputs/gait_events.csv all detected HS/TO events
% outputs/fig_tug_overview.png whole TUG trial + five stages + analysed cycle
% outputs/fig_cycle6_points.png ankle trajectory + events + DS band
% outputs/fig_cycle6_points_with_phases.png trajectory + support phases
% outputs/fig_stance_phases.png support phase bar chart (absolute time)
% outputs/fig_stance_phases_pct.png support phase bar chart (% gait cycle)
%
% Run: >> run('src/example_gait_analysis.m')
%
% NOTE: parameter struct field names use R2021b-legal identifiers
% (e.g. Step_Speed instead of 'Step Speed (m/s)') so the code runs on this
% MATLAB release; the CSV column labels below keep the human-friendly names.
%
% FRAME INDEXING: every frame number written to a CSV or printed to the
% console is a 0-BASED sample index (frame i = the (i+1)-th data row,
% time = i/fs). That is the 0-based convention used throughout this toolbox
% implementation, so the two sets of outputs are directly comparable.
% MATLAB row indices stay 1-based inside the +gait functions.

 baseDir = fileparts(mfilename('fullpath'));
 addpath(baseDir);
 dataDir = fullfile(baseDir, '..', 'data');
 outDir = fullfile(baseDir, '..', 'outputs');
 mkdir(outDir);

 data = gait.loadKinect(fullfile(dataDir, 'sample_TUG_gait.csv'));
 fs = data.fs;
 tug_time = data.N / fs;

 fprintf('==========================================================\n');
 fprintf('TUG total time = %.2f s (N=%d frames, fs=%d Hz)\n', tug_time, data.N, fs);
 fprintf('==========================================================\n');

 % the best cycle of the OUTBOUND walking leg (the manuscript's rule: the
 % analysed cycle is always taken before the turn)
 pts = gait.extractCyclePoints(data, 5.0, 4, 0.6, 0.04);
 if isempty(pts)
 error('No usable gait cycle was extracted from this recording.');
 end
 P = gait.computeParamsFromPoints(pts, tug_time);

 L = pts.L; R = pts.R;
 fprintf('\n########## best outbound cycle ##########\n');
 fprintf('window: frame %d~%d (%.3f~%.3f s)\n', ...
 pts.window(1) - 1, pts.window(2) - 1, ...
 t_at(pts, pts.window(1)), t_at(pts, pts.window(2)));
 fprintf('left cycle [L.HS, L.HS2]: %.3f~%.3f s (%.3f s)\n', ...
 P.cycle_bounds(1), P.cycle_bounds(2), P.union);
 fprintf('right cycle [R.HS, R.HS2]: %.3f~%.3f s (%.3f s, its own stride)\n', ...
 P.right_cycle_bounds(1), P.right_cycle_bounds(2), R.HS2(2) - R.HS(2));
 fprintf('double support: initial %.3f~%.3f + terminal %.3f~%.3f (total %.3f s)\n', ...
 P.ds_init(1), P.ds_init(2), P.ds_term(1), P.ds_term(2), P.overlap);
 fprintf('R.TO_prev (used by the phases) = %.3f s | R.TO (right foot''s own) = %.3f s\n', ...
 R.TO_prev(2), R.TO(2));
 fprintf('L ankle HS %d %.3f %+.3f | TO %d %.3f %+.3f | HS2 %d %.3f %+.3f\n', ...
 zerobased(L.HS), zerobased(L.TO), zerobased(L.HS2));
 fprintf('R ankle HS %d %.3f %+.3f | TO %d %.3f %+.3f | HS2 %d %.3f %+.3f\n', ...
 zerobased(R.HS), zerobased(R.TO), zerobased(R.HS2));
 fkeys = {'Step Speed (m/s)', 'Cadence (steps/min)', 'Stride length (m)', ...
 'Left single-limb support (%)', 'Right single-limb support (%)', ...
 'Single-limb support (%)', 'Double-limb support (%)', ...
 'Double-limb support (per stride) (%)', 'Stride time (s)', ...
 'Swing phase velocity (m/s)', 'TUG time (s)', ...
 'Avg single-limb support (%)', 'Avg double-limb support (%)', ...
 'Avg swing phase (%)'};
 lkeys = {'Step_Speed', 'Cadence', 'Stride_length', ...
 'Left_single_support', 'Right_single_support', ...
 'Single_support', 'Double_support', ...
 'Double_support_per_stride', 'Stride_time', ...
 'Swing_velocity', 'TUG_time', ...
 'Avg_single_support', 'Avg_double_support', ...
 'Avg_swing_phase'};
 for k = 1:numel(fkeys)
 fprintf(' %-30s: %.3f\n', fkeys{k}, P.(lkeys{k}));
 end
 fprintf(' stance fraction D = %.3f double-swing gap = %.2f%% identity L+R+DS = %.1f%%\n', ...
 P.stance_fraction, P.Double_swing_gap, P.ds_check_sum);
 % every outbound candidate and the score that ranked it (score/loc/phys);
 % the selected one is the maximum of `score`
 if isfield(pts, 'candidates')
 fprintf(' [outbound candidate scores score/loc/phys | window]\n');
 C = pts.candidates;
 for r = 1:size(C, 1)
 tag = '';
 if C{r, 4} == pts.window(1) && C{r, 5} == pts.window(2), tag = ' <== selected'; end
 fprintf(' score=%.3f loc=%.3f phys=%+.3f frame %d~%d%s\n', ...
 C{r, 1}, C{r, 2}, C{r, 3}, C{r, 4} - 1, C{r, 5} - 1, tag);
 end
 end

 if ~pts.outbound_ok
 fprintf('[note] no outbound cycle candidate in this trial - the analysed cycle was taken from the whole straight walk\n');
 end

 % ---- save 6-point table ----
 T6 = table();
 sides = {'L', 'R', 'L', 'R', 'L', 'R'};
 evs = {'HS', 'HS', 'TO', 'TO', 'HS2', 'HS2'};
 fr = [L.HS(1) R.HS(1) L.TO(1) R.TO(1) L.HS2(1) R.HS2(1)];
 fr = fr - 1; % 1-based row index -> 0-based frame index (see the note above)
 tm = [L.HS(2) R.HS(2) L.TO(2) R.TO(2) L.HS2(2) R.HS2(2)];
 zz = [L.HS(3) R.HS(3) L.TO(3) R.TO(3) L.HS2(3) R.HS2(3)];
 T6.side = sides'; T6.event = evs'; T6.frame = fr';
 T6.time_s = round(tm, 4)'; T6.forward_Z_m = round(zz, 4)';
 % The right-foot toe-off that the support phases actually use. It is a
 % different event from R.TO above (which is the right foot's own lift-off in
 % its own stride [R.HS, R.HS2]), so it is exported explicitly.
 T6 = [T6; table({'R'}, {'TO_prev'}, R.TO_prev(1) - 1, round(R.TO_prev(2), 4), ...
 round(R.TO_prev(3), 4), ...
 'VariableNames', {'side', 'event', 'frame', 'time_s', 'forward_Z_m'})];
 % the two double-support intervals of the analysed cycle (they are disjoint)
 T6 = [T6; table({'BOTH'; 'BOTH'; 'BOTH'; 'BOTH'}, ...
 {'DS_initial_start'; 'DS_initial_end'; 'DS_terminal_start'; 'DS_terminal_end'}, ...
 NaN(4, 1), round([P.ds_init(1); P.ds_init(2); P.ds_term(1); P.ds_term(2)], 4), ...
 NaN(4, 1), ...
 'VariableNames', {'side', 'event', 'frame', 'time_s', 'forward_Z_m'})];
 writetable(T6, fullfile(outDir, 'cycle6_points.csv'));
 fprintf('\n[saved] outputs/cycle6_points.csv\n');

 % ---- save parameters ----
 paramNames = {'Step Speed (m/s)', 'Cadence (steps/min)', 'Stride length (m)', ...
 'Left single-limb support (%)', 'Right single-limb support (%)', ...
 'Single-limb support (%)', 'Double-limb support (%)', ...
 'Double-limb support (per stride) (%)', 'Stride time (s)', ...
 'Swing phase velocity (m/s)', 'TUG time (s)', ...
 'Avg single-limb support (%)', 'Avg double-limb support (%)', ...
 'Avg swing phase (%)'};
 lkeys = {'Step_Speed', 'Cadence', 'Stride_length', ...
 'Left_single_support', 'Right_single_support', ...
 'Single_support', 'Double_support', ...
 'Double_support_per_stride', 'Stride_time', ...
 'Swing_velocity', 'TUG_time', ...
 'Avg_single_support', 'Avg_double_support', ...
 'Avg_swing_phase'};
 units = {'m/s', 'steps/min', 'm', '%', '%', '%', '%', '%', 's', 'm/s', 's', ...
 '%', '%', '%'};
 Tp = table(paramNames', cellfun(@(k) P.(k), lkeys'), units', ...
 'VariableNames', {'Parameter', 'Value', 'Unit'});
 writetable(Tp, fullfile(outDir, 'gait_parameters.csv'));
 fprintf('[saved] outputs/gait_parameters.csv\n');

 % ---- support phases ----
 S = gait.stancePhases(pts);
 fprintf('\n-- support phases (cycle %.3f s, frames %d-%d) --\n', ...
 S.cycle_s, S.window_frames(1), S.window_frames(2));
 for k = 1:numel(S.order)
 key = S.order{k};
 fprintf(' %-26s %.3f - %.3f s %.3f s (%.1f%%)\n', ...
 S.labels.(key), S.phases.(key)(1), S.phases.(key)(2), ...
 S.durations.(key), S.pct.(key));
 end
 fprintf(' sum = %.1f%% double-swing gap = %.3f s\n', ...
 sum(cell2mat(struct2cell(S.pct))), S.gap_s);

 Tst = table();
 phaseNames = {}; starts = []; ends = []; durs = []; pcts = [];
 for k = 1:numel(S.order)
 key = S.order{k};
 phaseNames{end + 1, 1} = S.labels.(key);
 starts(end + 1, 1) = S.phases.(key)(1);
 ends(end + 1, 1) = S.phases.(key)(2);
 durs(end + 1, 1) = S.durations.(key);
 pcts(end + 1, 1) = S.pct.(key);
 end
 Tst.phase = phaseNames;
 Tst.start_s = starts;
 Tst.end_s = ends;
 Tst.duration_s = durs;
 Tst.pct_of_cycle = pcts;
 writetable(Tst, fullfile(outDir, 'stance_phases.csv'));
 fprintf('[saved] outputs/stance_phases.csv\n');

 % ---- whole-trial TUG stages (sit -> walk out -> turn -> walk back -> sit down) ----
 SG = gait.tugSegments(pts, data);
 fprintf('\n-- TUG stages (whole trial %.2f s) --\n', SG.tug_s);
 for i = 1:numel(SG.order)
 k = SG.order{i};
 b = SG.bounds.(k);
 fprintf(' %d. %-22s frames %3d-%3d %6.3f-%-6.3f s %5.2f s (%5.1f%%)\n', ...
 i, SG.labels.(k), b(3) - 1, b(4) - 1, b(1), b(2), SG.durations.(k), SG.pct.(k));
 end
 fprintf(' analysed cycle [L.HS, L.HS2] = %.3f-%.3f s\n', P.cycle_bounds(1), P.cycle_bounds(2));
 if ~isempty(SG.note), fprintf(' [note] %s\n', SG.note); end
 writetable(SG.T, fullfile(outDir, 'tug_segments.csv'));
 fprintf('[saved] outputs/tug_segments.csv\n');

 % ---- all detected events ----
 evRows = {};
 for i = pts.hsL_all'
 evRows(end + 1, :) = {'L', 'HS', i - 1, pts.t(i)};
 end
 for i = pts.toL_all'
 evRows(end + 1, :) = {'L', 'TO', i - 1, pts.t(i)};
 end
 for i = pts.hsR_all'
 evRows(end + 1, :) = {'R', 'HS', i - 1, pts.t(i)};
 end
 for i = pts.toR_all'
 evRows(end + 1, :) = {'R', 'TO', i - 1, pts.t(i)};
 end
 EvT = cell2table(evRows, 'VariableNames', {'side', 'event', 'frame', 'time_s'});
 EvT = sortrows(EvT, 'time_s');
 writetable(EvT, fullfile(outDir, 'gait_events.csv'));
 fprintf('[saved] outputs/gait_events.csv\n');

 % ---- figures (best-effort; skipped when no display device, e.g. -batch) ----
 try
 gait.plotTugOverview(data, pts, P, SG, fullfile(outDir, 'fig_tug_overview.png'));
 fprintf('[saved] outputs/fig_tug_overview.png\n');
 gait.plotGaitCycle(pts, P, fullfile(outDir, 'fig_cycle6_points.png'));
 fprintf('[saved] outputs/fig_cycle6_points.png\n');
 gait.plotCycleWithPhases(pts, P, S, fullfile(outDir, 'fig_cycle6_points_with_phases.png'));
 fprintf('[saved] outputs/fig_cycle6_points_with_phases.png\n');
 gait.plotStancePhases(pts, S, fullfile(outDir, 'fig_stance_phases.png'), false);
 fprintf('[saved] outputs/fig_stance_phases.png\n');
 gait.plotStancePhases(pts, S, fullfile(outDir, 'fig_stance_phases_pct.png'), true);
 fprintf('[saved] outputs/fig_stance_phases_pct.png\n');
 catch ME
 fprintf('[figures skipped: %s]\n', ME.message);
 end

 fprintf('\nDONE -> %s\n', outDir);

function tt = t_at(pts, idx)
 tt = pts.t(idx);
end

function e = zerobased(e)
% 1-based MATLAB row index -> 0-based frame index used in the exported files.
 e(1) = e(1) - 1;
end
