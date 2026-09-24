# KinectTUG-Gait

**Instrumented Timed-Up-and-Go (iTUG) gait analysis from Kinect v2 skeletal tracking — MATLAB implementation**

[![License: BSD-3-Clause](https://img.shields.io/badge/License-BSD--3--Clause-blue.svg)](LICENSE)
[![MATLAB](https://img.shields.io/badge/MATLAB-R2016b%2B-orange.svg)](https://www.mathworks.com/)

A reproducible MATLAB toolbox that implements the gait-processing pipeline described
in the accompanying manuscript (cerebral small-vessel disease with gait disturbance).
It ingests Kinect v2 skeleton exports (25 joints × X/Y/Z/State at 30 fps), denoises
them, transforms to a subject-centred frame, automatically segments the Timed-Up-and-Go
(TUG) test, detects gait events from the ankle trajectory, and extracts **eight
spatiotemporal gait parameters** from a single representative gait cycle (the
"6-point method").

---

## Features

- Zero-phase 4th-order Butterworth low-pass (5 Hz, 30 fps) for smoothing/denoising.
- PCA-based coordinate transform to a subject frame (forward / lateral / vertical).
- Automatic TUG segmentation: stand-up → walk → turn → sit-down.
- Gait-event detection (heel-strike / toe-off) from the ankle forward (depth) trajectory,
  **direction-independent** so it works for the out-and-back TUG walk.
- Automatic selection of the best gait cycle of the **outbound** walking leg
  (the manuscript's rule: the cycle is always taken before the turn).
- Fourteen parameters: step speed, cadence, stride length, left/right single-limb support,
  double-limb support (total and per-stride), stride time, swing-phase velocity, TUG time,
  average single-limb support, average double-limb support, average swing phase.
- Standard decomposition of the selected cycle into **initial double support / left single
  support / terminal double support / right single support** (real contact intervals).
- Publication-quality figures and CSV exports; a single self-contained example script
  regenerates all of them (no test suite is shipped).

## Requirements

- **MATLAB** R2016b or newer (script-local functions and the `string` type are used).
- **Signal Processing Toolbox** (`butter`, `filtfilt`). `gradient` and `movmean` are base
  MATLAB; MATLAB's own `findpeaks` is deliberately **not** used (see `gait.findpeaksGait`).

No Statistics Toolbox is required (PCA is computed from the covariance eigendecomposition).

## Installation

```matlab
% From MATLAB, add the src/ folder (which contains the +gait package) to the path:
addpath('src');
% or run the example, which self-adds the path:
run('src/example_gait_analysis.m');
```

## Quick start

```matlab
addpath('src');
data = gait.loadKinect('data/sample_TUG_gait.csv');      % sample iTUG recording
pts  = gait.extractCyclePoints(data, 5.0, 4, 0.6);       % best OUTBOUND cycle
P    = gait.computeParamsFromPoints(pts, data.N/data.fs);
disp(P)

S = gait.stancePhases(pts);                               % four support phases
gait.plotGaitCycle(pts, P, 'outputs/fig_cycle6_points.png');
gait.plotCycleWithPhases(pts, P, S, 'outputs/fig_cycle6_points_with_phases.png');
gait.plotStancePhases(pts, S, 'outputs/fig_stance_phases.png', false);
```

Or simply run `example_gait_analysis` to regenerate all outputs in `outputs/`.

## Repository structure

```
kinect_gait_matlab/
├── LICENSE                 BSD-3-Clause
├── CITATION.cff            GitHub "Cite this repository" metadata
├── CONTRIBUTING.md
├── README.md
├── data/
│   └── sample_TUG_gait.csv   one complete TUG (30 fps, de-identified — see below)
├── docs/
│   └── methods.md           detailed algorithm ↔ manuscript mapping
└── src/
    ├── +gait/               MATLAB package (one function per file)
    │   ├── loadKinect.m
    │   ├── lowpass.m
    │   ├── preprocessJoints.m
    │   ├── buildSubjectFrame.m
    │   ├── segmentTUG.m
    │   ├── detectHeelStrikes.m
    │   ├── detectFootEventsForward.m
    │   ├── extractCyclePoints.m
    │   ├── computeParamsFromPoints.m
    │   ├── stancePhases.m            % four-phase support decomposition
    │   ├── tugSegments.m             % five whole-trial TUG stages
    │   ├── plotTugOverview.m         % whole-trial overview figure
    │   ├── plotStancePhases.m        % support-phase bar chart
    │   ├── plotCycleWithPhases.m     % trajectory + support phases
    │   ├── findpeaksGait.m           % self-contained peak detection
    │   └── plotGaitCycle.m
    └── example_gait_analysis.m
```

## Cycle selection

The TUG is an out-and-back walk, so a trial contains the outbound leg, the turn and the
return leg. Gait parameters are reported for **one** representative cycle, selected by
`extractCyclePoints`:

| mode | candidate pool | rule |
|---|---|---|
| `outbound` (only mode shipped) | cycles fully inside the **walk_out (去程) segment** `[i_stand, turn_lo]` | best `2*(steady location) + (physiological score)` |

Candidate cycles are only those with a stride time in `[0.5, 1.8] s`, no contact with the
turn window, and exactly one right heel-strike inside them followed by a second one.
This outbound rule is the one used for the manuscript's results; if a trial has no outbound
candidate at all (very short walk) the function falls back to the whole straight walk and
sets `pts.outbound_ok = false`.

## MATLAB-specific notes

| Topic | Note |
|---|---|
| Struct field names | R2021b rejects field names starting with `_` and does not accept `P.('Step Speed (m/s)')`. Parameter fields use identifiers (`Step_Speed`); the human-friendly strings live only in the CSV headers. |
| Cross-file package calls | Inside `+gait`, sibling functions must be called as `gait.xxx(...)` — bare names do not resolve here. |
| Peak detection | `gait.findpeaksGait` re-implements the standard find-peaks semantics (local maxima → minimum distance → prominence) from scratch, so MATLAB's `findpeaks` is not used and `MinPeakProminence` is never required. |
| Time base | `loadKinect` deliberately falls back to a uniform `t = (0:N-1)/fs` for CSV exports — the exported `Time` column is a wall-clock stamp, not the sample clock. See the comment in `loadKinect.m`. |
| Frame numbers | Every frame number that leaves the toolbox (CSV column or console line) is a **0-based sample index** — frame `i` is the `(i+1)`-th data row and `time = i/fs`. MATLAB's own row indices stay 1-based inside the `+gait` functions (subtract 1 when reporting). |

## Validation

The reported parameters were cross-checked numerically on a held-out cohort of Kinect
TUG recordings; values are deterministic and reproduce to the precision of the exported
CSVs. The toolbox is self-contained MATLAB and depends only on the Signal Processing Toolbox.

## The "6-point method" and the support-phase identity

For one representative gait cycle, each ankle contributes three points:
**HS** (heel-strike / landing), **TO** (toe-off / lift-off), **HS2** (next
heel-strike of the same foot). The six points (time, forward-Z) drive the parameters.

**The six points span ~1.5 strides, not one.** Each foot's triple is measured on that
foot's OWN stride, and the left/right strides are half a cycle apart: the left triple
lives in `[L.HS, L.HS2]`, the right triple in `[R.HS, R.HS2]` (later). This is
unavoidable — one stride window contains only five event boundaries
(`L.HS`, `R.TO_prev`, `R.HS`, `L.TO`, `L.HS2`), never a full triple for both feet.
Per-limb parameters (stride time/length, swing velocity, and hence step speed and
cadence) legitimately need each foot's own stride.

**Support phases, in contrast, are measured on ONE cycle** — the left stride
`[L.HS, L.HS2]` — from the interleaved events:

| Event | Meaning |
|---|---|
| `t0 = L.HS` | left foot lands (cycle start) |
| `t1 = R.TO_prev` | right foot lifts off — end of initial double support |
| `t2 = R.HS` | right foot lands — end of left single support |
| `t3 = L.TO` | left foot lifts off — end of terminal double support |
| `t4 = L.HS2` | left foot lands again — end of right single support |

- left single support = `(t2 − t1) / (t4 − t0)`,
- right single support = `(t4 − t3) / (t4 − t0)`,
- double support = `((t1 − t0) + (t3 − t2)) / (t4 − t0)`.

The four intervals tile the cycle, so **left single + right single + double support =
100%** exactly (the gait-cycle identity). `Double support` is the **total** double
support on the cycle (initial + terminal). The analysed window is itself one stride, so
per-cycle and per-stride double support are the same quantity; the stance fraction
`D = stance/stride` is exported separately as a diagnostic.

> **`R.TO_prev` ≠ `R.TO`.** `R.TO` is the right foot's own lift-off inside
> `[R.HS, R.HS2]`, half a step later than `t1`. `stancePhases` and
> `computeParamsFromPoints` both read `pts.R.TO_prev`, so the shaded bands in the
> figures and the reported percentages cannot drift apart.

## Output

Running `example_gait_analysis` writes to `outputs/`:

- `cycle6_points.csv` — the 6 key points, the `R.TO_prev` event, and the two
  double-support intervals (initial + terminal).
- `gait_parameters.csv` — final 8 parameters (Parameter / Value / Unit).
- `stance_phases.csv` — four standard support phases (start/end/duration/% of cycle).
- `tug_segments.csv` — the five whole-trial TUG stages
  (stage / label / frame_lo / frame_hi / start_s / end_s / duration_s / pct_of_tug).
  The stages tile `[0, N/fs]` exactly, so the percentages sum to 100.
- `gait_events.csv` — all detected heel-strike (HS) and toe-off (TO) events.
- `fig_tug_overview.png` — the **whole TUG trial** (no zoom), four stacked panels:
  SpineBase height + sit->stand threshold, CoM forward displacement + turn peak,
  ankle forward trajectories with every HS/TO event, and a colour bar of the five
  stages. The five stages are also the shaded background of the three signal panels,
  and the analysed cycle `[L.HS, L.HS2]` is drawn as a black band so it is obvious
  which part of the TUG the reported parameters come from.
- `fig_cycle6_points.png` — ankle forward trajectory with HS/TO/HS2 markers and the two
  double-support intervals (orange); solid lines = analysed cycle, dashed = the right
  foot's own stride.
- `fig_cycle6_points_with_phases.png` — same trajectory overlaid with the four
  support-phase bands (initial DS / left SS / terminal DS / right SS), the analysed
  cycle and the right foot's own stride marked, and `R.TO_prev` flagged.
- `fig_stance_phases.png` / `fig_stance_phases_pct.png` — support-phase bar charts
  (absolute time and % of gait cycle).

Every table is written as CSV with full precision; every figure is regenerated from
scratch on each run, so `outputs/` is fully disposable.

## Sample data

`data/sample_TUG_gait.csv` is one complete TUG trial (305 frames at 30 fps, ~10.17 s)
in the raw Kinect v2 export layout: a `Time` column followed by 25 joints ×
`_X / _Y / _Z / _State`.

**The file is de-identified.** The original `Time` values were the real wall-clock
capture stamps (`HH_MM_SS_mmm`); they have been replaced by a neutral, synthetic
sequence starting at `00_00_00_0000`. This changes nothing numerically, because
`loadKinect` does not use the `Time` column to build the time base (it always
reconstructs a uniform `t = (0:N-1)/fs` from the frame rate). Every joint coordinate
and every `_State` flag is byte-for-byte unchanged, so all reported parameters are
identical to those computed from the original recording.

## License & citation

Released under the [BSD-3-Clause](LICENSE) license. If you use this toolbox, please
cite it via `CITATION.cff` (edit the author/ORCID/repository fields before publishing).

---

*This software was developed to support the gait-analysis methods of the accompanying
manuscript and is provided for research reproducibility.*
