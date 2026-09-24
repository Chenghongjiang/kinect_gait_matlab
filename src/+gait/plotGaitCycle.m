function plotGaitCycle(pts, P, outPath)
%plotGaitCycle Ankle forward trajectory with gait events and double-support bands.
% Top panel : ankle forward (depth) trajectory; markers o=HS ^=TO s=HS2.
% Bottom : relF = ankleFwd - CoMF used for event detection.
%
% The analysed cycle is the LEFT stride [L.HS, L.HS2]. Its two double-support
% intervals (initial + terminal) are shaded; the right foot's own stride
% [R.HS, R.HS2] is marked with dashed lines, because R.TO and R.HS2 belong to
% that (later) cycle rather than to the shaded one.
%
% If outPath is given, the figure is saved as PNG.

 t = pts.t;
 aFL = pts.ankleFwdL; aFR = pts.ankleFwdR;
 L = pts.L; R = pts.R;
 cL = [0.84 0.15 0.15];
 cR = [0.12 0.47 0.71];
 cG = [0.25 0.25 0.25];
 cDS = [1 0.6 0];

 x0 = P.cycle_bounds(1) - 0.35;
 x1 = P.right_cycle_bounds(2) + 0.35;

 figure('Position', [100 100 1040 680]);

 % ---- top panel : forward trajectory ----
 ax1 = subplot(2, 1, 1); hold on; grid on;
 hL = plot(t, aFL, 'Color', cL, 'LineWidth', 1.4);
 hR = plot(t, aFR, 'Color', cR, 'LineWidth', 1.4);
 xlim([x0 x1]);
 plotMarkers(L, cL, true);
 plotMarkers(R, cR, true);
 yl = ylim;
 p1 = axvspan(P.ds_init(1), P.ds_init(2), cDS, 0.42);
 p2 = axvspan(P.ds_term(1), P.ds_term(2), cDS, 0.42);
 plot([P.cycle_bounds(1) P.cycle_bounds(1)], yl, '-', 'Color', cG, 'LineWidth', 1.1);
 plot([P.cycle_bounds(2) P.cycle_bounds(2)], yl, '-', 'Color', cG, 'LineWidth', 1.1);
 plot([P.right_cycle_bounds(1) P.right_cycle_bounds(1)], yl, '--', 'Color', cR, 'LineWidth', 1.0);
 plot([P.right_cycle_bounds(2) P.right_cycle_bounds(2)], yl, '--', 'Color', cR, 'LineWidth', 1.0);
 text(P.ds_term(2), yl(2) * 0.97, ...
 sprintf('double support (initial+terminal) = %.1f%% of the cycle', P.Double_support), ...
 'Color', [0.64 0.35 0], 'HorizontalAlignment', 'right', 'FontSize', 8, ...
 'Interpreter', 'none');
 xlim([x0 x1]);
 title(['Ankle forward trajectory & gait events (6-point, outbound cycle)' newline ...
 'o=HS ^=TO s=HS2; solid = analysed cycle [L.HS, L.HS2]; dashed = right foot''s own stride; orange = double support'], ...
 'Interpreter', 'none');
 ylabel('Forward Z (m, vs initial CoM)');
 legend([hL, hR, p1], {'Left ankle forward Z', 'Right ankle forward Z', ...
 'Double support (both feet on ground)'}, 'Location', 'northeast', 'FontSize', 8);

 % ---- bottom panel : relF ----
 subplot(2, 1, 2); hold on; grid on;
 hL2 = plot(t, pts.relL, 'Color', cL, 'LineWidth', 1.0);
 hR2 = plot(t, pts.relR, 'Color', cR, 'LineWidth', 1.0);
 xlim([x0 x1]);
 plotRel(L, pts.comF, cL);
 plotRel(R, pts.comF, cR);
 yl2 = ylim;
 axvspan(P.ds_init(1), P.ds_init(2), cDS, 0.30);
 axvspan(P.ds_term(1), P.ds_term(2), cDS, 0.30);
 plot([P.cycle_bounds(1) P.cycle_bounds(1)], yl2, '-', 'Color', cG, 'LineWidth', 1.1);
 plot([P.cycle_bounds(2) P.cycle_bounds(2)], yl2, '-', 'Color', cG, 'LineWidth', 1.1);
 plot(xlim, [0 0], 'k-', 'LineWidth', 0.6);
 xlim([x0 x1]);
 xlabel('Time (s)'); ylabel('relF = ankleFwd - CoMF (m)');
 legend([hL2, hR2], {'L ankle relF', 'R ankle relF'}, 'Location', 'northeast', 'FontSize', 8);

 if nargin > 2 && ~isempty(outPath)
 print(gcf, outPath, '-dpng', '-r150');
 end
end

% -------------------------------------------------------------------------
function plotMarkers(S, col, doLabel)
 plot(S.HS(2), S.HS(3), 'o', 'MarkerSize', 9, 'Color', col);
 plot(S.TO(2), S.TO(3), '^', 'MarkerSize', 9, 'MarkerFaceColor', 'none', 'Color', col);
 plot(S.HS2(2), S.HS2(3), 's', 'MarkerSize', 8, 'Color', col);
 if doLabel
 text(S.HS(2) + 0.02, S.HS(3) + 0.14, 'HS', 'Color', col, 'FontSize', 7, 'Interpreter', 'none');
 text(S.TO(2) + 0.02, S.TO(3) - 0.24, 'TO', 'Color', col, 'FontSize', 7, 'Interpreter', 'none');
 text(S.HS2(2) + 0.02, S.HS2(3) + 0.14, 'HS2', 'Color', col, 'FontSize', 7, 'Interpreter', 'none');
 end
end

% -------------------------------------------------------------------------
function plotRel(S, comF, col)
 i = S.HS(1); plot(S.HS(2), S.HS(3) - comF(i), 'o', 'MarkerSize', 7, 'Color', col);
 i = S.TO(1); plot(S.TO(2), S.TO(3) - comF(i), '^', 'MarkerSize', 7, 'MarkerFaceColor', 'none', 'Color', col);
 i = S.HS2(1); plot(S.HS2(2), S.HS2(3) - comF(i), 's', 'MarkerSize', 6, 'Color', col);
end

% -------------------------------------------------------------------------
function h = axvspan(x1, x2, col, alpha)
 yl = ylim;
 h = patch('XData', [x1 x2 x2 x1], 'YData', [yl(1) yl(1) yl(2) yl(2)], ...
 'FaceColor', toRGB(col), 'EdgeColor', 'none');
 set(h, 'FaceAlpha', alpha);
 uistack(h, 'bottom');
end

function rgb = toRGB(col)
 % Accept either an RGB triplet or a '#RRGGBB' hex string: R2021b patch does
 % not accept hex strings positionally (S.colors.* are hex by design).
 if ischar(col) || isstring(col)
 c = char(col);
 if ~isempty(c) && c(1) == '#', c = c(2:end); end
 rgb = sscanf(c, '%2x%2x%2x', [1 3]) / 255;   % 1x3 RGB row
 else
 rgb = col;
 end
end
