# Methods — algorithm ↔ manuscript mapping

This document maps every step of `src/+gait` to the *Gait Data Processing* section of
the manuscript, so the code is directly citable from the paper.

## 1. Data loading (`loadKinect`)

Kinect v2 skeletal tracking records 25 joints, each as `(X, Y, Z, State)` in camera
coordinates, at **30 fps** (manuscript Methods: 30 fps). Two export layouts are
supported:

- `.csv`: header line + one row per frame; the time code (`HH_MM_SS_mmm`) appears
  only on the first data row (later rows may carry a NUL prefix and parse to `NaN`).
- `.xlsx`: header row + a `Time` column on every row.

When the time code is unusable the time vector is reconstructed from the frame rate:
`t = (0 : N−1) / fs`. Short `NaN` gaps (tracking loss) are linearly interpolated.

## 2. Pre-processing (`preprocessJoints`, `lowpass`)

For every joint, `X/Y/Z` are NaN-interpolated and passed through a **zero-phase
4th-order Butterworth low-pass** with a **5 Hz** cutoff (`filtfilt`, no phase lag) —
this is the "data smoothing / denoising" step. `State` is left untouched.

## 3. Coordinate transform (`buildSubjectFrame`)

The centre of mass (CoM) is the mean of `SpineBase`, `HipLeft`, `HipRight`. Its
horizontal (X–Z) displacement is decomposed by PCA; the principal component is the
**forward (walking) axis** `f`, oriented by the sign of the *largest horizontal excursion*
(the turn-around point). The mean forward velocity is deliberately **not** used: an
out-and-back TUG has a net displacement of ~0, so its sign is set by rounding noise and
flips with the differentiation scheme (a real bug, see the note in `buildSubjectFrame.m`).
The **lateral axis** `l` is `f` rotated 90°. Vertical is the camera `Y`. This realises
the manuscript "coordinate transformation" into a subject-centred frame.

## 4. TUG segmentation (`segmentTUG`)

The Timed-Up-and-Go is split into stand-up / walk / turn / sit-down:

- **Stand-up / sit-down**: `SpineBase_Y` crossing a sit→stand threshold
  (`standFrac = 0.5` of the seated–upright range). `i_stand` / `i_sit` bound the
  upright span.
- **Turn window**: the peak of the CoM forward displacement `comF`, bracketed by the
  last left/right heel-strike before the peak and the first after it (a single TUG has
  one turn). `walk_mask` excludes stand/sit and the turn so only straight walking feeds
  event detection.

### Whole-trial stage table (`tugSegments`)

`tugSegments` does not re-detect anything: it just turns the `segmentTUG` boundaries into
the five stages of the whole recording, which is what `fig_tug_overview.png` and
`outputs/tug_segments.csv` report.

| # | stage | frames (1-based) | meaning |
|---|-------|------------------|---------|
| 1 | `sit` | `1 … i_stand` | sitting plus the stand-up transition |
| 2 | `walk_out` | `i_stand … turn_lo` | straight walking, outbound |
| 3 | `turn` | `turn_lo … turn_hi` | turning — **excluded** from all detection |
| 4 | `walk_back` | `turn_hi … i_sit` | straight walking, return |
| 5 | `sit_down` | `i_sit … N` | sit-down transition |

The five stages tile the whole trial: they are contiguous, start at `0 s` and end at the
paper's TUG time `N / fs`. Lengths are therefore counted as *frames / fs* rather than
`t(b) − t(a)` (the time vector only reaches `(N−1)/fs`, one sample short), which makes the
stage percentages sum to exactly 100 %. Every gait parameter is still computed only from
`walk_out + walk_back`; the other three stages exist to make the excluded parts explicit.

## 5. Gait-event detection (`detectFootEventsForward`)

Per the user-specified method, events come from the **ankle forward (depth)
trajectory relative to the CoM**: `relF = ankleFwd − comF`.

- **Heel-strike (HS)** = local **maximum** of `relF` (foot lands ahead of the body).
- **Toe-off (TO)** = local **minimum** of `relF` (foot pushes off behind the body).

Because the TUG is an out-and-back walk, "ahead of the body" flips sign on the return
leg. A **direction-independent** signal `sg = relF · sign(v_COM)` is therefore used, so
HS = peak of `sg`, TO = trough of `sg`, independent of walking direction. TO is taken
as the **global minimum of `sg` inside the step window**, which avoids mis-detecting the
small pre-swing "preparation" dip as lift-off.

Only events inside the upright straight-walk span are kept.

## 6. Cycle selection (`extractCyclePoints`)

Candidate left-foot cycles are every `[HS_L(i), HS_L(i+1)]` that (a) lies inside the
walk span, (b) does not cross the turn, and (c) contains exactly one right HS (`HS_R1`)
followed by a `HS_R2` (so both feet yield three points).

Note that the resulting right-foot triple (`R.HS`, `R.TO`, `R.HS2`) lies on the
**right** foot's own stride `[R.HS, R.HS2]`, which starts and ends later than the
selected left cycle. The function therefore also records `R.TO_prev` — the first
right toe-off in `[L.HS, R.HS)` — which is the event the support-phase
decomposition needs (see §7B). The selected cycle:

