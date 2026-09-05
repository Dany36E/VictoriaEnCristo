# Functional and visual QA

Run `./scripts/run_visual_qa.ps1` from PowerShell. The runner fails on test errors;
screenshots are written to `build/qa` even for initial layout failures.

## Verified scope

The first suite uses the real SeriesDetailScreen and production series catalog.
It covers six logical viewports (320x568, 360x800, 430x932, 768x1024,
1024x768, 1366x768), each at text scale 1 and 1.6. Bundled Manrope and
MaterialIcons fonts are loaded. Missed taps are fatal. Each season header is
scrolled into view and tapped, with framework errors checked after each action.
It does not play videos or certify successful external links.

The Bible picker suite adds 108 viewport/text-scale/theme cases using the real
66-book RVR1960 index (six viewports, two text scales and all nine reader
themes). It opens the production modal, captures its rendering,
checks framework errors and taps the clipboard banner. It asserts that
Juan 3:16-18 returns book 43, chapter 3, verse 16 and verseEnd 18.
Firebase initialization and clipboard transport are mocked; no backend is contacted.
All GoogleFonts weight aliases are loaded from bundled font files to avoid Ahem
fallback producing false layout errors. Native clipboard permission is not tested.

Observed and fixed: four fixed chapter columns overflowed small phone cells;
chapter columns and height now adapt to available width/text scale. The header
wraps and larger text opens a taller sheet. Recent chips also expand vertically.
The original twelve viewport/text-scale cases passed after these changes; a
320x568, 1.6-scale PNG was inspected. The expanded 108-case theme matrix also
completed successfully in the final local run.
Visual review of the earlier PNGs also found Flutter's debug corner banner in
the capture boundary; it is now disabled so future evidence represents only the
product UI.

## Iteration protocol

`./scripts/run_android_qa_matrix.ps1` exercises Series and access sequentially
on small-phone (320x568 at 160 dpi, logical 320x568) and tablet
(768x1024 at 160 dpi, logical 768x1024) configurations of the same emulator.
These deliberately low-pixel-count profiles stress layout while reducing
software-emulator instability; they are not density-fidelity tests. The separate
1080x2400 at 420 dpi run provides the current high-density Android evidence.
It checks emulator identity before changing dimensions and restores previous
overrides in a finally block. If the emulator crashes, restoration can fail;
restart it and restore the recorded dimensions before another run.
The initial matrix hit exactly this case. Recovery was verified with ADB and
both width/density overrides were reset. Do not treat a partial matrix as passed.

Small-phone native access exposed overflows in the Google button and registration
toggle under large text. Their layouts now wrap. The original failed log is
retained as `build/qa/native/phone_small/access-before-fix.log`.

`./scripts/build_qa_gallery.ps1` creates `build/qa/index.html` from captured PNGs.
It is a visual inspection gallery, not a pass/fail gate. Check timestamps to avoid
confusing older captures with evidence from the latest source revision. The
gallery compares capture timestamps with relevant app/test sources and visibly
marks stale evidence.

1. Run the matrix, preserve failures and inspect rendered PNGs.
2. Check whether a failure is in the app or in the harness before editing.
3. Fix the observed cause, rerun affected tests and visually inspect the result.
4. Add behavioral assertions for regressions. Never hide overflow exceptions,
   missed taps, loading timeouts or backend failures to make a run green.
5. Report coverage and remaining gaps explicitly. Never label viewport
   simulations as physical-device or native iOS tests.

The agent performs fixes during an active authorized task. This script executes
tests, not an autonomous code-writing model. No unattended scheduler is installed.

The local access visual matrix covers login validation and the welcome CTA on
the same six viewport profiles and two text scales as Series. It sets the target
platform per profile so Android, iOS-family and Windows branches render as they
would for that platform. Firebase Core uses its test transport, no auth action is
submitted, and no remote account or Firestore document is created. It also
asserts that the fixed audio control cannot cover the welcome scroll viewport.

The onboarding matrix continues with the real giant-selection screen. Across
the same twelve viewport/text-scale cases it captures initial and selected
states, verifies the empty-selection warning, selects Mundo Digital and checks
the selected state/count. It stops before the Firebase-aware frequency screen;
the native access suite continues through frequency selection without saving,
so neither local completion state nor remote profile data is changed.

Static review while adding this matrix found fixed-height CTA rows and an
unreserved floating-audio area in the giant screens. Selection now reserves the
audio footprint, uses one/two/three adaptive grid columns with scale-aware card
height, and both selection/frequency CTAs allow wrapping instead of overflowing.
These corrections passed the complete twelve-case onboarding matrix, including
the 320x568 viewport at 1.6 text scale.

## Remaining coverage

Apple runtime availability: the user confirmed no Mac or Codemagic access.
Native iPhone/iPad execution remains unverified, independently of viewport tests.
When an Apple runner becomes available, use its installed Flutter/Xcode and an
available simulator UDID (obtain with `xcrun simctl list devices available`):

```sh
xcrun simctl boot <UDID>
xcrun simctl bootstatus <UDID> -b
flutter drive --driver=test_driver/visual_qa_driver.dart --target=integration_test/series_native_qa_test.dart -d <UDID>
flutter drive --driver=test_driver/visual_qa_driver.dart --target=integration_test/access_native_qa_test.dart -d <UDID>
```

