# PhotoSweep

PhotoSweep is an iOS-first SwiftUI app that gamifies camera-roll cleanup with a swipeable card flow. It uses PhotoKit for local photo access and deletion, SwiftData for local metadata, and keeps all processing on-device.

## What is included

- SwiftUI iOS app target in `PhotoSweep.xcodeproj`
- PhotoKit permission handling for full, limited, denied, restricted, and empty states
- Swipe card UI: left queues for deletion, right keeps, tap previews, undo supported
- Delete queue review grid with per-item unselect
- Final confirmation before any Photos library mutation
- Real deletion via `PHPhotoLibrary.performChanges` and `PHAssetChangeRequest.deleteAssets`
- Local SwiftData persistence for reviewed statuses, sessions, and stats
- XP, levels, daily streak progress, and storage-selected progress rings
- Unit tests for session and stats logic
- Bonus feature flags for smart cleanup modes, maybe-later review, storage goals, timers, grouped delete review, achievements, monthly reports, and privacy mode scaffolding

## Run on a real iPhone

1. Open `PhotoSweep.xcodeproj` in Xcode.
2. Select the `PhotoSweep` scheme.
3. In Signing & Capabilities, choose your Apple development team.
4. Connect an iPhone running iOS 17 or newer.
5. Build and run on the device.
6. Tap `Connect Photos` and choose either full access or limited access.

Photo library deletion cannot be fully validated in a simulator. Use a real device and test with disposable photos first.

## Privacy and deletion flow

PhotoSweep stores only asset identifiers and metadata locally. It does not store full photo files, upload photos, require login, add ads, or sync to cloud services.

Swiping left never deletes immediately. It marks the asset as `delete`, persists that status locally, and adds the item to the delete queue. The native Photos deletion API is called only after the user opens the delete review screen, leaves the desired items selected, and confirms the final deletion modal.

Bonus analysis features are local-only. Duplicate, similar, blurry, document, and meme modes use on-device metadata and thumbnail analysis. They produce suggestions and badges only; they never delete anything or bypass the final review screen.

## Bonus features

- Smart cleanup mode explanations before starting
- Duplicate/similar candidates grouped locally with recommended-keep badges
- Blurry-photo badgeging through thumbnail sharpness analysis
- Storage goals and timed cleanup sessions
- Maybe Later upward swipe and follow-up session
- Smart delete review grouped by screenshots, blurry, duplicates, videos, old photos, and other
- Session history with kept/delete/maybe-later timeline
- Daily challenges, levels, achievements, and personality messages
- Monthly camera-roll report card
- Freemium plan design without payment implementation
- Privacy mode scaffolding for app-switcher blur and Face ID/Touch ID lock; disabled by default in `FeatureFlags` so the MVP stays frictionless

## Project structure

```text
PhotoSweep/
  Models/          Domain models and cleanup filters
  Persistence/     SwiftData models and persistence helpers
  Services/        PhotoKit, deletion, sessions, stats, haptics
  ViewModels/      MVVM state and screen actions
  Views/           Onboarding, dashboard, swipe, summary, delete review
  Utilities/       Formatting helpers
PhotoSweepTests/   Session and stats unit tests
```

## Notes

This workspace also includes `Package.swift` so the pure session/stat logic can be checked without launching the iOS app. The app's Xcode test target uses XCTest; the package test path uses Swift Testing because this machine's Command Line Tools install does not expose XCTest.
