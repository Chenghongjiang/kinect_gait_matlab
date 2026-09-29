function out = interactiveTUG(data, outDir)
%interactiveTUG Human-in-the-loop TUG segmentation (drag lines + Apply).
%
% gait.interactiveTUG()            use the bundled sample recording
% gait.interactiveTUG(data)        struct from gait.loadKinect
% gait.interactiveTUG(csvPath)     path to a Kinect CSV recording
% gait.interactiveTUG(data, outDir) also choose the output folder
%
% Workflow:
%  1. the automatic pipeline runs once and the Full TUG trial overview is
%     drawn (same 5-panel figure as example_gait_analysis),
%  2. four draggable vertical lines are overlaid on ALL five panels:
%       green  stand-up complete (i_stand)
%       orange turn start        (turn_lo)
%       red    turn end          (turn_hi)
%       brown  sit-down starts   (i_sit)
%  3. while a line is dragged the five stage bands, the turn window and the
%     stage colour bar follow it in real time (cheap preview: gait.tugSegments
%     only needs the boundary frames, no re-detection during the drag),
%  4. Apply re-runs the WHOLE pipeline from the manual boundaries (cycle
%     candidate filtering, scoring, parameters, support phases, stage table)
%     and saves the full set of CSVs + PNGs into outDir - exactly the same
%     files as example_gait_analysis writes, so results stay comparable,
%  5. Reset restores the automatic boundaries.
%
% The manual boundaries enter the pipeline through the segOverride argument
% of gait.extractCyclePoints: they replace ONLY the four stage frames, every
% downstream rule is unchanged (no re-tuning, no special cases).
%
% Frame indices are 1-based inside this toolbox; every frame number shown on
% screen / written to a CSV is the 0-based export convention.
%
% Returns out = struct('fig','pts','P','S','SG') with the state after the
% last successful Apply / Reset.

 if nargin < 1, data = []; end
 if nargin < 2 || isempty(outDir)
   pkgDir = fileparts(mfilename('fullpath'));        % .../src/+gait
   outDir = fullfile(pkgDir, '..', '..', 'outputs');
 end
 if isempty(data)
   pkgDir = fileparts(mfilename('fullpath'));
   data = gait.loadKinect(fullfile(pkgDir, '..', '..', 'data', 'sample_TUG_gait.csv'));
 elseif ischar(data) || isstring(data)
   data = gait.loadKinect(data);
 end
 fs = data.fs;
 N = data.N;
 tug_s = N / fs;

 KEYS = {'i_stand', 'turn_lo', 'turn_hi', 'i_sit'};
 NAMES = {'stand-up', 'turn start', 'turn end', 'sit-down'};
 COLS = [0.16 0.50 0.20;   % green  - stand-up complete
   0.90 0.32 0.00;   % orange - turn start
   0.84 0.15 0.15;   % red    - turn end
   0.42 0.22 0.10];  % brown  - sit-down starts

 % ---- shared state (parent workspace, used by the nested functions) ----
 % NOTE: never call struct() with [] or non-scalar values - struct([]) builds
 % a 0x0 struct array and struct(x, gobjects(4,5)) a 4x5 array, both of which
 % break later dot assignment. Fill the fields one by one instead.
 pts = []; P = []; S = []; SG = []; H = [];
 nan4 = struct('i_stand', NaN, 'turn_lo', NaN, 'turn_hi', NaN, 'i_sit', NaN);
 st = struct('v', nan4, 'auto', nan4);
 UI.busy = false;
 UI.status = []; UI.btnApply = []; UI.btnReset = [];
 UI.lines = gobjects(4, 5);
 UI.hits = gobjects(4, 5);
 UI.lbls = gobjects(4, 1);
 out = struct('fig', NaN, 'pts', NaN, 'P', NaN, 'S', NaN, 'SG', NaN);

 fig = figure('Name', 'Interactive TUG segmentation - drag lines, then Apply', ...
   'NumberTitle', 'off', 'MenuBar', 'none', 'ToolBar', 'none', ...
   'Color', 'w', 'Position', [80 60 1280 980]);

 if ~runPipeline([])
   close(fig);
   error('interactiveTUG:noCycle', ...
     'automatic detection found no usable gait cycle in this trial');
 end
 st.auto = pick4(pts.seg);
 st.v = st.auto;

 redrawAll();
 addButtons();
 addDraggables();
 drawnow;

 fprintf('[interactiveTUG] automatic boundaries (1-based frames): i_stand=%d, turn_lo=%d, turn_hi=%d, i_sit=%d\n', ...
   st.v.i_stand, st.v.turn_lo, st.v.turn_hi, st.v.i_sit);
 fprintf('[interactiveTUG] drag the four lines, then press Apply. Outputs -> %s\n', outDir);

 % =========================================================================
 % nested functions (share the parent workspace)
 % =========================================================================

 function ok = runPipeline(segO)
  % full pipeline from the current data; segO = manual boundaries (or [])
  ok = false;
  pts2 = gait.extractCyclePoints(data, 5.0, 4, 0.6, 0.04, segO);
  if isempty(pts2), return; end
  pts = pts2;
  P = gait.computeParamsFromPoints(pts, N / fs);
  S = gait.stancePhases(pts);
  SG = gait.tugSegments(pts, data);
  out = struct('fig', fig, 'pts', pts, 'P', P, 'S', S, 'SG', SG);
  ok = true;
 end

 function redrawAll()
  % rebuild the whole overview inside the existing figure
  H = gait.plotTugOverview(data, pts, P, SG, '', fig);
 end

 function addButtons()
  % status bar + Apply / Reset (clf reset wiped them -> re-add after redraw)
  UI.status = uicontrol(fig, 'Style', 'text', 'Units', 'normalized', ...
    'Position', [0.084 0.012 0.62 0.030], 'HorizontalAlignment', 'left', ...
    'FontSize', 9, 'BackgroundColor', 'w', 'String', '');
  UI.btnReset = uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
    'Position', [0.785 0.008 0.070 0.034], 'String', 'Reset', 'FontSize', 9, ...
    'TooltipString', 'restore the automatic boundaries', 'Callback', @onReset);
  UI.btnApply = uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
    'Position', [0.868 0.008 0.120 0.034], 'String', 'Apply', ...
    'FontWeight', 'bold', 'FontSize', 10, ...
    'TooltipString', 're-run the full pipeline from the current boundaries and save', ...
    'Callback', @onApply);
 end

 function addDraggables()
  % one visible + one wide invisible (hit-area) line per boundary per panel,
  % plus a small frame/time label at the top of panel 1
  UI.lines = gobjects(4, 5);
  UI.hits = gobjects(4, 5);
  UI.lbls = gobjects(4, 1);
  for k = 1:4
    for p = 1:5
      yy = ylim(H.ax(p));
      UI.lines(k, p) = line('Parent', H.ax(p), 'XData', [0 0], ...
        'YData', yy, 'Color', COLS(k, :), 'LineWidth', 1.5, ...
        'ButtonDownFcn', @(src, evt)beginDrag(k));
      UI.hits(k, p) = line('Parent', H.ax(p), 'XData', [0 0], ...
        'YData', yy, 'Color', 'none', 'LineWidth', 9, ...
        'ButtonDownFcn', @(src, evt)beginDrag(k));
    end
    UI.lbls(k) = text('Parent', H.ax(1), 'Position', [0 0 0], 'String', '', ...
      'Color', COLS(k, :), 'FontSize', 7, 'Interpreter', 'none', ...
      'BackgroundColor', 'w', 'Margin', 0.5);
  end
  updateDynamic();
 end

 function updateDynamic()
  % preview stage geometry from the CURRENT boundaries (tugSegments needs
  % only pts.seg + pts.t, so this stays smooth during the drag)
  segPrev = pts.seg;
  for k = 1:4
    segPrev.(KEYS{k}) = st.v.(KEYS{k});
  end
  prevPts = struct();
  prevPts.seg = segPrev;
  prevPts.t = pts.t;
  SGp = gait.tugSegments(prevPts, data);

  for s = 1:5
    key = SGp.order{s};
    b = SGp.bounds.(key);
    for p = 1:4
      if isgraphics(H.bands{p}(s))
        set(H.bands{p}(s), 'XData', [b(1) b(2) b(2) b(1)]);
      end
    end
    set(H.stage(s), 'XData', [b(1) b(2) b(2) b(1)]);
    if isgraphics(H.stageNum(s))
      set(H.stageNum(s), 'Position', [(b(1) + b(2)) / 2, 0.61, 0]);
    end
  end
  if isgraphics(H.turnWin)
    bt = SGp.bounds.turn;
    set(H.turnWin, 'XData', [bt(1) bt(2) bt(2) bt(1)]);
  end

  % move the lines + panel-1 labels
  yl1 = ylim(H.ax(1));
  ytop = yl1(2);
  yrange = max(eps, yl1(2) - yl1(1));
  for k = 1:4
    fr = st.v.(KEYS{k});
    tt = (fr - 1) / fs;
    for p = 1:5
      yy = ylim(H.ax(p));
      if isgraphics(UI.lines(k, p))
        set(UI.lines(k, p), 'XData', [tt tt], 'YData', yy);
      end
      if isgraphics(UI.hits(k, p))
        set(UI.hits(k, p), 'XData', [tt tt], 'YData', yy);
      end
    end
    if isgraphics(UI.lbls(k))
      if tt < tug_s / 2
        ha = 'left'; xoff = 0.02 * tug_s;
      else
        ha = 'right'; xoff = -0.02 * tug_s;
      end
      set(UI.lbls(k), 'Position', [tt + xoff, ytop - (k - 1) * 0.055 * yrange, 0], ...
        'String', sprintf('%s: %.2f s (frame %d)', NAMES{k}, tt, fr - 1), ...
        'HorizontalAlignment', ha, 'VerticalAlignment', 'top');
    end
  end

  if isequal(st.v, st.auto)
    set(UI.status, 'String', ...
      'boundaries: automatic detection  |  drag a line to adjust, then press Apply  |  Reset restores automatic', ...
      'ForegroundColor', [0.15 0.15 0.15]);
  else
    set(UI.status, 'String', ...
      'boundaries: MODIFIED (not applied yet)  |  Apply re-runs the pipeline and saves all CSVs + PNGs', ...
      'ForegroundColor', [0.70 0.35 0.00]);
  end
 end

 function beginDrag(k)
  if UI.busy, return; end
  set(fig, 'Pointer', 'fleur', ...
    'WindowButtonMotionFcn', @(src, evt)onDrag(k), ...
    'WindowButtonUpFcn', @(src, evt)endDrag());
 end

 function onDrag(k)
  fr = pointerToFrame();
  st.v.(KEYS{k}) = clampVal(k, fr);
  updateDynamic();
 end

 function endDrag()
  set(fig, 'Pointer', 'arrow', 'WindowButtonMotionFcn', '', 'WindowButtonUpFcn', '');
 end

 function fr = pointerToFrame()
  % figure CurrentPoint (normalized) -> time via the panel-1 axes position
  u0 = get(fig, 'Units');
  set(fig, 'Units', 'normalized');
  cp = get(fig, 'CurrentPoint');
  set(fig, 'Units', u0);
  axPos = get(H.ax(1), 'Position');   % [left bottom width height]
  tt = (cp(1) - axPos(1)) / axPos(3) * tug_s;
  fr = round(tt * fs) + 1;
  fr = min(max(fr, 2), N - 1);
 end

 function v = clampVal(k, fr)
  % keep the four boundaries ordered: i_stand < turn_lo <= turn_hi < i_sit
  v = min(max(fr, 2), N - 1);
  switch KEYS{k}
    case 'i_stand'
      v = min(v, st.v.turn_lo - 1);
    case 'turn_lo'
      v = max(v, st.v.i_stand + 1);
      v = min(v, st.v.turn_hi);
    case 'turn_hi'
      v = max(v, st.v.turn_lo);
      v = min(v, st.v.i_sit - 1);
    case 'i_sit'
      v = max(v, st.v.turn_hi + 1);
      v = min(v, N - 1);
  end
 end

 function onApply(src, evt) %#ok<INUSD>
  if UI.busy, return; end
  UI.busy = true;
  try
    if ~runPipeline(st.v)
      error('interactiveTUG:noCycle', ...
        'no usable gait cycle for the current manual boundaries');
    end
    st.v = pick4(pts.seg);   % the rounded frames actually used by the pipeline
    redrawAll();
    addButtons();
    addDraggables();
    saveOutputs();
    set(UI.status, 'String', sprintf(['APPLIED - boundaries frame %d / %d / %d / %d ' ...
      '(0-based) saved to outputs'], ...
      st.v.i_stand - 1, st.v.turn_lo - 1, st.v.turn_hi - 1, st.v.i_sit - 1), ...
      'ForegroundColor', [0.00 0.45 0.00]);
  catch ME
    set(UI.status, 'String', ['Apply failed: ' ME.message], ...
      'ForegroundColor', [0.75 0.10 0.10]);
  end
  UI.busy = false;
 end

 function onReset(src, evt) %#ok<INUSD>
  if UI.busy, return; end
  UI.busy = true;
  try
    if runPipeline(st.auto)   % deterministic: identical to the first auto run
      st.v = st.auto;         % drag lines snap back to the automatic frames too
      redrawAll();
      addButtons();
      addDraggables();
      set(UI.status, 'String', ...
        'RESET - automatic boundaries restored (nothing re-saved)', ...
        'ForegroundColor', [0.15 0.15 0.15]);
      fprintf('[interactiveTUG] reset to automatic boundaries\n');
    end
  catch ME
    set(UI.status, 'String', ['Reset failed: ' ME.message], ...
      'ForegroundColor', [0.75 0.10 0.10]);
  end
  UI.busy = false;
 end

 function saveOutputs()
  % the same five CSVs + five PNGs as example_gait_analysis, from the state
  % of the last successful pipeline run
  if ~exist(outDir, 'dir'), mkdir(outDir); end
  L = pts.L; R = pts.R;

  % ---- cycle6_points.csv ----
  sides = {'L'; 'R'; 'L'; 'R'; 'L'; 'R'};
  evs = {'HS'; 'HS'; 'TO'; 'TO'; 'HS2'; 'HS2'};
  fr = [L.HS(1); R.HS(1); L.TO(1); R.TO(1); L.HS2(1); R.HS2(1)] - 1;
  tm = round([L.HS(2); R.HS(2); L.TO(2); R.TO(2); L.HS2(2); R.HS2(2)], 4);
  zz = round([L.HS(3); R.HS(3); L.TO(3); R.TO(3); L.HS2(3); R.HS2(3)], 4);
  T6 = table(sides, evs, fr, tm, zz, ...
    'VariableNames', {'side', 'event', 'frame', 'time_s', 'forward_Z_m'});
  T6 = [T6; table({'R'}, {'TO_prev'}, R.TO_prev(1) - 1, round(R.TO_prev(2), 4), ...
    round(R.TO_prev(3), 4), ...
    'VariableNames', {'side', 'event', 'frame', 'time_s', 'forward_Z_m'})];
  T6 = [T6; table({'BOTH'; 'BOTH'; 'BOTH'; 'BOTH'}, ...
    {'DS_initial_start'; 'DS_initial_end'; 'DS_terminal_start'; 'DS_terminal_end'}, ...
    NaN(4, 1), round([P.ds_init(1); P.ds_init(2); P.ds_term(1); P.ds_term(2)], 4), ...
    NaN(4, 1), ...
    'VariableNames', {'side', 'event', 'frame', 'time_s', 'forward_Z_m'})];
  writetable(T6, fullfile(outDir, 'cycle6_points.csv'));

  % ---- gait_parameters.csv ----
  paramNames = {'Step Speed (m/s)', 'Cadence (steps/min)', 'Stride length (m)', ...
    'Left stride length (m)', 'Right stride length (m)', ...
    'Left single-limb support (%)', 'Right single-limb support (%)', ...
    'Single-limb support (%)', 'Double-limb support (%)', ...
    'Double-limb support (per stride) (%)', 'Stride time (s)', ...
    'Swing phase velocity (m/s)', 'TUG time (s)', ...
    'Avg single-limb support (%)', 'Avg double-limb support (%)'};
  lkeys = {'Step_Speed', 'Cadence', 'Stride_length', ...
    'Left_stride_length', 'Right_stride_length', ...
    'Left_single_support', 'Right_single_support', ...
    'Single_support', 'Double_support', ...
    'Double_support_per_stride', 'Stride_time', ...
    'Swing_velocity', 'TUG_time', ...
    'Avg_single_support', 'Avg_double_support'};
  units = {'m/s', 'steps/min', 'm', 'm', 'm', '%', '%', '%', '%', '%', 's', 'm/s', 's', ...
    '%', '%'};
  Tp = table(paramNames', cellfun(@(k) P.(k), lkeys'), units', ...
    'VariableNames', {'Parameter', 'Value', 'Unit'});
  writetable(Tp, fullfile(outDir, 'gait_parameters.csv'));

  % ---- stance_phases.csv ----
  phaseNames = {}; starts = []; ends = []; durs = []; pcts = [];
  for k = 1:numel(S.order)
    key = S.order{k};
    phaseNames{end + 1, 1} = S.labels.(key);
    starts(end + 1, 1) = S.phases.(key)(1);
    ends(end + 1, 1) = S.phases.(key)(2);
    durs(end + 1, 1) = S.durations.(key);
    pcts(end + 1, 1) = S.pct.(key);
  end
  writetable(table(phaseNames, starts, ends, durs, pcts, ...
    'VariableNames', {'phase', 'start_s', 'end_s', 'duration_s', 'pct_of_cycle'}), ...
    fullfile(outDir, 'stance_phases.csv'));

  % ---- tug_segments.csv ----
  writetable(SG.T, fullfile(outDir, 'tug_segments.csv'));

  % ---- gait_events.csv ----
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

  % ---- figures (each one re-created off to the side, then closed) ----
  figsBefore = findall(0, 'Type', 'figure');
  try
    gait.plotTugOverview(data, pts, P, SG, fullfile(outDir, 'fig_tug_overview.png'));
    gait.plotGaitCycle(pts, P, fullfile(outDir, 'fig_cycle6_points.png'));
    gait.plotCycleWithPhases(pts, P, S, fullfile(outDir, 'fig_cycle6_points_with_phases.png'));
    gait.plotStancePhases(pts, S, fullfile(outDir, 'fig_stance_phases.png'), false);
    gait.plotStancePhases(pts, S, fullfile(outDir, 'fig_stance_phases_pct.png'), true);
  catch ME
    fprintf('[interactiveTUG] figures skipped: %s\n', ME.message);
  end
  delete(setdiff(findall(0, 'Type', 'figure'), [figsBefore; fig]));

  % ---- console summary ----
  fprintf('[interactiveTUG] saved CSVs + PNGs -> %s\n', outDir);
  fprintf('[interactiveTUG] stages:\n');
  for i = 1:numel(SG.order)
    k2 = SG.order{i};
    b = SG.bounds.(k2);
    fprintf('   %d. %-22s %6.2f-%-6.2f s  %5.2f s (%5.1f%%)\n', ...
      i, SG.labels.(k2), b(1), b(2), SG.durations.(k2), SG.pct.(k2));
  end
 end

 function s4 = pick4(seg)
  s4 = struct('i_stand', seg.i_stand, 'turn_lo', seg.turn_lo, ...
    'turn_hi', seg.turn_hi, 'i_sit', seg.i_sit);
 end

end
