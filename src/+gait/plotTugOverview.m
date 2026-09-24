function plotTugOverview(data, pts, P, SG, outPath)
%plotTugOverview Whole-trial TUG overview (the full sit -> stand -> walk out
%               -> turn -> walk back -> sit-down sequence, no zoom).
%
% Answers "where inside the TUG does the analysed gait cycle sit?":
%
%   panel 1  SpineBase height + sit->stand threshold  -> stand-up / sit-down
%   panel 2  CoM forward displacement (+ turn peak)   -> outbound / turn / return
%   panel 3  ankle forward trajectories + ALL HS/TO events
%   panel 4  the five TUG stages as a colour bar with durations
%
% Shaded bands = the five stages (from gait.tugSegments). The black band and
% the two black lines in panel 3 mark the analysed cycle [L.HS, L.HS2].
%
% Saves a PNG when outPath is given.
%
% Whole-trial overview figure for this pipeline.
%
% R2021b notes:
%   * text() does NOT accept an axes handle first (it would be parsed as the
%     3-D form text(x,y,z,txt)); 'Parent'/Position name-value pairs are used.
%   * legend auto-update is switched off after creation, otherwise the stage
%     patches added later show up as bogus 'data1'..'data5' entries.
%   * plot/patch use 'Parent' explicitly so this works headless (-batch).

 if nargin < 5, outPath = ''; end

 t = pts.t(:);
 N = numel(t);
 fs = data.fs;
 tug_s = N / fs;
 seg = pts.seg;
 i_stand = seg.i_stand; i_sit = seg.i_sit;
 comF = seg.comF(:);
 y = gait.preprocessJoints(data, 5.0, 4).joints.SpineBase.Y;
 aL = pts.ankleFwdL(:); aR = pts.ankleFwdR(:);
 cL = [0.84 0.15 0.15];
 cR = [0.12 0.47 0.71];
 cGray = [0.22 0.28 0.31];
 cPurple = [0.48 0.12 0.63];
 cGreen = [0.18 0.49 0.20];
 cOrange = [0.90 0.32 0.00];
 cBrown = [0.36 0.25 0.22];
 cCycle = [0.07 0.07 0.07];

 fig = figure('Position', [60 30 1280 940], 'Color', 'w');
 pos = [0.082 0.795 0.880 0.125
        0.082 0.635 0.880 0.105
        0.082 0.345 0.880 0.235
        0.082 0.215 0.880 0.075];
 ax = gobjects(1, 4);
 for k = 1:4
   ax(k) = axes('Parent', fig, 'Position', pos(k, :));
   hold(ax(k), 'on');
   grid(ax(k), 'on');
   box(ax(k), 'on');
 end

 % ---------------- panel 1: SpineBase height ----------------
 hY = plot(ax(1), t, y, 'Color', cGray, 'LineWidth', 1.3);
 hThr = plot(ax(1), [0 tug_s], [seg.y_thr seg.y_thr], '--', ...
   'Color', cPurple, 'LineWidth', 1.1);
 plot(ax(1), t(i_stand), y(i_stand), 'v', 'MarkerSize', 9, ...
   'MarkerFaceColor', cGreen, 'MarkerEdgeColor', cGreen);
 plot(ax(1), t(i_sit), y(i_sit), 'v', 'MarkerSize', 9, ...
   'MarkerFaceColor', cBrown, 'MarkerEdgeColor', cBrown);
 xlim(ax(1), [0 tug_s]);
 yl1 = ylim(ax(1));
 shadeStages(ax(1), SG, 0.10, yl1);
 text('Parent', ax(1), 'Position', [t(i_stand), y(i_stand)], ...
   'String', sprintf('stand-up complete\nframe %d (%.2f s)', i_stand, t(i_stand)), ...
   'Color', cGreen, 'FontSize', 7.5, 'Interpreter', 'none', ...
   'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom');
 text('Parent', ax(1), 'Position', [tug_s - 0.06, yl1(2)], ...
   'String', sprintf('sit-down starts\nframe %d (%.2f s)', i_sit, t(i_sit)), ...
   'Color', cBrown, 'FontSize', 7.5, 'Interpreter', 'none', ...
   'HorizontalAlignment', 'right', 'VerticalAlignment', 'top');
 ylabel(ax(1), 'SpineBase height (camera Y, m)', 'FontSize', 8.5);
 lg1 = legend([hY hThr], ...
   {'SpineBase height (camera Y)'; 'sit->stand threshold (min + 0.5 x range)'}, ...
   'Location', 'southeast', 'FontSize', 7, 'Interpreter', 'none');
 set(lg1, 'AutoUpdate', 'off');

 % ---------------- panel 2: CoM forward displacement ----------------
 hCom = plot(ax(2), t, comF, 'Color', cGreen, 'LineWidth', 1.5);
 plot(ax(2), [0 tug_s], [0 0], 'k-', 'LineWidth', 0.6);
 pk = seg.comF_peak;
 hPk = plot(ax(2), t(pk), comF(pk), 'o', 'MarkerSize', 7, ...
   'MarkerFaceColor', cOrange, 'MarkerEdgeColor', cOrange);
 xlim(ax(2), [0 tug_s]);
 yl2 = ylim(ax(2));
 shadeStages(ax(2), SG, 0.10, yl2);
 text('Parent', ax(2), 'Position', [t(pk), comF(pk)], ...
   'String', sprintf('turn peak (frame %d, %.2f s)', pk, t(pk)), ...
   'Color', cOrange, 'FontSize', 7.5, 'Interpreter', 'none', ...
   'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom');
 ylabel(ax(2), 'CoM forward displacement (m)', 'FontSize', 8.5);
 lg2 = legend([hCom hPk], {'CoM forward displacement'; 'turn peak'}, ...
   'Location', 'southeast', 'FontSize', 7, 'Interpreter', 'none');
 set(lg2, 'AutoUpdate', 'off');

 % ---------------- panel 3: ankle forward + all events ----------------
 hL = plot(ax(3), t, aL, 'Color', cL, 'LineWidth', 1.2);
 hR = plot(ax(3), t, aR, 'Color', cR, 'LineWidth', 1.2);
 hsL = pts.hsL_all; toL = pts.toL_all;
 hsR = pts.hsR_all; toR = pts.toR_all;
 hHS = plot(ax(3), t(hsL), aL(hsL), 'o', 'MarkerSize', 4.5, ...
   'MarkerFaceColor', cL, 'MarkerEdgeColor', cL);
 hTO = plot(ax(3), t(toL), aL(toL), '^', 'MarkerSize', 4.5, ...
   'MarkerFaceColor', 'none', 'MarkerEdgeColor', cL);
 plot(ax(3), t(hsR), aR(hsR), 'o', 'MarkerSize', 4.5, ...
   'MarkerFaceColor', cR, 'MarkerEdgeColor', cR);
 plot(ax(3), t(toR), aR(toR), '^', 'MarkerSize', 4.5, ...
   'MarkerFaceColor', 'none', 'MarkerEdgeColor', cR);
 xlim(ax(3), [0 tug_s]);
 yl3 = ylim(ax(3));
 shadeStages(ax(3), SG, 0.10, yl3);
 cb = P.cycle_bounds;
 hCyc = patch('Parent', ax(3), 'XData', [cb(1) cb(2) cb(2) cb(1)], ...
   'YData', [yl3(1) yl3(1) yl3(2) yl3(2)], 'FaceColor', cCycle, 'EdgeColor', 'none');
 set(hCyc, 'FaceAlpha', 0.13);
 plot(ax(3), [cb(1) cb(1)], yl3, '-', 'Color', cCycle, 'LineWidth', 1.2);
 plot(ax(3), [cb(2) cb(2)], yl3, '-', 'Color', cCycle, 'LineWidth', 1.2);
 text('Parent', ax(3), 'Position', [cb(1), yl3(1)], ...
   'String', sprintf('analysed gait cycle\nframes %d-%d (%.2f-%.2f s)', ...
   pts.window(1) - 1, pts.window(2) - 1, cb(1), cb(2)), ...
   'Color', cCycle, 'FontSize', 7.5, 'Interpreter', 'none', ...
   'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom', ...
   'BackgroundColor', 'w', 'Margin', 1);
 ylabel(ax(3), 'Ankle forward Z (m)', 'FontSize', 8.5);
 lg3 = legend([hL hR hHS hTO], ...
   {'Left ankle forward Z'; 'Right ankle forward Z'; ...
    'HS (heel strike, foot lands)'; 'TO (toe-off, foot lifts)'}, ...
   'Location', 'northeast', 'FontSize', 7, 'Interpreter', 'none');
 set(lg3, 'NumColumns', 2);
 set(lg3, 'AutoUpdate', 'off');

 % ---------------- panel 4: stage bar ----------------
 hStage = gobjects(1, numel(SG.order));
 legTxt = {};
