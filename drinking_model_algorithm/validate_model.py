#!/usr/bin/env python3
"""
Standalone validator for dynamic standard-drink models.

Compared models:
1) Legacy v1.1 bookkeeping:
   N(t) = max(0, A(t) - r * elapsed_since_first_drink)

2) Physical v1.2+ runtime (recommended):
   - body stock B(t) never < 0
   - metabolism runs only while B(t) > 0
   - supports absorption lag and burst-merge preprocessing
"""

from __future__ import annotations

import argparse
import csv
import json
import math
import random
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Iterable, List, Sequence, Tuple


EPS = 1e-9


@dataclass(frozen=True)
class Drink:
    v: float
    s: float  # minutes
    e: float  # minutes


@dataclass(frozen=True)
class ModelParams:
    metabolism_rate_sd_per_hour: float
    absorption_lag_minutes: float
    min_absorption_duration_minutes: float
    burst_merge_window_minutes: float


def load_cases(path: Path) -> Dict:
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def build_drinks(raw_drinks: List[Dict], default_duration_minutes: float) -> List[Drink]:
    sorted_raw = sorted(raw_drinks, key=lambda d: float(d["start_min"]))
    starts = [float(d["start_min"]) for d in sorted_raw]
    drinks: List[Drink] = []

    for i, row in enumerate(sorted_raw):
        v = float(row["v"])
        s = float(row["start_min"])
        explicit_end = row.get("end_min")
        e = float(explicit_end) if explicit_end is not None else s + default_duration_minutes
        if i + 1 < len(starts):
            e = min(e, starts[i + 1])  # same as "update previous drink end to current time"
        e = max(e, s)
        drinks.append(Drink(v=v, s=s, e=e))
    return drinks


def merge_burst_drinks(drinks: Sequence[Drink], burst_merge_window_minutes: float) -> List[Drink]:
    if not drinks:
        return []
    if burst_merge_window_minutes <= 0:
        return list(drinks)

    merged: List[Drink] = []
    cluster: List[Drink] = [drinks[0]]

    def flush_cluster(items: Sequence[Drink]) -> None:
        merged.append(
            Drink(
                v=sum(x.v for x in items),
                s=min(x.s for x in items),
                e=max(x.e for x in items),
            )
        )

    for d in drinks[1:]:
        if d.s - cluster[-1].s <= burst_merge_window_minutes + EPS:
            cluster.append(d)
        else:
            flush_cluster(cluster)
            cluster = [d]
    flush_cluster(cluster)
    return merged


def effective_absorption_window(drink: Drink, params: ModelParams) -> Tuple[float, float]:
    start = drink.s + params.absorption_lag_minutes
    end_base = drink.e + params.absorption_lag_minutes
    end = max(end_base, start + params.min_absorption_duration_minutes)
    return start, end


def absorption_proportion(t_min: float, s_min: float, e_min: float) -> float:
    if t_min <= s_min:
        return 0.0
    if t_min >= e_min:
        return 1.0
    duration = e_min - s_min
    if duration <= 0:
        return 1.0
    return (t_min - s_min) / duration


def absorbed_total(t_min: float, drinks: Sequence[Drink], params: ModelParams) -> float:
    total = 0.0
    for d in drinks:
        a_s, a_e = effective_absorption_window(d, params)
        total += d.v * absorption_proportion(t_min, a_s, a_e)
    return max(0.0, total)


def build_time_axis(
    drinks: Sequence[Drink],
    params: ModelParams,
    step_min: float,
    horizon_min: float | None = None,
    extra_points: Iterable[float] | None = None,
) -> List[float]:
    if horizon_min is None:
        max_end = max((effective_absorption_window(d, params)[1] for d in drinks), default=0.0)
        horizon_min = max_end + 8 * 60

    step_count = max(1, int(math.ceil(horizon_min / step_min)))
    axis = [i * step_min for i in range(step_count + 1)]
    for d in drinks:
        a_s, a_e = effective_absorption_window(d, params)
        axis.extend([d.s, d.e, a_s, a_e])
    axis.append(0.0)
    axis.append(horizon_min)
    if extra_points is not None:
        axis.extend(float(x) for x in extra_points)
    return sorted(set(round(t, 8) for t in axis))


