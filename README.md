<p align="center">
  <img src="logo.png" width="200" alt="To-Do">
</p>

# To-Do

![Static Badge](https://img.shields.io/badge/platform-iOS-white)
![Static Badge](https://img.shields.io/badge/latest_release-v1.0.0-green)
![Static Badge](https://img.shields.io/badge/swift-v5.0-orange)

[![CI](https://github.com/freegatik/To-Do/actions/workflows/ci.yml/badge.svg)](https://github.com/freegatik/To-Do/actions/workflows/ci.yml)

Native **UIKit** app (Swift **5**, iOS **15.6** minimum) for an offline-first task list. On first launch it imports seed data from **[dummyjson.com/todos](https://dummyjson.com/todos)** and persists with **Core Data**; afterwards CRUD, search, and filters run locally. **VIPER** modules **`TodoList`** (table, pull-to-refresh, voice search via **Speech** / **AVFoundation**, context menu) and **`TodoEditor`** (validation, share sheet). **`TodoRepository`** coordinates networking, Core Data, and domain models (`Domain/` vs DTOs in `Data/Networking`).

## CI

Workflow [`.github/workflows/ci.yml`](.github/workflows/ci.yml) on [GitHub Actions](https://github.com/freegatik/To-Do/actions) for **`push`**, **`pull_request`**, and **`workflow_dispatch`**. **`concurrency`** with **`cancel-in-progress`** limits duplicate runs per ref.

| Job | What it runs |
|-----|----------------|
| **SwiftLint** | **`macos-15`**, prefers **Xcode 16.2** then **Xcode.app**; installs SwiftLint via Homebrew if missing; **`swiftlint lint`** with GitHub Actions reporter ([`.swiftlint.yml`](.swiftlint.yml)) |
| **Build** | **`xcodebuild build`** for **`To-Do`** / **`To-Do.xcodeproj`**, **`generic/platform=iOS Simulator`**, **`EXCLUDED_ARCHS=x86_64`**, **`ONLY_ACTIVE_ARCH=YES`** |
| **Static analysis** | **`xcodebuild analyze`** with the same simulator destination pattern |
| **Tests + coverage** | [`prepare-ios-ci.sh`](.github/scripts/prepare-ios-ci.sh) (iOS platform / first launch), creates **`To-Do CI`** simulator via [`ensure-ci-simulator.sh`](.github/scripts/ensure-ci-simulator.sh), resolves **`-destination`** with [`xcode-sim-destination.sh`](.github/scripts/xcode-sim-destination.sh) (**UDID**, avoids **`name=` + implicit OS:latest** mismatches); **`xcodebuild test`** with **`-enableCodeCoverage YES`**, **`-resultBundlePath TestResults.xcresult`**, single parallel worker; **`xccov`** report in log; uploads **`TestResults.xcresult`** + **`coverage-targets.txt`** on **`always()`**; optional **Codecov** when **`CODECOV_TOKEN`** is set |

**Environment:** workflow pins **`DEVELOPER_DIR`** to **`Xcode.app`** by default and **`IPHONEOS_DEPLOYMENT_TARGET: "15.6"`** (aligned with the Xcode project).

## Requirements

- **Xcode 16.x** (CI targets **Xcode 16.2** when installed on the runner)
- **macOS 15+**-class runner image (**`macos-15`** in CI)
- Simulator **iOS ≥ 15.6**; locally you can use any compatible device (e.g. **iPhone 17 Pro** with a recent iOS as in your own checks)

## Getting started

```bash
git clone https://github.com/freegatik/To-Do.git
cd To-Do
open To-Do.xcodeproj
```

Use the **To-Do** scheme: **⌘R** to run, **⌘U** for tests. For UI tests that should skip the first network import, pass the launch argument **`--uitest`**.

## Project layout

| Area | Path / notes |
|------|----------------|
| Lifecycle | `To-Do/Application/` (`AppDelegate`, `SceneDelegate`) |
| VIPER modules | `To-Do/Modules/TodoList/`, `To-Do/Modules/TodoEditor/` |
| Data | `To-Do/Data/` (Core Data stack, **`TodoRepository`**, **`TodoAPIClient`**, API models) |
| Domain | `To-Do/Domain/` |
| Shared UI helpers | `To-Do/Common/` |
| Model file | `To-Do/To_Do.xcdatamodeld/` |
| Unit tests | `To-DoTests/` |
| UI tests | `To-DoUITests/` |

## Testing

CI runs **unit + UI** tests in one **`xcodebuild test`** invocation. Locally (pick a destination that exists on your Mac):

```bash
xcodebuild test \
  -project To-Do.xcodeproj \
  -scheme "To-Do" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=18.1' \
  -enableCodeCoverage YES \
  -resultBundlePath /tmp/To-Do.xcresult
xcrun xccov view --report /tmp/To-Do.xcresult | head -40
```

Lint (same config as CI):

```bash
swiftlint lint --reporter github-actions-logging
```

## License

Published under the [MIT License](LICENSE). Third-party APIs, assets, and simulator-only resources remain subject to their respective terms.