- `mode='outbound'` (**default**) — the candidate pool is restricted to cycles that
  lie **fully inside the walk_out (去程) segment** `[i_stand, turn_lo]` (both the
  cycle start and end must be within the outbound straight walk, from stand-up
  complete to the turn start); the best one is picked by
  `2·(steady location) + (physiological score)`. **This is the rule used for the
  manuscript's results**: the analysed cycle is always taken on the way out.
  When no outbound candidate exists (very short walk) the pool falls back to the whole
  straight walk and `pts.outbound_ok` is set to `false`.

  NOTE: the shipped `extractCyclePoints` implements ONLY this `outbound` rule (the
  manuscript's rule). The `auto` / `steady` / `first` / `last` variants listed below
  were used during development for sensitivity checks and are NOT part of the released
  function; do not pass a `mode` argument to it.
- `mode='auto'` — the same score, but over the whole straight-walk span
  (outbound + return), so it may select a return-leg cycle.
- `mode='steady'` — most centrally located steady cycle.
- `mode='first'` — first full cycle after the first post-stand step (outbound, A).
- `mode='last'` — last full cycle before sitting down (return, B).

The physiological score rewards left/right symmetry, a stride time near 1.0 s, a
double-support near the typical 25%, and no double-swing gap. This transparently
avoids the sit-down-decelerated last cycle.

## 7. Parameters (`computeParamsFromPoints`)

**Two families of parameters, two different time windows.** This distinction is
essential and was a source of a real bug (see the note below).

### (A) Per-limb parameters — each foot measured on its OWN stride

| Parameter | Formula |
|---|---|
| Stride time | `t(HS2) − t(HS)` (mean of L/R) |
| Stride length | `|z(HS2) − z(HS)|` (mean of L/R) |
| Step speed | `0.5·(stride_len_L/stride_time_L + stride_len_R/stride_time_R)` |
| Cadence | `120 / stride_time` (steps·min⁻¹) |
| Swing velocity | `0.5·(|z(HS2)−z(TO)|_L/swing_L + |…|_R/swing_R)` |
| TUG time | `N / fs` |

The left and right strides are **phase-shifted by half a cycle**, so the 6 key
points span ≈ 1.5 strides, not one. This is unavoidable: a single stride window
contains only five event boundaries (`L.HS`, `R.TO_prev`, `R.HS`, `L.TO`,
`L.HS2`), never a full `HS/TO/HS2` triple for both feet. Swing velocity in
particular requires each foot's own `TO`.

### (B) Support-phase parameters — measured on ONE cycle

The reference cycle is the **left stride** `[L.HS, L.HS2]`, decomposed by the
interleaved events of both feet:

| Event | Meaning |
|---|---|
| `t0 = L.HS` | left foot lands (cycle start) |
| `t1 = R.TO_prev` | right foot lifts off — end of **initial double support** |
| `t2 = R.HS` | right foot lands — end of **left single support** |
| `t3 = L.TO` | left foot lifts off — end of **terminal double support** |
| `t4 = L.HS2` | left foot lands again — end of **right single support** |

| Parameter | Formula |
|---|---|
| Left single support | `(t2 − t1) / (t4 − t0) × 100` |
| Right single support | `(t4 − t3) / (t4 − t0) × 100` |
| Double support | `((t1 − t0) + (t3 − t2)) / (t4 − t0) × 100` |

Because the four intervals tile `[t0, t4]`,
**left single + right single + double support ≡ 100%** exactly (the double-swing
gap is zero because contact is defined as `[HS, TO]`).

`Double support` is the **total** double support on the cycle (initial + terminal). A
stride contains **two** double-support intervals, so the same quantity is also reported
*per stride* as `(2D−1)·100`, with the stance fraction `D = stance/stride` measured from
the same 6 points.

> **`R.TO_prev` ≠ `R.TO`.** `R.TO` is the right foot's own lift-off inside
> `[R.HS, R.HS2]`, i.e. half a step later than `t1`. Using `R.TO` here made the
> "double support" collapse to the terminal double support alone and pushed the
> normalisation window above the stride time, so the percentages were no longer
> "% of gait cycle". Both `stancePhases` and `computeParamsFromPoints` read
> `pts.R.TO_prev`, so the shaded bands and the reported percentages cannot drift
> apart.

### Standard four-phase decomposition

Within the selected cycle `[L.HS, L.HS2]`, the support pattern is further decomposed:

- **Initial double support** `[t(L.HS), t(R.TO_prev)]`: both feet are on the ground at the beginning of the cycle.
- **Left single support** `[t(R.TO_prev), t(R.HS)]`: only the left foot is on the ground; the right foot is swinging.
- **Terminal double support** `[t(R.HS), t(L.TO)]`: both feet are on the ground again.
- **Right single support** `[t(L.TO), t(L.HS2)]`: only the right foot is on the ground; the left foot is swinging.

`t(R.TO_prev)` is the right-foot toe-off event that occurs **after** `t(L.HS)` but **before** `t(R.HS)`.
If no such event exists (very fast cadence), the initial double-support duration is zero.
The four durations sum to the stride time, so they can be expressed as `% of gait cycle`
and checked with the identity
`initial_DS + left_SS + terminal_DS + right_SS ≡ 100%`.

`stancePhases` and the support-phase block of `computeParamsFromPoints` read the *same*
field (`pts.R.TO_prev`), so the shaded bands in the figures and the reported
single/double-support percentages are guaranteed to agree.

## Reproducibility notes

- Sample data: `data/sample_TUG_gait.csv` (one complete TUG, ~10.17 s, 30 fps,
  305 frames). The `Time` column has been de-identified (neutral synthetic stamps
  starting at `00_00_00_0000`); the loader ignores it and reconstructs a uniform
  time base from the frame rate, so all results are unaffected.
- Frame numbers reported in the CSV files and the console log are 0-based sample
  indices (frame `i` = the `(i+1)`-th data row, `time = i/fs`). This is the
  0-based convention used throughout this toolbox; MATLAB's internal row indices remain
  1-based, and the conversion happens only where results are reported.
- All results are deterministic given the input; run `example_gait_analysis` to
  regenerate every table and figure.
