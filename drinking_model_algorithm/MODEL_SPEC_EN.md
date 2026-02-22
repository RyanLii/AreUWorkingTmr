# Drinking Tracker App
## Dynamic Standard Drink Model Specification
### Version 2.0 (Dynamic Recovery Framework)
### Date: 2026-02-22

---

## 1. Purpose

This specification defines the computation model and presentation strategy for a human alcohol-state simulator.
This version is designed to satisfy all of the following:

1. Physical intuition: no metabolism when there is no alcohol left; no carrying "unused metabolism" into the future.
2. Behavioral realism: absorption has a lag; it does not rise immediately at drink entry.
3. User clarity: default UI focuses on "time to clear"; details are on demand.
4. Engineering practicality: stable behavior under very short-interval rapid drinking logs.
5. Recovery awareness: a dynamic Recovery Time (earlier than full clearance) is surfaced as the primary output, scaled by session intake.

This model is for behavioral awareness only. It is not medical, legal, or driving advice.

---

## 2. Scope

### 2.1 In Scope

1. Standard-drink intake modeling with absorption lag.
2. Body stock and metabolism modeling (non-negative, non-debt).
3. Burst-merge handling for very short drink intervals.
4. Layered UX guidance for primary vs detailed information.
5. Runnable incremental algorithm and validation protocol.
6. Dynamic Recovery Time derived from full clearance with a session-scaled buffer.

### 2.2 Out of Scope

1. Medical-grade BAC estimation.
2. Deep personalization (food, medication, liver condition, etc.).
3. Legal compliance determination.

---

## 3. Core Concept (Human-State Simulator)

The system tracks `B(t)` as an internal state variable:

```text
B(t) >= 0
display_sd(t) = B(t)
```

`B(t)` represents effective standard drinks currently in the body.
It is an internal quantity; the main UI should answer:
`What state am I in now?` and `How long until I feel human again?`

Recommended state labels:

1. `Pre-absorption`: drink logged, still in lag window.
2. `Absorbing`: `B(t)` is rising.
3. `Clearing`: `B(t)` is falling.
4. `Cleared`: `B(t) = 0` and will not rise again from current logs.

---

## 4. Symbols

1. `v_i`: standard-drink value for record `i` (SD).
2. `s_i`: start time of record `i`.
3. `e_i`: end time of record `i`.
4. `A(t)`: cumulative absorbed amount up to time `t`.
5. `a(t) = dA/dt`: instantaneous absorption rate (SD/h).
6. `r`: metabolism rate (SD/h).
7. `B(t)`: effective standard-drink body stock at time `t`.
8. `S_total`: total standard drinks consumed in the session.
9. `t_clear`: time when `B(t)` reaches 0 and remains 0 (full clearance).
10. `buffer_hours`: dynamic safety buffer derived from `S_total`.
11. `t_recovery`: recovery time — `t_clear - buffer_hours` (primary output).

---

## 5. Configurable Parameters

1. `default_duration_minutes`: default `30`.
2. `metabolism_rate_sd_per_hour`: default `0.8`.
3. `absorption_lag_minutes`: default `15`.
   Meaning: delay between drinking and absorption onset.
4. `min_absorption_duration_minutes`: default `20`.
   Meaning: minimum absorption-window duration per intake block.
5. `burst_merge_window_minutes`: default `2`.
   Meaning: logs in a very short window are merged into one intake block.

---

## 6. Drink Data Structure

Each input record must include:

1. `v_i: Double` (`>= 0`)
2. `s_i: Timestamp`
3. `e_i: Timestamp` (`e_i >= s_i`)

---

## 7. Timing and Burst Preprocessing

### 7.1 Base Timing

When `Add Drink` is tapped:

1. `s_new = now`
2. Optional rule for previous record:
   `e_prev = min(now, s_prev + default_duration)`
3. `e_new = s_new + default_duration`

### 7.2 Burst Merge Rule

Sort by `s_i`. If adjacent starts differ by `<= burst_merge_window_minutes`,
merge them into one cluster:

```text
v_cluster = sum(v_i)
s_cluster = min(s_i)
e_cluster = max(e_i)
```

Note: raw logs can be retained for audit/replay, while model math uses merged clusters.

---

## 8. Absorption Model (with Lag)

For each effective intake block `j` (single drink or merged cluster):

```text
as_j = s_j + absorption_lag_minutes
ae_j = max(e_j + absorption_lag_minutes, as_j + min_absorption_duration_minutes)
```

Absorption proportion:

```text
if t <= as_j:        p_j(t) = 0
if as_j < t < ae_j:  p_j(t) = (t - as_j) / (ae_j - as_j)
if t >= ae_j:        p_j(t) = 1
```