Repeat for an iPhone and an iPad simulator; retain each run's `build/qa/native`
directory separately. Existing iOS project targets both families (`1,2`). There
is no local Mac, so `.github/workflows/visual-qa.yml` executes these commands on
GitHub-hosted macOS runners. Local Firebase config files must never be uploaded
in reports.

Access runner: `./scripts/run_native_qa.ps1 -Device emulator-5554 -Suite access`.
It checks empty-form validation without submitting credentials, edits an invalid
email, captures login/welcome at text scales 1 and 1.6, and ensures the welcome
CTA can be scrolled into view. Editing through WidgetTester is not proof of the
OS keyboard's visual behavior; a separate physical-keyboard/IME test is needed.
The login screen creates its authentication service only when the user submits
an authentication action. This layout-only suite does not submit one, initialize
Firebase or contact a Firebase project.

Native access/welcome iteration found actual overflow in the welcome screen at
1.6 text scale: fixed-height content and an unbounded CTA row. The screen now
scrolls when needed, preserves its full-height spacing on larger displays, and
allows the CTA label to wrap. Visual review also found an intra-word split in
the title; its longest word is now measured against available width. Body text
continues to respect the user's text scaling. Latest evidence resides in
`build/qa/access-native.log` and `build/qa/native/welcome*_1_6.png`.
Final access run passed both text scales on the Android emulator. The final
`welcome_action_1_6.png` was inspected: title word remains whole, privacy card
and complete CTA are visible after scrolling, without overflow stripes.
The 320x568 native profile also found an over-wide frequency chip at text scale
1.6. Frequency labels now wrap within the available chip width, and the access
runner scrolls virtualized onboarding content into a tappable position.

Local full suite after the picker, access and onboarding fixes: 349 tests passed.
This is the scope of existing unit/widget tests, not 349 end-to-end functions.

Native Series runner: `./scripts/run_native_qa.ps1 -Device emulator-5554`.
Uses the real catalog and UI, exercises five season expansions/collapses and
back navigation, and saves emulator screenshots via the host driver under
`build/qa/native`. Does not sign in, modify user records or play episodes.
Verified native run: Android emulator `Medium_Phone_API_36.1`, 1080x2400,
420 dpi, completed successfully. Seven nonempty PNGs were produced. Catalog
and season 2 screenshots were visually inspected. Log: `build/qa/native-run.log`.
ADB initially reported unauthorized; restarting the host ADB server restored
the emulator connection without resetting its data.
Do not pass `--no-pub` after a release build: it can leave the development
integration_test plugin absent from GeneratedPluginRegistrant.

- Full Bible reading, study and sermon flows beyond the picker/clipboard range.
- Authenticated login and onboarding persistence, home, plans, journal,
  progress, settings and guardian flows.
- Safe areas, keyboard, orientation, offline failures and larger accessibility text.
- Native Android media, permissions, VPN and lifecycle.
- Native iPhone/iPad cannot run locally on Windows; GitHub Actions provides the
  current simulator coverage.
- Authenticated tests need isolated test accounts/backend; existing integration
  suites must be reviewed before running because some target remote accounts.

At initial discovery, adb returned no attached devices and the sandboxed emulator
returned no AVDs. A subsequent permitted profile query found
`Medium_Phone_API_36.1`; its headless startup was launched for native testing.
Windows cannot execute an iOS simulator. Device availability
must be rechecked before concluding a later run is blocked.

## Research

`.github/workflows/visual-qa.yml` is the unattended CI entry point. On pushes,
pull requests and manual dispatch it runs the viewport matrix, an Android
emulator matrix, and separate iPhone/iPad simulator jobs. Every job uploads its
logs, screenshots, result JSON and HTML gallery for 30 days, including failures.
The workflow uses only checked-in example configuration and a dummy Android
Firebase descriptor; its access suite never initializes Firebase. It must never
exercise production accounts or write user data. Apple execution is provided by
GitHub's macOS runners and its current status is visible in Actions.

GitHub documents `macos-latest` as a hosted macOS VM label; each hosted job gets
a fresh VM. This makes it the practical simulator path when no local Mac or
Codemagic account is available, while Firebase Test Lab remains the stronger
later-stage option for a matrix of hosted iOS device models.

The Android CI runner follows the action's documented responsibility for
creating an AVD, waiting for boot, executing a script and stopping the emulator:
[ReactiveCircus Android Emulator Runner](https://github.com/ReactiveCircus/android-emulator-runner)

Flutter recommends combining unit/widget and integration tests, and documents
`flutter drive` for execution on a physical device or emulator:
[Flutter testing overview](https://docs.flutter.dev/testing/overview) and
[Flutter integration testing](https://docs.flutter.dev/testing/integration-tests)

Firebase Test Lab accepts Flutter integration tests as Android instrumentation
and iOS XCTest bundles and offers real-device execution:
[Flutter integration testing with Firebase Test Lab](https://firebase.google.com/docs/test-lab/flutter/integration-testing-with-flutter)

GitHub-hosted runner reference:
[Choosing the runner for a job](https://docs.github.com/en/actions/how-tos/write-workflows/choose-where-workflows-run/choose-the-runner-for-a-job)

Remote runs, credentials and availability are not yet verified. No remote test
results are claimed by this local matrix.
