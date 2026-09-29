function plotStancePhases(pts, S, outPath, usePct)
%plotStancePhases Bar chart of the four support phases in a gait cycle.
% If outPath is supplied, the figure is saved as a PNG.
% usePct = true -> x-axis = % of gait cycle
% usePct = false -> x-axis = absolute time (default)
% Only uses base MATLAB + patch (no optional toolboxes).

 if nargin < 4, usePct = false; end
 t0 = S.phases.initial_DS(1);
 t4 = S.phases.right_SS(2);
 cycle = S.cycle_s;
 L = pts.L; R = pts.R;

 conv = @(x) 100 * (x - t0) / cycle * usePct + x * ~usePct;
 xEnd = 100 * usePct + t4 * ~usePct;

 figure('Position', [100 100 1000 380]);
 ax = gca; hold on; grid on;

 % helper: draw a filled horizontal bar at (x0,w), lane (y0,h)
 barPatch = @(x0, w, y0, h, col) patch(ax, [x0 x0+w x0+w x0], ...
 [y0 y0 y0+h y0+h], col, 'EdgeColor', 'none');

 % four support-phase bars
 for k = 1:numel(S.order)
 key = S.order{k};
 x0 = conv(S.phases.(key)(1));
 x1 = conv(S.phases.(key)(2));
 w = max(0, x1 - x0);
 col = hex2rgb(S.colors.(key));
 barPatch(x0, w, 2.0, 0.8, col);
 xc = (x0 + x1) / 2;
 label = sprintf('%s\n%.3f s (%.1f%%)', S.labels.(key), S.durations.(key), S.pct.(key));
 text(xc, 2.4, label, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
 'FontSize', 7.5, 'Color', 'white', 'FontWeight', 'bold');
 end

 % left foot contact [t0, L.TO]
 lx1 = conv(L.TO(2));
 barPatch(conv(t0), max(0, lx1 - conv(t0)), 1.0, 0.6, [0.84 0.15 0.15]);

 % right foot contact: previous step tail [t0, t1] + this step [R.HS, R.TO]
 t1 = S.phases.initial_DS(2);
 rx1 = conv(min(t1, t4));
 barPatch(conv(t0), max(0, rx1 - conv(t0)), 0.2, 0.6, [0.12 0.47 0.71]);
 rx2 = conv(R.HS(2));
 rx3 = conv(min(R.TO(2), t4));
 barPatch(rx2, max(0, rx3 - rx2), 0.2, 0.6, [0.12 0.47 0.71]);

 % outer border around support-phase lane
 xL = conv(t0); xR = xEnd;
 plot(ax, [xL xL xR xR xL], [2.0 2.8 2.8 2.0 2.0], 'k-', 'LineWidth', 0.8);

 ax.YTick = [0.5 1.3 2.4];
 ax.YTickLabel = {'Right foot contact', 'Left foot contact', 'Support phase'};
 ax.YLim = [0 3.1];
 ax.XLim = [conv(t0) - (2 * usePct + 0.02 * ~usePct), xEnd + (2 * usePct + 0.02 * ~usePct)];
 if usePct
 xlabel('% of gait cycle');
 else
 xlabel('Time (s)');
 end
 title(sprintf('Stance / support phases within the selected gait cycle (frames %d-%d, %.3f s)', ...
 S.window_frames(1), S.window_frames(2), cycle));

 % legend
 n = numel(S.order);
 leg = cell(1, n);
 for k = 1:n
 leg{k} = S.labels.(S.order{k});
 end
 legend(leg, 'Location', 'south', 'Orientation', 'horizontal', 'FontSize', 7.5);

 if nargin > 2 && ~isempty(outPath)
 print(gcf, outPath, '-dpng', '-r150');
 end
end

function rgb = hex2rgb(hex)
 if hex(1) == '#', hex = hex(2:end); end
 rgb = sscanf(hex, '%2x%2x%2x', [1 3]) / 255;
end