Cumulative absorption:

```text
A(t) = sum_j [ v_j * p_j(t) ]
```

---

## 9. Physical Metabolism Model

Continuous form:

```text
if B(t) > 0:
    dB/dt = a(t) - r
if B(t) = 0:
    dB/dt = max(0, a(t) - r)
```

Implications:

1. Metabolism outflow occurs only when stock exists.
2. No further subtraction when stock is zero, so no negative debt.

---

## 10. Segment Update (Exact in Piecewise-Linear Regime)

Within any interval that does not cross `as_j` or `ae_j`, `a(t)` is constant (`a_seg`).
Let interval duration be `dt_h` (hours), and starting stock be `B0`:

1. `B0 == 0` and `a_seg <= r`: `B1 = 0`
2. `B0 == 0` and `a_seg > r`: `B1 = (a_seg - r) * dt_h`
3. `B0 > 0` and `a_seg >= r`: `B1 = B0 + (a_seg - r) * dt_h`
4. `B0 > 0` and `a_seg < r`: `B1 = max(0, B0 - (r - a_seg) * dt_h)`

---

## 11. Runtime Algorithm

Runtime state:

1. `current_stock_sd` (`>= 0`)
2. `last_update_time`
3. `effective_drink_blocks[]` (after burst merge)

On refresh:

1. Build effective absorption windows `[as_j, ae_j]`.
2. Split `[last_update_time, now]` by all `as_j/ae_j` boundaries in range.
3. Advance `current_stock_sd` segment by segment using Section 10.
4. Set `last_update_time = now`.

---

## 12. Dynamic Recovery Framework (v2.0)

This section extends the output layer of the v1.4 model. All core dynamics (absorption lag, non-negative stock, segmented linear propagation) are unchanged.

### 12.1 Dynamic Buffer

Let `S_total` be the total standard drinks consumed in the session.

```text
buffer_hours_raw = 0.33 + 0.08 × max(0, S_total − 1)
buffer_hours     = clamp(buffer_hours_raw, 0.25, 2.0)
```

Lighter sessions produce shorter buffers; heavier sessions produce longer ones.
This ensures the Recovery Time is meaningfully earlier than full clearance across the full intake range.

| `S_total` | `buffer_hours_raw` | `buffer_hours` |
|---|---|---|
| 1 | 0.33 | 0.33 |
| 3 | 0.49 | 0.49 |
| 6 | 0.73 | 0.73 |
| 10 | 1.05 | 1.05 |
| 20 | 1.85 | 1.85 |
| 25 | 2.25 | 2.00 (clamped) |

### 12.2 Recovery Time Definition

Let `t_clear` be the first time `B(t) = 0` and stays at 0.

```text
t_recovery = t_clear − buffer_hours × 3600
```

`t_recovery` is the model's estimate of when the user has returned to a low-impact internal state. It is not a BAC threshold, legal limit, or medical standard.

### 12.3 Updated Output Priority

| Priority | Output | Description |
|---|---|---|
| Primary | Recovery Time (`t_recovery`) | When the user is likely to feel functional again |
| Secondary | Full Clearance (`t_clear`) | When modeled `B(t)` reaches zero |

### 12.4 Disclaimer

Recovery Time is derived purely from the model's internal stock simulation. It does not represent:
- Blood or breath alcohol concentration.
- Fitness to drive or operate machinery.
- Any legal threshold.

Individual variation (food, sleep, weight, medication) may shift actual recovery earlier or later.

---

## 13. Real-World Interpretation

### 13.1 Two drinks, wait 5 hours, then one drink

Under default params (`r = 0.8`, `lag = 15`):

1. First two drinks are already metabolized by the time the third starts (`B = 0`).
2. During the first 15 minutes after the third drink, `B` remains near 0 (lag).
3. Then it rises, and is not canceled by historical idle time.

### 13.2 Five drinks logged within 1 minute

With default `burst_merge_window = 2`, these logs merge into one cluster.
Combined with `lag + min_absorption_duration`, this avoids unstable spikes.

---

## 14. User-Facing Output Guidance

### 14.1 Product Principle

Default screen answers two questions in order:

1. `How long until I feel human again?` (Recovery Time — primary)
2. `How long until fully cleared?` (Full Clearance — secondary)

Detailed quantities belong in the detail view.

### 14.2 Progress Bar

The cooling-off bar is divided into two visual segments at the recovery split point:

- **Segment 1** (session start → Recovery Time): warm gradient (mint → orange).
  Represents the active-load phase.
