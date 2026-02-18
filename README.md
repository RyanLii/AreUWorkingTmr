# Last Round?

`Safer Night Companion` for Apple Watch + iPhone companion.

## Repository standards

- License: MIT (`LICENSE`)
- Contribution guide: `CONTRIBUTING.md`
- Security policy: `SECURITY.md`
- Code of conduct: `CODE_OF_CONDUCT.md`
- CI: GitHub Actions (`.github/workflows/ci.yml`)

## What is implemented

- Watch-first flow:
  - `Quick Add` (Beer/Wine/Shot/Cocktail/Spirits/Custom)
  - category detail logging with size + ABV + count + `Use Default`
  - watch-side permission/runtime loop for standalone operation
    - HealthKit read (when available) updates weight/biological sex inputs
    - location monitoring (when available) drives missed-log + home-arrival hooks
    - graceful fallback when Health/location is unavailable
  - regional serving templates (US/AU/UK) for beer/wine/shot defaults
  - `Impact Preview` before logging (estimated drive-time impact)
  - `Voice Log` (dictation text parser -> structured drink entries)
  - `Live Status` (state, BAC estimate, likely drive-time estimate)
  - `Timeline` (recent entries)
- iPhone companion:
  - `Today`, `History`, `Profile`, `Reminders`, `Privacy`
  - first-launch onboarding with explicit estimate acknowledgment
  - permission controls for Notifications, Location, HealthKit read
  - HealthKit profile merge when authorization is available
  - location-monitor hooks for missed-log and home-hydration reminders
  - in-app review prompt milestones based on completed nights
- Shared core domain:
  - standard-drink conversion with regional definitions (US/AU/UK)
  - personalized Widmark-style BAC estimate
  - minute-level BAC timeline sampling for tighter ETA precision
  - category-aware non-linear absorption curve + sex-aware metabolism rate
  - near-term peak-aware intoxication state to avoid rapid-log underreporting
  - region-based drive-threshold estimates using local legal-limit mapping (AU/US/UK)
  - hydration recommendation by body-weight + drink load
- Architecture:
  - `AppStore` refactored with protocol-injected session policy + persistence
- Persistence:
  - SwiftData models with CloudKit-first container and local fallback
- Tests:
  - parser, estimation, reminder logic

## Project structure

- `/Users/ryanlee/Development/AreUWorkingTmr/project.yml`: XcodeGen spec for iOS + watchOS app targets
- `/Users/ryanlee/Development/AreUWorkingTmr/Shared/`: shared domain models and services
- `/Users/ryanlee/Development/AreUWorkingTmr/iOSApp/`: iPhone UI + permission/location services
- `/Users/ryanlee/Development/AreUWorkingTmr/WatchApp/`: watchOS UI and app entry
- `/Users/ryanlee/Development/AreUWorkingTmr/Tests/`: core logic tests
- `/Users/ryanlee/Development/AreUWorkingTmr/Package.swift`: local Swift package wrapper for deterministic core test runs
- `/Users/ryanlee/Development/AreUWorkingTmr/scripts/generate_app_icon_master.swift`: custom icon master generator

## Run locally

1. Generate Xcode project

```bash
xcodegen generate
```

2. Run core tests (works without iOS/watch simulator runtime)

```bash
swift test
```

3. Build app targets

```bash
xcodebuild -project AreUWorkingTmr.xcodeproj -scheme AreUWorkingTmr build
xcodebuild -project AreUWorkingTmr.xcodeproj -scheme AreUWorkingTmrWatch build
```

## Icon assets

- iOS iconset path:
  - `/Users/ryanlee/Development/AreUWorkingTmr/iOSApp/Resources/Assets.xcassets/AppIcon.appiconset`
- watchOS iconset path:
  - `/Users/ryanlee/Development/AreUWorkingTmr/WatchApp/Resources/Assets.xcassets/AppIcon.appiconset`
- Master artwork:
  - `/Users/ryanlee/Development/AreUWorkingTmr/artifacts/icon-build/icon-master-1024.png`

Regenerate master icon:

```bash
swift scripts/generate_app_icon_master.swift artifacts/icon-build/icon-master-1024.png
```

## Product philosophy

- This app is a sweet night companion.
- It is not a spending tracker and not a behavior-shaming tool.
- It focuses on one thing only: helping tonight end safer and tomorrow feel better.
- BAC and drive-time outputs are friendly estimates only; they are not legal advice or legal proof.

## 1.1 backlog

- Regional icon packs for drink types:
  - users can choose drink icons from top regional styles (target: top 20 icon options per region)
  - examples: beer glass variants, wine vessel variants, local shot/cocktail visual styles