# ---------- Legacy v1.1 bookkeeping ----------

def legacy_metabolized_total(t_min: float, drinks: Sequence[Drink], params: ModelParams) -> float:
    if not drinks:
        return 0.0
    s_first = min(d.s for d in drinks)
    hours = max(0.0, (t_min - s_first) / 60.0)
    return params.metabolism_rate_sd_per_hour * hours


def n_legacy_v11(t_min: float, drinks: Sequence[Drink], params: ModelParams) -> float:
    absorbed = absorbed_total(t_min, drinks, params)
    metabolized = legacy_metabolized_total(t_min, drinks, params)
    return max(0.0, absorbed - metabolized)


def simulate_legacy_v11(axis: Sequence[float], drinks: Sequence[Drink], params: ModelParams) -> List[float]:
    return [n_legacy_v11(t, drinks, params) for t in axis]


# ---------- Physical v1.2+ ----------

def segment_boundaries(start_min: float, end_min: float, drinks: Sequence[Drink], params: ModelParams) -> List[float]:
    points = [start_min, end_min]
    for d in drinks:
        a_s, a_e = effective_absorption_window(d, params)
        if start_min < a_s < end_min:
            points.append(a_s)
        if start_min < a_e < end_min:
            points.append(a_e)
    return sorted(set(round(t, 8) for t in points))


def absorption_rate_sd_per_hour(interval_start_min: float, interval_end_min: float, drinks: Sequence[Drink], params: ModelParams) -> float:
    mid = (interval_start_min + interval_end_min) / 2.0
    rate = 0.0
    for d in drinks:
        a_s, a_e = effective_absorption_window(d, params)
        duration_min = a_e - a_s
        if duration_min <= 0:
            continue
        if a_s < mid < a_e:
            rate += d.v / (duration_min / 60.0)
    return rate


def advance_stock_segment(stock_sd: float, in_rate_sd_per_hour: float, out_rate_sd_per_hour: float, dt_hours: float) -> float:
    if dt_hours <= 0:
        return max(0.0, stock_sd)

    stock = max(0.0, stock_sd)
    net = in_rate_sd_per_hour - out_rate_sd_per_hour

    if stock <= EPS:
        return max(0.0, net) * dt_hours
    if net >= 0:
        return stock + net * dt_hours

    time_to_zero = stock / (-net)
    if time_to_zero >= dt_hours:
        return stock + net * dt_hours
    return 0.0


def advance_physical_interval(
    start_min: float,
    end_min: float,
    current_stock_sd: float,
    drinks: Sequence[Drink],
    params: ModelParams,
) -> float:
    if end_min <= start_min:
        return max(0.0, current_stock_sd)

    stock = max(0.0, current_stock_sd)
    points = segment_boundaries(start_min, end_min, drinks, params)

    for i in range(len(points) - 1):
        a = points[i]
        b = points[i + 1]
        dt_hours = max(0.0, (b - a) / 60.0)
        if dt_hours <= 0:
            continue
        in_rate = absorption_rate_sd_per_hour(a, b, drinks, params)
        stock = advance_stock_segment(
            stock_sd=stock,
            in_rate_sd_per_hour=in_rate,
            out_rate_sd_per_hour=params.metabolism_rate_sd_per_hour,
            dt_hours=dt_hours,
        )
    return max(0.0, stock)


def n_physical_reference_at(t_min: float, drinks: Sequence[Drink], params: ModelParams) -> float:
    if t_min <= 0:
        return 0.0
    return advance_physical_interval(
        start_min=0.0,
        end_min=t_min,
        current_stock_sd=0.0,
        drinks=drinks,
        params=params,
    )


def simulate_physical_reference(axis: Sequence[float], drinks: Sequence[Drink], params: ModelParams) -> List[float]:
    return [n_physical_reference_at(t, drinks, params) for t in axis]