- **Segment 2** (Recovery Time → Full Clearance): cool gradient (blue).
  Represents the tail / residual phase.

Labels below the bar:

```text
● Feel human ~HH:MM          Full clear ~HH:MM ●
```

### 14.3 Detail Page (On Demand)

If the user opens details, show:

1. `Total logged` — `S_total` in SD.
2. `In body now` — `B(now)` in SD.
3. `Still absorbing` — `pending_sd(now)` in SD.
4. `Metabolized` — `S_total - B(now) - pending_sd(now)` in SD.
5. `Estimated peak` — peak `B(t)` and time.
6. `Feel human` — `t_recovery` (absolute time).
7. `Full clear` — `t_clear` (absolute time).
8. `Clearing for` — elapsed time since `B(t)` began descending (shown in clearing/cleared state only).

Where:

```text
pending_sd(t) = sum_j [ v_j * (1 - p_j(t)) ]
```

### 14.4 Definition of "Full Clearance"

```text
Assuming no new drinks from now on,
the remaining time until B(t) reaches 0 and stays at 0.
```

Notes:

1. It is not "touching 0 at a single instant."
2. It must be the first time after which logged intake cannot make it rise again.
3. This handles lag cases (e.g. just logged a drink but absorption has not started yet).

### 14.5 Human-Feeling Mapping (Non-Medical)

For better realism and readability, map states to supportive copy:

1. `Pre-absorption`: `Just logged. Body response may still be delayed.`
2. `Absorbing`: `Body load is rising. Consider slowing down.`
3. `Clearing`: `Body load is falling. Keep hydrating and resting.`
4. `Cleared`: `Model estimates this session has cleared.`

These are behavioral cues, not medical judgments.

### 14.6 Important Disclaimer

All outputs only mean modeled `B(t)` has cleared or is below threshold.

1. They are not equal to measured BAC.
2. They are awareness metrics, not medical conclusions.

---

## 15. Validation Protocol

Script path:

`/Users/ryanlee/Development/AreUWorkingTmr/drinking_model_algorithm/validate_model.py`

Run:

```bash
cd /Users/ryanlee/Development/AreUWorkingTmr/drinking_model_algorithm
python3 validate_model.py
```

Default output compares these candidates against physical reference:

1. `Physical_v1.2+_runtime`
2. `Legacy_v1.1_bookkeeping`

---

## 16. Current Validation Snapshot (Default Cases)

Based on current defaults and scenarios (2026-02-19):

1. `Physical_v1.2+_runtime` has zero error against reference.
2. `Legacy_v1.1_bookkeeping` underestimates in long-gap scenarios (up to `0.6 SD`).
3. Monte Carlo (200 trials):
   `runtime-vs-reference worst error = 0.0000000000`
   `legacy-vs-reference worst error  = 2.3906701761`

---

## 17. Acceptance Tests

At minimum:

1. `lag_single_drink` (10-20 minute lag verification).
2. `two_drinks_then_5h_then_one`.
3. `long_gap_second_drink`.
4. `one_minute_five_drinks_burst`.
5. Monte Carlo random regression.
6. Recovery buffer scaling: verify `t_recovery` is `buffer_hours` before `t_clear` for a range of `S_total` values.

---

## 18. Assumptions and Limitations

1. Absorption is still a linear approximation, not full pharmacokinetics.
2. Parameters are population-level approximations, not individual medical truth.
3. Outputs are not equivalent to breath or blood BAC measurements.
4. Recovery Time does not account for sleep quality, food, hydration, or individual variation.

---

## 19. Migration Notes

### v1.1 → v1.4

1. Remove global continuous subtraction `M(t) = r * (t - s_first)`.
2. Remove carry-forward negative debt state.
3. Add `absorption_lag_minutes` and `min_absorption_duration_minutes`.
4. Add `burst_merge_window_minutes` and cluster preprocessing.
5. Add lag and burst focused regression scenarios.
6. Shift UI to "time-first main card + numeric detail page."
7. Update product narrative from tank metaphor to human-state simulator.

### v1.4 → v2.0

1. Add `projectedRecoveryTime` field to `SessionSnapshot`.
2. Implement `recoveryTime(totalStandardDrinks:projectedZeroTime:)` in `EstimationService`.
3. Recovery buffer formula: `clamp(0.33 + 0.08 × max(0, S_total - 1), 0.25, 2.0)` hours before `t_clear`.
4. Promote Recovery Time to primary UI output; demote Full Clearance to secondary.
5. Split cooling-off progress bar at recovery fraction (warm → cool gradient).
6. Add `Feel human` and `Full clear` rows to detail view.
7. No changes to core absorption or metabolism math.
