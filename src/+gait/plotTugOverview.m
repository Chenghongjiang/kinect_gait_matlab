function [H, fig] = plotTugOverview(data, pts, P, SG, outPath, parentFig)
%plotTugOverview Whole-trial TUG overview (the full sit -> stand -> walk out
%               -> turn -> walk back -> sit-down sequence, no zoom).
%
% With an output argument the handles of every DYNAMIC graphic are returned
% in H (stage shading bands, turn window, stage-bar patches + number labels,
% axes) so gait.interactiveTUG can update them while a boundary line is
% dragged. parentFig (optional): draw into this existing figure (clf'ed
% first) instead of creating a new one.
%
% Answers "where inside the TUG does the analysed gait cycle sit?":
%
%   panel 1  SpineBase height + sit->stand threshold  -> stand-up / sit-down
%   panel 2  CoM forward displacement (+ turn peak)   -> outbound / turn / return
%   panel 3  left-right shoulder X distance (+ turn edges) -> turning
%   panel 4  ankle forward trajectories + ALL HS/TO events
%   panel 5  the five TUG stages as a colour bar with durations
%
% Shaded bands = the five stages (from gait.tugSegments). The black band and
% the two black lines in panel 4 mark the analysed cycle [L.HS, L.HS2].
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
 if nargin < 6, parentFig = []; end

 t = pts.t(:);
 N = numel(t);
 fs = data.fs;
 tug_s = N / fs;
 seg = pts.seg;
 i_stand = seg.i_stand; i_sit = seg.i_sit;
 comF = seg.comF(:);
 pre = gait.preprocessJoints(data, 5.0, 4);
 y = pre.joints.SpineBase.Y;
 aL = pts.ankleFwdL(:); aR = pts.ankleFwdR(:);
 cL = [0.84 0.15 0.15];
 cR = [0.12 0.47 0.71];
 cGray = [0.22 0.28 0.31];
 cPurple = [0.48 0.12 0.63];
 cGreen = [0.18 0.49 0.20];
 cOrange = [0.90 0.32 0.00];
 cBrown = [0.36 0.25 0.22];
 cCycle = [0.07 0.07 0.07];

 if isempty(parentFig) || ~isgraphics(parentFig)
   fig = figure('Position', [60 30 1280 940], 'Color', 'w');
 else
   oldName = get(parentFig, 'Name'); % clf reset would wipe Name -> save + restore
   fig = parentFig;
   clf(fig, 'reset'); % Position / Units survive the reset
   set(fig, 'Color', 'w', 'MenuBar', 'none', 'ToolBar', 'none', ...
     'NumberTitle', 'off', 'Name', oldName);
 end
 % handles of every graphic that gait.interactiveTUG updates live while a
 % boundary line is dragged (stage bands, turn window, stage bar, axes)
 H = struct('bands', {cell(1, 4)}, 'turnWin', [], 'stage', gobjects(1, 5), ...
   'stageNum', gobjects(1, 5), 'ax', []);
 pos = [0.082 0.800 0.880 0.115
        0.082 0.655 0.880 0.095
        0.082 0.545 0.880 0.085
        0.082 0.285 0.880 0.215
        0.082 0.170 0.880 0.068];
 ax = gobjects(1, 5);
 for k = 1:5
   ax(k) = axes('Parent', fig, 'Position', pos(k, :));
   hold(ax(k), 'on');
   grid(ax(k), 'on');
   box(ax(k), 'on');
 end

 % ---------------- panel 1: SpineBase height ----------------
 hY = plot(ax(1), t, y, 'Color', cGray, 'LineWidth', 1.3);
 hThr = plot(ax(1), [0 tug_s], [seg.y_thr seg.y_thr], '--', ...
   'Color', cPurple, 'LineWidth', 1.1);
 hSLy = plot(ax(1), t, pre.joints.ShoulderLeft.Y(:), '-', ...
   'Color', cL, 'LineWidth', 0.8);
 hSRy = plot(ax(1), t, pre.joints.ShoulderRight.Y(:), '-', ...
   'Color', cR, 'LineWidth', 0.8);
 plot(ax(1), t(i_stand), y(i_stand), 'v', 'MarkerSize', 9, ...
   'MarkerFaceColor', cGreen, 'MarkerEdgeColor', cGreen);
 plot(ax(1), t(i_sit), y(i_sit), 'v', 'MarkerSize', 9, ...
   'MarkerFaceColor', cBrown, 'MarkerEdgeColor', cBrown);
 xlim(ax(1), [0 tug_s]);
 yl1 = ylim(ax(1));
 H.bands{1} = shadeStages(ax(1), SG, 0.10, yl1);
 text('Parent', ax(1), 'Position', [t(i_stand), y(i_stand)], ...
   'String', sprintf('stand-up complete\nframe %d (%.2f s)', i_stand - 1, t(i_stand)), ...
   'Color', cGreen, 'FontSize', 7.5, 'Interpreter', 'none', ...
   'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom');
 text('Parent', ax(1), 'Position', [tug_s - 0.06, yl1(2)], ...
   'String', sprintf('sit-down starts\nframe %d (%.2f s)', i_sit - 1, t(i_sit)), ...
   'Color', cBrown, 'FontSize', 7.5, 'Interpreter', 'none', ...
   'HorizontalAlignment', 'right', 'VerticalAlignment', 'top');
 ylabel(ax(1), 'SpineBase height (camera Y, m)', 'FontSize', 8.5);
 lg1 = legend([hY hThr hSLy hSRy], ...
   {'SpineBase height (camera Y)'; 'sit->stand threshold (min + 0.5 x range)'; ...
    'ShoulderLeft Y'; 'ShoulderRight Y'}, ...
   'Location', 'southeast', 'FontSize', 5, 'Interpreter', 'none');
 set(lg1, 'NumColumns', 2);
 set(lg1, 'AutoUpdate', 'off');

 % ---------------- panel 2: CoM forward displacement ----------------
 hCom = plot(ax(2), t, comF, 'Color', cGreen, 'LineWidth', 1.5);
 plot(ax(2), [0 tug_s], [0 0], 'k-', 'LineWidth', 0.6);
 pk = seg.comF_peak;
 hPk = plot(ax(2), t(pk), comF(pk), 'o', 'MarkerSize', 7, ...
   'MarkerFaceColor', cOrange, 'MarkerEdgeColor', cOrange);
 xlim(ax(2), [0 tug_s]);
 yl2 = ylim(ax(2));
 H.bands{2} = shadeStages(ax(2), SG, 0.10, yl2);
 text('Parent', ax(2), 'Position', [t(pk), comF(pk)], ...
   'String', sprintf('turn peak (frame %d, %.2f s)', pk - 1, t(pk)), ...
   'Color', cOrange, 'FontSize', 7.5, 'Interpreter', 'none', ...
   'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom');
 ylabel(ax(2), 'CoM forward displacement (m)', 'FontSize', 8.5);
 lg2 = legend([hCom hPk], {'CoM forward displacement'; 'turn peak'}, ...
   'Location', 'southeast', 'FontSize', 7, 'Interpreter', 'none');
 set(lg2, 'AutoUpdate', 'off');

 % ------------- panel 3: travel heading + shoulder dX (turn) -----------
 % The two L/R-tag-independent signals used by the turn detection:
 %   left axis  - pelvis travel heading relative to the outbound direction
 %   right axis - |ShoulderLeft.X - ShoulderRight.X| (shoulder width
 %                projected on the camera X axis; shrinks while turning)
 % NOTE: uistack() errors on yyaxis axes, so the stage bands / turn patch
 % are drawn on a NORMAL axis first; yyaxis is activated afterwards.
 cTeal = [0.00 0.50 0.50]; cHead = [0.10 0.25 0.70];
 turn_lo = seg.turn_lo; turn_hi = seg.turn_hi;
 headRel = seg.turn_heading_rel * 180/pi;
 headRel(1:i_stand - 1) = NaN; headRel(i_sit + 1:end) = NaN; % no heading at rest
 yl3 = [-190 190];
 H.bands{3} = shadeStages(ax(3), SG, 0.10, yl3);   % before yyaxis conversion
 hWin = patch('Parent', ax(3), ...
   'XData', [t(turn_lo) t(turn_hi) t(turn_hi) t(turn_lo)], ...
   'YData', [yl3(1) yl3(1) yl3(2) yl3(2)], ...
   'FaceColor', cOrange, 'EdgeColor', 'none');
 set(hWin, 'FaceAlpha', 0.13);
 H.turnWin = hWin;
 plot(ax(3), [t(turn_lo) t(turn_lo)], yl3, '-', 'Color', cOrange, 'LineWidth', 1.0);
 plot(ax(3), [t(turn_hi) t(turn_hi)], yl3, '-', 'Color', cOrange, 'LineWidth', 1.0);
 hold(ax(3), 'on'); xlim(ax(3), [0 tug_s]); ylim(ax(3), yl3);

 yyaxis(ax(3), 'right');
 dX = seg.turn_dX;
 hSh = plot(ax(3), t, dX, 'Color', cTeal, 'LineWidth', 1.0);
 plot(ax(3), t(turn_lo), dX(turn_lo), 'v', 'MarkerSize', 7, ...
   'MarkerFaceColor', cOrange, 'MarkerEdgeColor', cOrange);
 % --- anatomical shoulder X trajectories (the TRUE paths): the physical
 % left/right shoulders exchange camera sides during the 180-deg turn.
 % Kinect's camera-side tags hand the anatomical identity over while one
 % shoulder is occluded, so the anatomical traces are reconstructed by
 % swapping the tag source at the frame inside the detected turn window
 % that minimises the post-swap continuity step
 % max(|XR(k)-XL(k+1)|, |XL(k)-XR(k+1)|). Each trace keeps ONE colour for
 % the whole trial and the two traces cross at the reconnection frame.
 % The small step at the crossing (~0.1-0.2 m at 30 fps) is the occlusion
 % limit of the sensor, not real motion.
 XLx = pre.joints.ShoulderLeft.X(:); XRx = pre.joints.ShoulderRight.X(:);
 kBest = 0; cBest = inf;
 kMax = min(turn_hi, numel(XLx) - 1);
 for k = turn_lo:kMax
   cc = max(abs(XRx(k) - XLx(k + 1)), abs(XLx(k) - XRx(k + 1)));
   if cc < cBest, cBest = cc; kBest = k; end
 end
 pL = XLx; pR = XRx;
 if kBest > 0 && kBest < numel(XLx)
   pL(kBest + 1:end) = XRx(kBest + 1:end);
   pR(kBest + 1:end) = XLx(kBest + 1:end);
 end
 hSLx = plot(ax(3), t, pL, '-', 'Color', cL, 'LineWidth', 0.9);
 hSRx = plot(ax(3), t, pR, '-', 'Color', cR, 'LineWidth', 0.9);
 if kBest > 0 && kBest < numel(XLx)
   yCross = mean([XLx(kBest), XRx(kBest)]);
   plot(ax(3), t(kBest), yCross, 'k*', ...
     'MarkerSize', 11, 'LineWidth', 1.2);
   text('Parent', ax(3), 'Position', [t(kBest), yCross], ...
     'String', sprintf('L/R cross %.2f s', t(kBest)), ...
     'Color', [0.15 0.15 0.15], 'FontSize', 7.2, 'Interpreter', 'none', ...
     'HorizontalAlignment', 'left', 'VerticalAlignment', 'top');
 end
 x3 = [pre.joints.ShoulderLeft.X(:); pre.joints.ShoulderRight.X(:)];
 ylim(ax(3), [min(0, min(x3) * 1.15), max([dX; x3]) * 1.15]);
 set(ax(3), 'YColor', cTeal);
 ylabel(ax(3), 'shoulder X / |L-R X| (m)', 'FontSize', 8.5, 'Color', cTeal);

 yyaxis(ax(3), 'left');
 hHead = plot(ax(3), t, headRel, 'Color', cHead, 'LineWidth', 1.4);
 hThr1 = plot(ax(3), [0 tug_s],  30*[1 1], ':', ...
   'Color', cHead, 'LineWidth', 1.0);
 plot(ax(3), [0 tug_s], -30*[1 1], ':', 'Color', cHead, 'LineWidth', 1.0);
 plot(ax(3), t(turn_hi), headRel(turn_hi), 'v', 'MarkerSize', 7, ...
   'MarkerFaceColor', cOrange, 'MarkerEdgeColor', cOrange);
 set(ax(3), 'YColor', cHead, 'YLim', yl3);
 ylabel(ax(3), 'Travel heading rel. outbound (deg)', 'FontSize', 8.5, 'Color', cHead);
 text('Parent', ax(3), 'Position', [t(turn_hi) + 0.08, 178], ...
   'String', sprintf('turn [%s]', seg.turn_method), ...
   'Color', [0.25 0.25 0.25], 'FontSize', 7.2, 'Interpreter', 'none', ...
   'HorizontalAlignment', 'left', 'VerticalAlignment', 'top');
 lgS = legend([hHead hThr1 hSLx hSRx hSh hWin], ...
   {'travel heading rel. outbound'; 'heading threshold +/-30 deg'; ...
    'left shoulder X (anatomical)'; 'right shoulder X (anatomical)'; ...
    '|ShoulderL.X - ShoulderR.X|'; 'detected turn window'}, ...
   'Location', 'northeast', 'FontSize', 5, 'Interpreter', 'none');
 set(lgS, 'NumColumns', 3);
 set(lgS, 'AutoUpdate', 'off');

 % ---------------- panel 4: ankle forward + all events ----------------
 hL = plot(ax(4), t, aL, 'Color', cL, 'LineWidth', 1.2);
 hR = plot(ax(4), t, aR, 'Color', cR, 'LineWidth', 1.2);
 hsL = pts.hsL_all; toL = pts.toL_all;
 hsR = pts.hsR_all; toR = pts.toR_all;
 hHS = plot(ax(4), t(hsL), aL(hsL), 'o', 'MarkerSize', 4.5, ...
   'MarkerFaceColor', cL, 'MarkerEdgeColor', cL);
 hTO = plot(ax(4), t(toL), aL(toL), '^', 'MarkerSize', 4.5, ...
   'MarkerFaceColor', 'none', 'MarkerEdgeColor', cL);
 plot(ax(4), t(hsR), aR(hsR), 'o', 'MarkerSize', 4.5, ...
   'MarkerFaceColor', cR, 'MarkerEdgeColor', cR);
 plot(ax(4), t(toR), aR(toR), '^', 'MarkerSize', 4.5, ...
   'MarkerFaceColor', 'none', 'MarkerEdgeColor', cR);
 xlim(ax(4), [0 tug_s]);
 yl4 = ylim(ax(4));
 H.bands{4} = shadeStages(ax(4), SG, 0.10, yl4);
 cb = P.cycle_bounds;
 hCyc = patch('Parent', ax(4), 'XData', [cb(1) cb(2) cb(2) cb(1)], ...
   'YData', [yl4(1) yl4(1) yl4(2) yl4(2)], 'FaceColor', cCycle, 'EdgeColor', 'none');
 set(hCyc, 'FaceAlpha', 0.13);
 plot(ax(4), [cb(1) cb(1)], yl4, '-', 'Color', cCycle, 'LineWidth', 1.2);
 plot(ax(4), [cb(2) cb(2)], yl4, '-', 'Color', cCycle, 'LineWidth', 1.2);
 text('Parent', ax(4), 'Position', [cb(1), yl4(1)], ...
   'String', sprintf('analysed gait cycle\nframes %d-%d (%.2f-%.2f s)', ...
   pts.window(1) - 1, pts.window(2) - 1, cb(1), cb(2)), ...
   'Color', cCycle, 'FontSize', 7.5, 'Interpreter', 'none', ...
   'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom', ...
   'BackgroundColor', 'w', 'Margin', 1);
 ylabel(ax(4), 'Ankle forward Z (m)', 'FontSize', 8.5);
 lg3 = legend([hL hR hHS hTO], ...
   {'Left ankle forward Z'; 'Right ankle forward Z'; ...
    'HS (heel strike, foot lands)'; 'TO (toe-off, foot lifts)'}, ...
   'Location', 'northeast', 'FontSize', 7, 'Interpreter', 'none');
 set(lg3, 'NumColumns', 2);
 set(lg3, 'AutoUpdate', 'off');

 % ---------------- panel 5: stage bar ----------------
 % one patch per stage is ALWAYS created (a degenerate stage just gets a
 % zero-width patch) so gait.interactiveTUG can update its XData on drag.
 H.stage = gobjects(1, numel(SG.order));
 H.stageNum = gobjects(1, numel(SG.order));
 legTxt = {}; hLeg = [];
