function SG = tugSegments(pts, data)
%tugSegments Split the WHOLE TUG trial into its five stages.
%
% Produces the same stage boundaries used throughout this toolbox.
% so both implementations report the same stage boundaries. The stages come
% straight from segmentTUG, nothing is re-detected here:
%
%   1 sit        frame 1        -> i_stand   sitting + stand-up
%   2 walk_out   i_stand        -> turn_lo   straight walk, outbound
%   3 turn       turn_lo        -> turn_hi   turning (excluded from detection)
%   4 walk_back  turn_hi        -> i_sit     straight walk, return
%   5 sit_down   i_sit          -> N         sit-down
%
% Only walk_out + walk_back feed event detection and every gait parameter;
% this helper just makes the excluded parts explicit (overview figure/table).
%
% Inputs
%   pts  : struct from extractCyclePoints (uses pts.seg and pts.t)
%   data : struct from loadKinect (for fs / N; optional)
%
% Returns
%   SG.order     cellstr, stage keys in time order
%   SG.labels    struct, human-readable label per key
%   SG.colors    struct, 1x3 RGB per key
%   SG.bounds    struct, [start_s end_s frame_lo frame_hi] per key
%   SG.durations struct, seconds per key
%   SG.pct       struct, % of the whole TUG per key
%   SG.tug_s     TUG duration (N / fs)
%   SG.note      char, non-empty when a stage is degenerate
%   SG.T         table (stage,label,frame_lo,frame_hi,start_s,end_s,
%                duration_s,pct_of_tug) ready for writetable

 if nargin < 2, data = []; end

 seg = pts.seg;
 t = pts.t(:);
 N = numel(t);
 if ~isempty(data) && isfield(data, 'fs')
   fs = data.fs;
 else
   fs = 1 / median(diff(t));
 end
 tug_s = N / fs;

 i_stand = seg.i_stand; i_sit = seg.i_sit;
 turn_lo = seg.turn_lo; turn_hi = seg.turn_hi;

 note = '';
 if turn_hi <= turn_lo
   note = 'no clear turn detected - the turn stage is empty';
 end

 SG.order = {'sit', 'walk_out', 'turn', 'walk_back', 'sit_down'};
 SG.labels.sit = 'Sitting / stand-up';
 SG.labels.walk_out = 'Walk out (straight)';
 SG.labels.turn = 'Turn (excluded)';
 SG.labels.walk_back = 'Walk back (straight)';
 SG.labels.sit_down = 'Sit down';

 SG.colors.sit = [0.565 0.643 0.682];   % #90A4AE
 SG.colors.walk_out = [0.400 0.733 0.416];   % #66BB6A
 SG.colors.turn = [1.000 0.655 0.149];   % #FFA726
 SG.colors.walk_back = [0.259 0.647 0.961];   % #42A5F5
 SG.colors.sit_down = [0.553 0.431 0.388];   % #8D6E63

 f0 = [1, i_stand, turn_lo, turn_hi, i_sit];
 % The trial occupies N frame INTERVALS ([0, N/fs]) but only N samples, so the
 % last stage ends half-open at frame N+1 - that is what makes the five stages
 % tile the full TUG time. frame_hi is reported back as the last real frame.
 f1 = [i_stand, turn_lo, turn_hi, i_sit, N + 1];
 for k = 1:numel(SG.order)
   key = SG.order{k};
   a = min(max(f0(k), 1), N);
   b = min(max(f1(k), a), N + 1);
   % Length is measured in FRAMES / fs, not t(b) - t(a): the time vector only
   % reaches (N-1)/fs while the paper defines TUG time as N/fs. Counting frames
   % makes the five stages tile [0, N/fs] exactly, so the percentages sum to 100.
   t0 = t(a);
   dur = (b - a) / fs;
   SG.bounds.(key) = [t0, t0 + dur, a, min(b, N)];
   SG.durations.(key) = max(0, dur);
   if tug_s > 0
     SG.pct.(key) = 100 * SG.durations.(key) / tug_s;
   else
     SG.pct.(key) = 0;
   end
 end
 SG.tug_s = tug_s;
 SG.note = note;

 stage = {}; label = {}; frame_lo = []; frame_hi = [];
 start_s = []; end_s = []; duration_s = []; pct_of_tug = [];
 for k = 1:numel(SG.order)
   key = SG.order{k};
   b = SG.bounds.(key);
   stage{end + 1, 1} = key;
   label{end + 1, 1} = SG.labels.(key);
   % exported frame numbers are 0-based sample indices (SG.bounds stays
   % 1-based because it is also used to index the data arrays)
   frame_lo(end + 1, 1) = b(3) - 1;
   frame_hi(end + 1, 1) = b(4) - 1;
   start_s(end + 1, 1) = round(b(1), 4);
   end_s(end + 1, 1) = round(b(2), 4);
   duration_s(end + 1, 1) = round(SG.durations.(key), 4);
   pct_of_tug(end + 1, 1) = round(SG.pct.(key), 2);
 end
 SG.T = table(stage, label, frame_lo, frame_hi, start_s, end_s, ...
   duration_s, pct_of_tug);
end
