# MeetPR iOS

## V0 TestFlight Readiness

- AppIcon: ready with placeholder 1024 px light, dark, and tinted assets.
- Launch screen: ready with Info.plist `UILaunchScreen` brand-red background.
- Privacy manifest: ready for V0 local-demo behavior.
- Bundle ID: `com.meetpr.app` remains on the personal Apple Developer account for V0.
- Signing: automatic signing uses development team `XV97B4R4RZ`.
- Info.plist readiness: portrait-only iPhone, fitness category, copyright, and export-compliance keys are configured.

Next: W23 release engineering covers archive export, upload, TestFlight setup, App Store Connect metadata, and Apple review submission.

## Next Test Build

- Version `1.0` build `8`: includes student workout fixes for set numbers starting at `1`, visible coach notes in workout/history surfaces, default-completed past plan days shown as display-only (a `按计划推定` badge; assumed completions are excluded from e1RM/PR history and the Today growth curve), and automatic token refresh/retry after returning to an idle app.
