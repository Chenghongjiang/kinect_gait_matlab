function plotCycleWithPhases(pts, P, S, outPath)
%plotCycleWithPhases Ankle trajectory + 6 key points + 4 support phase bands.
%
% The 6 key points span TWO staggered strides: each foot's HS/TO/HS2 is
% measured on that foot's OWN stride, and the left/right strides are half a
% cycle apart. The four support phases, by contrast, describe ONE cycle -
% the left stride [L.HS, L.HS2].
%
% The figure marks both windows explicitly so it is unambiguous which event
% drives which quantity:
%   solid vertical lines  : the analysed cycle [L.HS, L.HS2] (phase bands)
%   dashed vertical lines : the right foot's own stride [R.HS, R.HS2],
%                           which is where R.TO and R.HS2 belong
%   diamond R.TO_prev     : the right toe-off the phase bands actually use
%                           (a different event from R.TO)
%
% Saves PNG if outPath is provided.

 t = pts.t;
 aFL = pts.ankleFwdL; aFR = pts.ankleFwdR;
 L = pts.L; R = pts.R;
 order = S.order;
 cL = [0.84 0.15 0.15];
 cR = [0.12 0.47 0.71];
 cG = [0.25 0.25 0.25];
 cP = [0.55 0.10 0.60];

 x0 = P.cycle_bounds(1) - 0.25;
 x1 = P.right_cycle_bounds(2) + 0.25;

 figure('Position', [80 60 1120 800]);

 % ---------------- top: ankle forward trajectory ----------------
 ax1 = subplot(2, 1, 1); hold on; grid on;
 hL = plot(t, aFL, 'Color', cL, 'LineWidth', 1.4);
 hR = plot(t, aFR, 'Color', cR, 'LineWidth', 1.4);
 xlim([x0 x1]);
 plotCycleMarkers(L, cL, 'L', true);
 plotCycleMarkers(R, cR, 'R', true);
 plot(R.TO_prev(2), R.TO_prev(3), 'd', 'MarkerSize', 8, ...
 'MarkerFaceColor', 'none', 'Color', cP, 'LineWidth', 1.2);
 text(R.TO_prev(2) + 0.03, R.TO_prev(3) + 0.34, 'R.TO_prev', ...
 'Color', cP, 'FontSize', 7, 'Interpreter', 'none');
 yl = ylim;
 plot([P.cycle_bounds(1) P.cycle_bounds(1)], yl, '-', 'Color', cG, 'LineWidth', 1.1);
 plot([P.cycle_bounds(2) P.cycle_bounds(2)], yl, '-', 'Color', cG, 'LineWidth', 1.1);
 plot([P.right_cycle_bounds(1) P.right_cycle_bounds(1)], yl, '--', 'Color', cR, 'LineWidth', 1.0);
 plot([P.right_cycle_bounds(2) P.right_cycle_bounds(2)], yl, '--', 'Color', cR, 'LineWidth', 1.0);
 p1 = [];
 for k = 1:numel(order)
 kk = order{k};
 p1(k) = axvspan(S.phases.(kk)(1), S.phases.(kk)(2), S.colors.(kk), 0.26);
 end
 xlim([x0 x1]);
 ylabel('Forward Z (m, vs initial CoM)');
 title(['Ankle forward trajectory, 6 key points & stance phases (outbound cycle)' newline ...
 'solid = analysed cycle [L.HS, L.HS2] (phase bands)   dashed = right foot''s own stride [R.HS, R.HS2]'], ...
 'Interpreter', 'none');
 legend([hL, hR, p1], {'Left ankle forward Z', 'Right ankle forward Z', ...
 S.labels.(order{1}), S.labels.(order{2}), S.labels.(order{3}), S.labels.(order{4})}, ...
 'Location', 'northeast', 'FontSize', 7.0);

 % ---------------- bottom: relF with the same events ----------------
 subplot(2, 1, 2); hold on; grid on;
 hL2 = plot(t, pts.relL, 'Color', cL, 'LineWidth', 1.0);
 hR2 = plot(t, pts.relR, 'Color', cR, 'LineWidth', 1.0);
 xlim([x0 x1]);
 plotRelMarkers(L, pts.comF, cL);
 plotRelMarkers(R, pts.comF, cR);
 yl2 = ylim;
 plot([P.cycle_bounds(1) P.cycle_bounds(1)], yl2, '-', 'Color', cG, 'LineWidth', 1.1);
 plot([P.cycle_bounds(2) P.cycle_bounds(2)], yl2, '-', 'Color', cG, 'LineWidth', 1.1);
 plot([P.right_cycle_bounds(1) P.right_cycle_bounds(1)], yl2, '--', 'Color', cR, 'LineWidth', 1.0);
 plot([P.right_cycle_bounds(2) P.right_cycle_bounds(2)], yl2, '--', 'Color', cR, 'LineWidth', 1.0);
 p2 = [];
 for k = 1:numel(order)
 kk = order{k};
 p2(k) = axvspan(S.phases.(kk)(1), S.phases.(kk)(2), S.colors.(kk), 0.20);
 end
 plot(xlim, [0 0], 'k-', 'LineWidth', 0.6);
 xlim([x0 x1]);
 xlabel('Time (s)'); ylabel('relF = ankleFwd - CoMF (m)');
 legend([hL2, hR2, p2], {'L ankle relF', 'R ankle relF', ...
 S.labels.(order{1}), S.labels.(order{2}), S.labels.(order{3}), S.labels.(order{4})}, ...
 'Location', 'northeast', 'FontSize', 7.0);

 if nargin > 3 && ~isempty(outPath)
 print(gcf, outPath, '-dpng', '-r150');
 end
end

% -------------------------------------------------------------------------
function plotCycleMarkers(S, col, tag, doLabel)
 plot(S.HS(2), S.HS(3), 'o', 'MarkerSize', 9, 'Color', col);
 plot(S.TO(2), S.TO(3), '^', 'MarkerSize', 9, 'MarkerFaceColor', 'none', 'Color', col);
 plot(S.HS2(2), S.HS2(3), 's', 'MarkerSize', 8, 'Color', col);
 if doLabel
 text(S.HS(2) + 0.02, S.HS(3) + 0.14, [tag '.HS'], ...
 'Color', col, 'FontSize', 7, 'Interpreter', 'none');
 text(S.TO(2) + 0.02, S.TO(3) - 0.24, [tag '.TO'], ...
 'Color', col, 'FontSize', 7, 'Interpreter', 'none');
 text(S.HS2(2) + 0.02, S.HS2(3) + 0.14, [tag '.HS2'], ...
 'Color', col, 'FontSize', 7, 'Interpreter', 'none');
 end
end

% -------------------------------------------------------------------------
function plotRelMarkers(S, comF, col)
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