for s = 1:numel(SG.order)
  key = SG.order{s};
  b = SG.bounds.(key);
  if b(2) <= b(1), continue; end
  hStage(s) = patch('Parent', ax(4), 'XData', [b(1) b(2) b(2) b(1)], ...
    'YData', [0.30 0.30 0.92 0.92], 'FaceColor', SG.colors.(key), ...
    'EdgeColor', 'w', 'LineWidth', 0.9);
  text('Parent', ax(4), 'Position', [(b(1) + b(2)) / 2, 0.61], ...
    'String', num2str(s), 'FontSize', 8, 'FontWeight', 'bold', ...
    'Color', [0.13 0.13 0.13], 'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'middle', 'Interpreter', 'none');
  legTxt{end + 1} = sprintf('%d. %s   %.2f-%.2f s  (%.2f s, %.1f%%)', ...
    s, SG.labels.(key), b(1), b(2), SG.durations.(key), SG.pct.(key));
end
hStage = hStage(isgraphics(hStage));
if ~isempty(hStage)
  xlim(ax(4), [0 tug_s]);
  ylim(ax(4), [0.05 1.05]);
  set(ax(4), 'YTick', []);
  ylabel(ax(4), 'TUG stages', 'FontSize', 8.5);
  xlabel(ax(4), 'Time (s)');
  lg4 = legend(hStage, legTxt, 'Location', 'southoutside', 'FontSize', 7.2, ...
    'Interpreter', 'none', 'Box', 'off');
  set(lg4, 'NumColumns', 2);
  set(lg4, 'AutoUpdate', 'off');
  set(ax(4), 'Position', pos(4, :));
  set(lg4, 'Units', 'normalized');
  p4 = get(ax(4), 'Position');
  set(lg4, 'Position', [p4(1), p4(2) - 0.105, p4(3), 0.085]);
end

 % ---------------- title ----------------
 annotation(fig, 'textbox', [0.02 0.955 0.96 0.042], 'String', ...
   sprintf(['Full TUG trial overview - sit -> stand -> walk out -> turn -> walk back -> sit down\n' ...
   'N=%d frames, %.0f fps, TUG time = %.2f s   |   shaded bands = the five TUG stages   |   ' ...
   'black lines = analysed cycle [L.HS, L.HS2]'], N, fs, tug_s), ...
   'HorizontalAlignment', 'center', 'Interpreter', 'none', ...
   'FontSize', 9.5, 'EdgeColor', 'none', 'VerticalAlignment', 'middle');

 if ~isempty(outPath)
   print(fig, outPath, '-dpng', '-r130');
 end
end

% -------------------------------------------------------------------------
function shadeStages(ax, SG, alpha, yl)
% Draw one translucent band per TUG stage across the full y range of ax.
 for s = 1:numel(SG.order)
   key = SG.order{s};
   b = SG.bounds.(key);
   if b(2) <= b(1), continue; end
   h = patch('Parent', ax, 'XData', [b(1) b(2) b(2) b(1)], ...
     'YData', [yl(1) yl(1) yl(2) yl(2)], ...
     'FaceColor', SG.colors.(key), 'EdgeColor', 'none');
   set(h, 'FaceAlpha', alpha);
   uistack(h, 'bottom');
 end
 ylim(ax, yl);
end
