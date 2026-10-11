# ComposableKit

**A lightweight, dependency-free implementation of [The Composable Architecture](https://github.com/pointfreeco/swift-composable-architecture) (TCA) for SwiftUI apps that support iOS 15+.**

ComposableKit keeps Point-Free's API and names — `@Reducer`, `@ObservableState`, `Effect.run`, `@Dependency`, `@Shared`, `TestStore` — so the TCA documentation and examples apply. It runs on iOS 15, has no runtime dependencies, and works in Swift 5 and Swift 6 projects, with or without default `MainActor` isolation.

```swift
import ComposableKit

@Reducer
struct CounterFeature {
    @ObservableState
    struct State: Equatable {
        var count = 0
        var fact: String?
    }

    enum Action: Equatable {
        case incrementTapped
        case factTapped
        case factResponse(String)
    }

    @Dependency(\.numberFact) var numberFact

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .incrementTapped:
                state.count += 1
                return .none
            case .factTapped:
                return .run { [count = state.count, numberFact] send in
                    await send(.factResponse(try await numberFact.fetch(count)))
                } catch: { error, send in
                    await send(.factResponse(error.localizedDescription))
                }
            case let .factResponse(fact):
                state.fact = fact
                return .none
            }
        }
    }
}

struct CounterView: View {
    @ObservedObject var store: StoreOf<CounterFeature>

    var body: some View {
        VStack {
            Text("\(store.count)")
            Button("Increment") { store.send(.incrementTapped) }
            Button("Fact") { store.send(.factTapped) }
            if let fact = store.fact { Text(fact) }
        }
    }
}
```

---

## What is in this repository

The repository has four independent parts. Each one works on its own; none requires another.

| Part | Path | What it is |
|---|---|---|
| **ComposableKit** (Swift package) | [`Packages/ComposableKit`](Packages/ComposableKit) | The architecture library. Apps depend on it the same way they would depend on Point-Free's TCA. |
| **Scene generator** | [`composablekit-create.py`](composablekit-create.py) | An offline Python script that creates a new screen ("scene") in the ComposableKit pattern: 5 files ready to fill in. |
| **Testing skill** | [`.claude/skills/ios-tca-tests`](.claude/skills/ios-tca-tests/SKILL.md) | A [Claude Code](https://claude.com/claude-code) skill. Run it when a feature is done: it reads the scene's code, writes the unit tests (Swift Testing + `TestStore`), runs them and iterates until they pass. |
| **Example app** | [`POC_TCA`](POC_TCA) | A small iOS app that uses the package: a movie list (`Home`) and a movie details screen (`HomeDetails`), with fake OMDb-style data and full test coverage. |

The full architecture guide — components, rules, testing strategy, composition, comparisons with MVVM/VIP — is in [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

---

## Requirements

- **iOS 15+**
- **Xcode 26+** (Swift 6.2 toolchain). Apps can use the Swift 5 or Swift 6 language mode.
- Python 3 (only for the scene generator)
- Claude Code (only for the testing skill)

---

## Using the package

### 1. Add it to your app

ComposableKit is a regular Swift package. Add `Packages/ComposableKit` to your project (in Xcode: **File › Add Package Dependencies… › Add Local…**, or copy the folder into your repository) and link the **`ComposableKit`** product to your **app target only**.

Your test target does not link the package: it just uses `import ComposableKit` (linking it twice would load two copies of the library).

> To consume it as a remote dependency (by URL, like Point-Free's packages), publish `Packages/ComposableKit` in its own repository — SwiftPM expects `Package.swift` at the repository root — and tag a version (e.g. `1.0.0`).

### 2. Write features

The API is the same as TCA's:

| Concept | API |
|---|---|
| Feature | `@Reducer struct XFeature` with `@ObservableState struct State`, `enum Action`, `var body: some ReducerOf<Self>` |
| Effects | `.none`, `.send`, `.run { send in } catch: { error, send in }`, `.merge`, `.concatenate`, `.cancellable(id:cancelInFlight:)`, `.cancel(id:)`, `.debounce(id:for:clock:)` |
| Dependencies | `@Dependency(\.client)`, `DependencyKey` (`liveValue` / `testValue` / `previewValue`), `withDependencies`; built in: `continuousClock`, `uuid`, `date` |
| Composition | `Scope`, `.ifLet`, `.forEach` with `IdentifiedArrayOf`, `store.scope(state:action:)` |
| Forms | `BindableAction`, `BindingReducer()`, `$store.field` |
| Shared state | `@Shared(.inMemory / .appStorage / .fileStorage)`, `$value.withLock { }` |
| Reducer modifiers | `.onChange(of:)`, `.dependency(_:_:)`, `._printChanges()` |
| Testing | exhaustive `TestStore`, `TestClock`, `LockIsolated` |

Differences from the official TCA, all caused by iOS 15 support:

- The View uses `@ObservedObject var store: StoreOf<Feature>` (the `Store` is an `ObservableObject`); there is no `@Bindable` or `WithPerceptionTracking`.
- No `@Presents` / `StackState`: navigation goes through a `navigate` closure injected by whoever creates the screen (a Coordinator or router).
- `continuousClock` is an `EffectClock` with `sleep(for: Double)` in seconds.

See [section 4 of the guide](docs/ARCHITECTURE.md#4-the-composablekit-package) for the complete list.

### 3. Test

```swift
import ComposableKit
import Testing
@testable import MyApp

@MainActor
@Test
func factTappedShowsTheFact() async {
    let store = TestStore(initialState: CounterFeature.State(count: 3)) {
        CounterFeature()
    } withDependencies: { deps in
        deps.numberFact.fetch = { number in "\(number) is odd" }
    }

    await store.send(.factTapped)
    await store.receive(\.factResponse, "3 is odd") { state in
        state.fact = "3 is odd"
    }
}
```

**Required once per test target:** add [`ComposableKitTestSupport.swift`](POC_TCATests/Helpers/ComposableKitTestSupport.swift) to it. It routes `TestStore` failures to Swift Testing and isolates `@Shared` values per test — without it, failures only show up in the console and the test passes. The testing skill adds it automatically.

On a slow CI, raise the `TestStore` timeout (default 1 s) with `COMPOSABLEKIT_TEST_TIMEOUT=5` (`TEST_RUNNER_COMPOSABLEKIT_TEST_TIMEOUT=5` with `xcodebuild`).

---

## Creating a scene

A scene is one screen, split into 5 files:

```
SafeMode/
├── Core/SafeModeFeature.swift            ← State, Action, body, Route, analytics mapping
├── UI/SafeModeView.swift                 ← SwiftUI View + Factory (UIHostingController) + Preview
└── Service/
    ├── SafeModeService.swift             ← Response + Client (dependency) + URLSession service
    ├── SafeModeMapper.swift              ← Response → ViewData
    └── SafeModeAnalyticsModel.swift      ← analytics events
```

Generate it with:

```bash
python3 composablekit-create.py SafeMode ./MyApp/Scenes
```

- Works offline and prints the TODOs to fill in (API fields, endpoint, mapping, layout, analytics names).
- If the module has no analytics dependency yet, it also creates `Shared/Analytics/AnalyticsClient.swift` next to the scenes folder.
- An existing scene is never overwritten: only missing files are created. `--force` resets the scene to the template.
- The generated scene compiles as is (Swift 5 and Swift 6, iOS 15+). The View uses only native SwiftUI components — replace them with your design system freely.

The Factory returns a `UIViewController`, so scenes plug into UIKit navigation or into SwiftUI through `UIViewControllerRepresentable` (see [`POC_TCAApp.swift`](POC_TCA/POC_TCAApp.swift)).

---

## Generating tests with Claude Code

When the feature is done, run in Claude Code, inside your project:

```
/ios-tca-tests SafeMode
```

The skill reads the scene, writes 4 test files (Feature — reducer, navigation, analytics, Factory —, Mapper, Response decoding, fixtures), adds the test target helpers if they are missing, runs the tests with `xcodebuild` and fixes them until they pass. It optionally runs a mutation check to prove the tests catch bugs.

To use it in another project, copy [`.claude/skills/ios-tca-tests`](.claude/skills/ios-tca-tests) into that project's `.claude/skills/` folder (a standalone copy is also at [`ios-tca-tests.md`](ios-tca-tests.md)).

---

## Running the example app

Open `POC_TCA.xcodeproj` in Xcode 26+ and run the `POC_TCA` scheme on an iOS simulator. The package's macros need approval the first time (Xcode prompts for it).

```bash
# App tests
xcodebuild test -project POC_TCA.xcodeproj -scheme POC_TCA \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -skipMacroValidation -only-testing:POC_TCATests

# Package tests (179 tests + 6 macro tests)
cd Packages/ComposableKit && swift test
```

---

## Learn more

- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — the full guide: the pattern, each component, analytics, the View contract, testing strategy, complex scenes, shared state and known limitations.
- [Point-Free's TCA documentation](https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/) — the API reference ComposableKit mirrors.