for s = 1:numel(SG.order)
  key = SG.order{s};
  b = SG.bounds.(key);
  H.stage(s) = patch('Parent', ax(5), 'XData', [b(1) b(2) b(2) b(1)], ...
    'YData', [0.30 0.30 0.92 0.92], 'FaceColor', SG.colors.(key), ...
    'EdgeColor', 'w', 'LineWidth', 0.9);
  if b(2) <= b(1), continue; end
  H.stageNum(s) = text('Parent', ax(5), 'Position', [(b(1) + b(2)) / 2, 0.61], ...
    'String', num2str(s), 'FontSize', 8, 'FontWeight', 'bold', ...
    'Color', [0.13 0.13 0.13], 'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'middle', 'Interpreter', 'none');
  legTxt{end + 1} = sprintf('%d. %s   %.2f-%.2f s  (%.2f s, %.1f%%)', ...
    s, SG.labels.(key), b(1), b(2), SG.durations.(key), SG.pct.(key));
  hLeg(end + 1) = H.stage(s);
end
hLeg = hLeg(isgraphics(hLeg));
if ~isempty(hLeg)
  xlim(ax(5), [0 tug_s]);
  ylim(ax(5), [0.05 1.05]);
  set(ax(5), 'YTick', []);
  ylabel(ax(5), 'TUG stages', 'FontSize', 8.5);
  xlabel(ax(5), 'Time (s)');
  lg4 = legend(hLeg, legTxt, 'Location', 'southoutside', 'FontSize', 7.2, ...
    'Interpreter', 'none', 'Box', 'off');
  set(lg4, 'NumColumns', 2);
  set(lg4, 'AutoUpdate', 'off');
  set(ax(5), 'Position', pos(5, :));
  set(lg4, 'Units', 'normalized');
  p4 = get(ax(5), 'Position');
  set(lg4, 'Position', [p4(1), p4(2) - 0.105, p4(3), 0.085]);
end

 % ---------------- title ----------------
 annotation(fig, 'textbox', [0.02 0.955 0.96 0.042], 'String', ...
   sprintf(['Full TUG trial overview - sit -> stand -> walk out -> turn -> walk back -> sit down\n' ...
   'N=%d frames, %.0f fps, TUG time = %.2f s   |   shaded bands = the five TUG stages   |   ' ...
   'black lines = analysed cycle [L.HS, L.HS2]'], N, fs, tug_s), ...
   'HorizontalAlignment', 'center', 'Interpreter', 'none', ...
   'FontSize', 9.5, 'EdgeColor', 'none', 'VerticalAlignment', 'middle');

 % axes handles last (ax(5) Position was re-set above)
 H.ax = ax;

 if ~isempty(outPath)
   print(fig, outPath, '-dpng', '-r130');
 end
end

% -------------------------------------------------------------------------
function hp = shadeStages(ax, SG, alpha, yl)
% Draw one translucent band per TUG stage across the full y range of ax.
% Returns the patch handles so a caller can move them (gait.interactiveTUG).
 hp = gobjects(1, numel(SG.order));
 for s = 1:numel(SG.order)
   key = SG.order{s};
   b = SG.bounds.(key);
   if b(2) <= b(1), continue; end
   hp(s) = patch('Parent', ax, 'XData', [b(1) b(2) b(2) b(1)], ...
     'YData', [yl(1) yl(1) yl(2) yl(2)], ...
     'FaceColor', SG.colors.(key), 'EdgeColor', 'none');
   set(hp(s), 'FaceAlpha', alpha);
   uistack(hp(s), 'bottom');
 end
 ylim(ax, yl);
end