def simulate_physical_runtime(axis: Sequence[float], drinks: Sequence[Drink], params: ModelParams) -> List[float]:
    if not axis:
        return []

    out: List[float] = []
    stock = 0.0
    last = 0.0

    for t in axis:
        stock = advance_physical_interval(
            start_min=last,
            end_min=t,
            current_stock_sd=stock,
            drinks=drinks,
            params=params,
        )
        out.append(stock)
        last = t
    return out


def metrics(reference: Sequence[float], candidate: Sequence[float]) -> Tuple[float, float, float, int]:
    errors = [abs(a - b) for a, b in zip(reference, candidate)]
    max_err = max(errors) if errors else 0.0
    mae = (sum(errors) / len(errors)) if errors else 0.0
    rmse = math.sqrt(sum(e * e for e in errors) / len(errors)) if errors else 0.0
    worst_idx = max(range(len(errors)), key=lambda i: errors[i]) if errors else -1
    return max_err, mae, rmse, worst_idx


def print_report(
    scenario_name: str,
    axis: Sequence[float],
    physical_reference: Sequence[float],
    physical_runtime: Sequence[float],
    legacy_v11: Sequence[float],
) -> None:
    rows = [
        ("Physical_v1.2+_runtime", physical_runtime),
        ("Legacy_v1.1_bookkeeping", legacy_v11),
    ]

    print(f"\nScenario: {scenario_name}")
    print("candidate                  max_abs_err   mae         rmse        worst_t(min)")
    print("-------------------------  -----------   ----------  ----------  ------------")
    for label, series in rows:
        max_err, mae, rmse, idx = metrics(physical_reference, series)
        worst_t = axis[idx] if idx >= 0 else 0.0
        print(f"{label:25}  {max_err:11.6f}   {mae:10.6f}  {rmse:10.6f}  {worst_t:12.2f}")


def print_checkpoints(
    checkpoints: Sequence[float],
    axis: Sequence[float],
    physical_reference: Sequence[float],
    legacy_v11: Sequence[float],
) -> None:
    if not checkpoints:
        return
    print("checkpoints(min)           physical_v1.2+  legacy_v1.1")
    print("------------------------   --------------  -----------")
    for cp in checkpoints:
        idx = min(range(len(axis)), key=lambda i: abs(axis[i] - cp))
        print(f"{axis[idx]:22.2f}   {physical_reference[idx]:14.6f}  {legacy_v11[idx]:11.6f}")


def dump_csv(
    path: Path,
    axis: Sequence[float],
    physical_reference: Sequence[float],
    physical_runtime: Sequence[float],
    legacy_v11: Sequence[float],
) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(
            [
                "t_min",
                "physical_reference",
                "physical_runtime",
                "legacy_v11_bookkeeping",
                "err_runtime",
                "err_legacy",
            ]
        )
        for t, ref, run, legacy in zip(axis, physical_reference, physical_runtime, legacy_v11):
            writer.writerow([t, ref, run, legacy, abs(ref - run), abs(ref - legacy)])


def monte_carlo_validation(
    trials: int,
    default_duration_minutes: float,
    params: ModelParams,
) -> Tuple[float, float]:
    random.seed(42)
    worst_runtime_err = 0.0
    worst_legacy_err = 0.0

    for _ in range(trials):
        n = random.randint(1, 12)
        starts = sorted(random.uniform(0, 360) for _ in range(n))
        raw = [{"v": random.uniform(0.2, 2.2), "start_min": s} for s in starts]
        drinks = build_drinks(raw, default_duration_minutes)
        drinks = merge_burst_drinks(drinks, params.burst_merge_window_minutes)
        axis = build_time_axis(drinks, params, step_min=1.0, horizon_min=720.0)

        ref = simulate_physical_reference(axis, drinks, params)
        runtime = simulate_physical_runtime(axis, drinks, params)
        legacy = simulate_legacy_v11(axis, drinks, params)

        runtime_max_err, _, _, _ = metrics(ref, runtime)
        legacy_max_err, _, _, _ = metrics(ref, legacy)
        worst_runtime_err = max(worst_runtime_err, runtime_max_err)
        worst_legacy_err = max(worst_legacy_err, legacy_max_err)
    return worst_runtime_err, worst_legacy_err


