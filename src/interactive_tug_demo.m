%% interactive_tug_demo Launch the interactive TUG segmentation GUI.
%
% Opens the Full TUG trial overview with four draggable boundary lines
% (stand-up / turn start / turn end / sit-down). Drag a line, watch the
% stage bands + turn window + stage bar follow in real time, then press
% Apply: the whole pipeline re-runs from the manual boundaries and all
% CSVs + PNGs are saved to ../outputs (same files as example_gait_analysis).
% Reset restores the automatic detection.
%
% Run: >> run('src/interactive_tug_demo.m')

 baseDir = fileparts(mfilename('fullpath'));
 addpath(baseDir);
 data = gait.loadKinect(fullfile(baseDir, '..', 'data', 'sample_TUG_gait.csv'));
 gait.interactiveTUG(data);
