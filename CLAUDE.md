# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**Last Round?** — A watch-first drink-tracking app for Apple Watch + iPhone. Goal: safer nights, better mornings. No BAC/driving/legal guidance; outputs are behavioral estimates only.

## Commands

```bash
# Generate Xcode project (required after editing project.yml)
xcodegen generate

# Run core unit tests
swift test --parallel

# Run a single test class
swift test --filter EstimationServiceTests

# Full smoke test (core tests + builds + simulator screenshots)
./scripts/smoke.sh

# Build iOS app
xcodebuild -project AreUWorkingTmr.xcodeproj -scheme AreUWorkingTmr build

# Build watchOS app
xcodebuild -project AreUWorkingTmr.xcodeproj -scheme AreUWorkingTmrWatch build
```

CI runs `swift test --parallel` on every push (`.github/workflows/ci.yml`).

## Architecture

**Three layers:**

1. **`Shared/`** — Pure Swift domain logic, wrapped in a Swift Package (`SaferNightCore`) for deterministic testing. No SwiftUI, no SwiftData, no platform APIs here.
2. **`iOSApp/`** / **`WatchApp/`** — SwiftUI views + platform-specific services (location, permissions). Both consume `AppStore` via `@EnvironmentObject`.
3. **`Tests/`** — Unit tests for the `SaferNightCore` package only.

**State management:** `AppStore` (`Shared/Services/AppStore.swift`) is the single `@MainActor ObservableObject`. It holds all mutable state and is injected at the root of both apps. All services are protocol-injected into `AppStore` for testability.

**Drinking model:** `EstimationService` runs a dynamic standard-drink body-load simulation (config: `DrinkingModelConfig.v14`). Key params: 30-min absorption window, 0.8 std drinks/hr metabolism, 15-min lag, 20-min min absorption duration. The model spec lives in `drinking_model_algorithm/MODEL_SPEC_EN.md`.

**Session boundary:** Sessions run 11am-to-11am (`SessionClock`, `boundaryHour = 11`). A drink logged at 2 AM Saturday belongs to Friday night's session. Between 6–11 AM, if alcohol has cleared, `earlyMorningSummary` shows the previous session's summary without waiting for the boundary. `DefaultAppStoreSessionPolicy` also infers the "working tomorrow" flag from weekdays.

**Persistence:** SwiftData with CloudKit-first sync, local fallback. `PersistenceController` sets this up; `SwiftDataAppStorePersistence` wraps the operations behind a protocol.

**Location triggers:** `LocationMonitor` (iOS) / `WatchLocationMonitor` (Watch) detect venue exits and home arrivals to fire `ReminderService` evaluations.

**Voice parsing:** `DrinkParser` is regex-based. Input like "two pints of lager" → `ParsedDrinkIntent`.

**Burst-merge:** Drinks logged within 2 minutes of each other are merged to prevent model artifacts.

## Project configuration

The `.xcodeproj` is generated — never edit it directly. All project structure is declared in `project.yml` (XcodeGen). After modifying `project.yml`, run `xcodegen generate`.

`Package.swift` defines `SaferNightCore` (the testable core library) and `SaferNightCoreTests`. SwiftData models and persistence are excluded from the package (they require platform frameworks).

## Roadmap

### v0.2.0 — Backfill Logging

**Goal:** Let users log a drink they forgot to record in real time.

**Design decisions:**
- Backfilled entries are correct-by-timestamp: `SessionClock` automatically assigns them to the right session based on their timestamp, not when they were logged.
- Backfilling a past drink does **not** update the current session's live snapshot — it only affects historical session summaries (`previousSessionSummary`, `HistoryView`).
- Backfilled entries use `DrinkSource.edit` (already defined, unused).
- Watch sync works automatically via the existing `sendDrinksAdded` path.

**UI entry point:** Clock icon button (🕐) in the Quick Add card header (right side of title row, `TodayView.quickAddCard`). Tapping opens a sheet with:
1. Time picker — `DatePicker` scoped to the current session window (up to 24h back from now, capped at `SessionClock.boundaryHour` of the previous day)
2. Drink picker — reuses existing preset tiles and `detailSheet` flow
3. Confirm button — calls `AppStore.addBackfilledDrink()`

**AppStore changes:**
- Add `func addBackfilledDrink(category:servingName:volumeMl:abvPercent:timestamp:)` — same as `addQuickDrink` but accepts a custom `timestamp` and uses `source: .edit`. Does **not** call `recalculateSnapshot` (past session, no effect on current UI).

**Files to touch:**
- `Shared/Services/AppStore.swift` — add `addBackfilledDrink()`
- `iOSApp/Views/TodayView.swift` — add clock button + `BackfillSheet`
- `iOSApp/Views/BackfillSheet.swift` (new) — time picker + drink selector