def run_from_cases(config: Dict, step_override: float | None, dump_dir: Path | None) -> None:
    defaults = config.get("defaults", {})
    default_duration_minutes = float(defaults.get("default_duration_minutes", 30))
    default_step_min = float(defaults.get("sample_step_minutes", 1))
    step_min = step_override if step_override is not None else default_step_min

    params = ModelParams(
        metabolism_rate_sd_per_hour=float(defaults.get("metabolism_rate_sd_per_hour", 0.8)),
        absorption_lag_minutes=float(defaults.get("absorption_lag_minutes", 15)),
        min_absorption_duration_minutes=float(defaults.get("min_absorption_duration_minutes", 20)),
        burst_merge_window_minutes=float(defaults.get("burst_merge_window_minutes", 2)),
    )

    print("Model params")
    print(f"- metabolism_rate_sd_per_hour:      {params.metabolism_rate_sd_per_hour}")
    print(f"- absorption_lag_minutes:           {params.absorption_lag_minutes}")
    print(f"- min_absorption_duration_minutes:  {params.min_absorption_duration_minutes}")
    print(f"- burst_merge_window_minutes:       {params.burst_merge_window_minutes}")

    scenarios = config.get("scenarios", [])
    if not scenarios:
        raise ValueError("No scenarios found in cases file.")

    for s in scenarios:
        name = s["name"]
        raw_drinks = build_drinks(s.get("drinks", []), default_duration_minutes)
        drinks = merge_burst_drinks(raw_drinks, params.burst_merge_window_minutes)
        horizon_min = float(s["horizon_min"]) if "horizon_min" in s else None
        checkpoints = [float(x) for x in s.get("checkpoints_min", [])]
        axis = build_time_axis(drinks, params, step_min=step_min, horizon_min=horizon_min, extra_points=checkpoints)

        physical_ref = simulate_physical_reference(axis, drinks, params)
        physical_runtime = simulate_physical_runtime(axis, drinks, params)
        legacy_v11 = simulate_legacy_v11(axis, drinks, params)

        if len(drinks) != len(raw_drinks):
            print(f"\n[burst merge] {name}: {len(raw_drinks)} -> {len(drinks)} drinks")

        print_report(name, axis, physical_ref, physical_runtime, legacy_v11)
        print_checkpoints(checkpoints, axis, physical_ref, legacy_v11)

        if dump_dir is not None:
            out_path = dump_dir / f"{name}.csv"
            dump_csv(out_path, axis, physical_ref, physical_runtime, legacy_v11)
            print(f"CSV: {out_path}")

    worst_runtime_err, worst_legacy_err = monte_carlo_validation(
        trials=200,
        default_duration_minutes=default_duration_minutes,
        params=params,
    )
    print("\nMonte Carlo (200 trials)")
    print(f"worst runtime-vs-reference error (v1.2+): {worst_runtime_err:.10f}")
    print(f"worst legacy-vs-reference error (v1.1):   {worst_legacy_err:.10f}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Validate physical v1.2+ standard-drink model.")
    parser.add_argument(
        "--cases",
        type=Path,
        default=Path(__file__).resolve().parent / "cases" / "default_cases.json",
        help="Path to scenario JSON",
    )
    parser.add_argument("--step-min", type=float, default=None, help="Override sampling step in minutes")
    parser.add_argument(
        "--dump-csv-dir",
        type=Path,
        default=None,
        help="Directory to dump per-scenario CSV timelines",
    )
    args = parser.parse_args()

    config = load_cases(args.cases)
    run_from_cases(config, step_override=args.step_min, dump_dir=args.dump_csv_dir)


if __name__ == "__main__":
    main()
