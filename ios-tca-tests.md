---
name: ios-tca-tests
description: Generates the unit tests (Swift Testing + TestStore) for a ComposableKit scene (the 5-file pattern: Feature, View + Factory, Service, Mapper, AnalyticsModel) — Feature (reducer, navigation, analytics, Factory), Mapper and Response decoding. Use it when a feature is done and needs its tests, or to complete a scene's tests.
version: 6.0.0
---

# ios-tca-tests

Generates the tests of a scene that follows the ComposableKit pattern (TCA syntax). The tests use **Swift Testing** and the package's **`TestStore`** — the same API as Point-Free's TCA:

- `await store.send(.action) { state in state.field = expectedValue }` — checks the state change.
- `await store.receive(\.didLoad) { ... }` — checks each Action sent by an effect.
- The test fails if an Action is left unchecked, an effect is still running, or a state change is not declared (**exhaustive** mode).
- Dependencies are overridden in `withDependencies:` — no spy classes, no `sleep`/`waitUntil`.

**One test file per production responsibility:** reducer/navigation/analytics/Factory in `FeatureTests` (in nested `@Suite`s), transformation in `MapperTests`, API contract in `ResponseTests`. No suite checks another one's work.

> **Maintenance:** do not write `$` followed by a number in this file. When the skill is invoked with an argument (e.g. `/ios-tca-tests SafeMode`), Claude Code replaces those tokens with the argument and the code samples arrive corrupted. Use named closure parameters (`state in`, `deps in`, `list in`).

---

## Invocation

`/ios-tca-tests` — ask for the scene name and/or the test target if they were not passed.

## Execution steps

1. If the scene did not come as an argument (`/ios-tca-tests SafeMode`), ask: "What is the scene name? (e.g. SafeMode)"
2. If you cannot figure it out, ask: "Which module is the scene in, and in which test target/folder should I create the files?"
3. Derive:
   - `SCENE` = scene name (PascalCase), e.g. `SafeMode`
   - `SCENE_CAMEL` = lowercase first letter, e.g. `safeMode` (dependency `safeModeClient`)
   - `MODULE` = the `@testable import` module, e.g. `Invest`
4. **Read the scene's 5 files before writing any test.** The templates below reflect the default scene template; **the real code wins**. Note:
   - the cases of `Action` and `{SCENE}Route`
   - what each Action does in `body`: State fields it changes and effects (`.run`, `.send`, `.cancellable`, navigation)
   - the endpoints of `{SCENE}Client` and which Actions call them
   - the fields of `{SCENE}Response` and `{SCENE}ViewData` and each field's rule in the Mapper
   - the `switch` in `analyticsEvent(for:state:)` (and which events use `state` data) and the properties of each struct in `{SCENE}AnalyticsModel`
   - the signature of `{SCENE}Factory.make(...)`
   - where the API JSON for `ResponseTests` comes from (P8)
5. Run the **preflight** and apply what each item asks for
6. Write the files, adapting them to the real code ("Coverage rules" section)
7. **Run the scene's suite and iterate until it is green** ("Execution" section). Do not finish with only the files written
8. Show the developer: file tree, preflight result, command used and result (passed/failed, known issues, mutation proof). If the suite did **not** run, say so explicitly, with the reason and the command. **Never** claim the tests pass without having run them

---

## Preflight

| # | Check | How | If it fails |
|---|---|---|---|
| P1 | The target supports Swift Testing | `import Testing` in other tests; Xcode 16+ | **Stop**: "The target does not support Swift Testing." |
| P2 | The scene's tests do not exist | Look for `{SCENE}FeatureTests`, `{SCENE}MapperTests` | If they exist, **ask** whether to complete or overwrite them. Never overwrite without confirmation |
| P3 | The scene follows the current pattern | `@Reducer struct {SCENE}Feature` and `@Dependency(\.{SCENE_CAMEL}Client)` | If it is an older pattern (`{SCENE}Store`, `{SCENE}ViewModel`, Coordinator per scene): **stop** and ask to migrate the scene to the ComposableKit pattern first |
| P4 | The test target sees `ComposableKit` | `import ComposableKit` compiles in the test target | Do not add the package to the test target as a linked dependency (that would load two copies of the library). If the import fails, tell the developer |
| P5 | The shared helpers exist and are up to date | `Helpers/ComposableKitTestSupport.swift` (class `ComposableKitTestSupport`, **with `currentTestScope`**) and `Helpers/NSError+Fixture.swift` (**with `nonisolated static func fixture`**) | Create only what is missing. Old version: replace it with the template below — without `currentTestScope`, `@Shared` values leak between tests; without `nonisolated` there are warnings in targets with default MainActor isolation. **Without `ComposableKitTestSupport`, TestStore failures only show up in the console and the test passes** |
| P6 | `{SCENE}AnalyticsModel` has no placeholders | `// TODO` in the file | **Ask** for the tracking spec. Without the spec: generate without the `*ShouldMatchSpec` tests and record it as pending |
| P7 | The module has the analytics dependency | `extension DependencyValues { var analytics: AnalyticsClient }` in the module or in a shared module | Tell the developer: the Feature does not compile without it (the scene generator creates `Shared/Analytics/AnalyticsClient.swift` when it is missing) |
| P8 | There is a sample of the API JSON | Endpoint contract/OpenAPI, real response, backend mock | **Ask** the developer. Without a sample: generate `ResponseTests` with the template only (empty Response) or record it as pending — **never** build the JSON by copying the `CodingKeys` |
| P9 | The test target runs on iOS 16+ | The test target's `IPHONEOS_DEPLOYMENT_TARGET` (`.timeLimit` requires iOS 16) | Below 16: remove `, .timeLimit(.minutes(1))` from the `@Suite`s and note it in the summary |

---

## What is tested

| Scene file | Suite | What it guarantees | How |
|---|---|---|---|
| `{SCENE}Feature.body` | `FeatureTests` › `Reducer` | Each Action changes the right state; each effect sends the right Actions, in order; a repeated `tapRetry` does not duplicate responses; a reload failure keeps the content and shows the error; `viewDidAppear` with content does not reload; `tapClose` cancels the fetch; each `tap*` delivers the right `Route`, on the main thread | `TestStore` + overridden client, `TestClock`, `LockIsolated<[Route]>` |
| `analyticsEvent(for:state:)` | `FeatureTests` › `Analytics` | The right event per Action (pure function) + one integration test with `AnalyticsClient` | `deps.analytics.track` |
| `{SCENE}Factory.make` (in the View file) | `FeatureTests` › `Factory` | Returned type, initial state, `navigate` closure wired | Real `Store` |
| `{SCENE}Mapper` | `MapperTests` | `Response` → `ViewData`, field by field | literal values |
| `{SCENE}Response` (in the Service file) | `ResponseTests` | The API JSON decodes into the `Response` (`CodingKeys`, optionals, required fields) | Literal JSON with the **API's** keys |
| `{SCENE}View`, `{SCENE}Service` (the type) | — | No logic / depend on the network | — |

> **Outside the scene:** whoever implements `navigate` (the module's Coordinator, the app router) has its own tests — see "Who implements `navigate`".

---

## Folder structure

```
{Target}Tests/
├── Helpers/                         ← once per target
│   ├── ComposableKitTestSupport.swift
│   └── NSError+Fixture.swift
└── .../{SCENE}/                     ← same relative path as the scene (e.g. Scenes/{SCENE}/)
    ├── {SCENE}FeatureTests.swift    ← @Suite Reducer · Analytics · Factory
    ├── {SCENE}MapperTests.swift
    ├── {SCENE}ResponseTests.swift
    └── Helpers/
        └── Fixture+{SCENE}.swift
```

## Imports

The tests only import `ComposableKit`, `Testing`, `SwiftUI` (for `UIHostingController.rootView`) and the scene's module. Types from other app modules arrive through `@testable import {MODULE}`; if the compiler requires it (MemberImportVisibility), import them explicitly.

---

## Shared helpers

### `Helpers/ComposableKitTestSupport.swift`

Routes the failures detected by `ComposableKit` (TestStore assertions, dependencies without a test value, effects with unhandled errors) to Swift Testing. **Without this file, tests do not fail.**

```swift
import Foundation
import ComposableKit
import Testing

/// Routes problems detected by ComposableKit (TestStore assertions,
/// dependencies without a test value, effects with unhandled errors)
/// to Swift Testing failures, and gives each test its own `@Shared` values.
/// Copy this file, unchanged, into each module's test target.
/// Without it, tests do NOT fail.
@objc(ComposableKitTestSupport)
final class ComposableKitTestSupport: NSObject, ComposableKitTestIssueReporting {
    static func reportIssue(_ message: String, fileID: String, filePath: String, line: Int, column: Int) {
        let location = SourceLocation(
            fileID: fileID,
            filePath: filePath,
            line: max(1, line),
            column: max(1, column)
        )
        if Test.current != nil {
            Issue.record(Comment(rawValue: message), sourceLocation: location)
        } else {
            print("⚠️ [ComposableKit] \(location) — \(message)")
        }
    }

    /// The running test: each test has its own `@Shared` values
    /// (parallel tests do not see each other).
    @objc static func currentTestScope() -> String? {
        guard let test = Test.current else { return nil }
        return ([test.id.moduleName] + test.id.nameComponents).joined(separator: ".")
    }
}
```

### `Helpers/NSError+Fixture.swift`

```swift
import Foundation

extension NSError {
    // `nonisolated`: it is called inside the clients' `@Sendable` closures
    // (`fetchData = { throw NSError.fixture() }`), outside the MainActor.
    nonisolated static func fixture(message: String = "connection error") -> NSError {
        NSError(domain: "Tests", code: 0, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
```

---

## Scene fixtures

### `{SCENE}/Helpers/Fixture+{SCENE}.swift`

```swift
import Foundation // URL, Date, Decimal... (with MemberImportVisibility they do not come through @testable import)
@testable import {MODULE}

extension {SCENE}Response {
    // `nonisolated`: it is called inside the clients' `@Sendable` closures
    // (`fetchData = { .fixture() }`), outside the MainActor. Without it, in a test
    // target with default MainActor isolation: a warning in Swift 5, an error in Swift 6.
    nonisolated static func fixture() -> {SCENE}Response {
        {SCENE}Response()
    }
}

extension {SCENE}Feature.{SCENE}ViewData {
    // `nonisolated` (the template's ViewData is too): usable in `@Test(arguments:)`.
    nonisolated static func fixture() -> {SCENE}Feature.{SCENE}ViewData {
        {SCENE}Feature.{SCENE}ViewData()
    }
}
```

**Rules**:
- When `Response`/`ViewData` have fields, each field becomes a parameter with a default value: `static func fixture(id: String = "fixture-id", ...)`. The fixtures of the `Response` (and of its nested types) and of the `ViewData` are **`nonisolated static func`**: they run inside the clients' closures and in `@Test(arguments:)`. Older scene, with a `struct ViewData` without `nonisolated`: mark the `ViewData` as `nonisolated struct` (or drop `nonisolated` from its fixture and do not use it in `arguments:`).
- **Consistency:** when a Feature test overrides a field of the Response fixture (`.fixture(trackingCode: nil)`), override the matching field of the ViewData fixture (`.fixture(trackingCode: nil, trackingText: "No tracking code")`) — or use `.fixture()` on both sides. When the test **injects the ViewData straight into the initial state** (`initialState.viewData = .fixture(barcode: nil)`) and does not go through the client, only the ViewData fixture matters.
- **Data from outside the State** (`State(itemID:)`): keep the literal in a `private let itemID = "item-1"` at file scope and use it in every `State(...)`, in `makeStore` and in the assertions.
- **Fixture contract:** `{SCENE}ViewData.fixture()` is **exactly** what the Mapper produces from `{SCENE}Response.fixture()`. The Feature tests use `.fixture()` on both sides (without calling the Mapper); the `mapFixtureResponseShouldProduceFixtureViewData` test in `MapperTests` enforces the contract.

---

## `{SCENE}FeatureTests.swift`

```swift
import ComposableKit
import Foundation
import SwiftUI // UIHostingController.rootView (MemberImportVisibility)
import Testing
@testable import {MODULE}

// ╔══════════════════════════════════════════════════════════════╗
// ║  {SCENE} Feature Tests                                       ║
// ║  Reducer (state, effects, navigation) · Analytics · Factory  ║
// ║  The Mapper is not called here: the expected value is        ║
// ║  `.fixture()` (fixture contract, enforced in MapperTests).   ║
// ╚══════════════════════════════════════════════════════════════╝

@MainActor
@Suite("{SCENE} Feature", .timeLimit(.minutes(1)))
struct {SCENE}FeatureTests {

    // MARK: - Reducer

    @MainActor
    @Suite("Reducer")
    struct ReducerTests {

        @Test
        func viewDidAppearWhenServiceSucceedsShouldShowViewData() async {
            let store = makeStore { deps in
                deps.{SCENE_CAMEL}Client.fetchData = { .fixture() }
            }

            await store.send(.viewDidAppear) { state in
                state.isLoading = true
            }
            await store.receive(\.didLoad, .fixture()) { state in
                state.isLoading = false
                state.viewData = .fixture()
            }
        }

        @Test
        func viewDidAppearWhenServiceFailsShouldShowError() async {
            let store = makeStore { deps in
                deps.{SCENE_CAMEL}Client.fetchData = { throw NSError.fixture(message: "connection error") }
            }

            await store.send(.viewDidAppear) { state in
                state.isLoading = true
            }
            await store.receive(\.didFail, "connection error") { state in
                state.isLoading = false
                state.errorMessage = "connection error"
            }
        }

        @Test
        func tapRetryShouldClearErrorAndReload() async {
            var initialState = {SCENE}Feature.State()
            initialState.errorMessage = "previous error"
            let store = makeStore(initialState) { deps in
                deps.{SCENE_CAMEL}Client.fetchData = { .fixture() }
            }

            await store.send(.tapRetry) { state in
                state.isLoading = true
                state.errorMessage = nil
            }
            await store.receive(\.didLoad) { state in
                state.isLoading = false
                state.viewData = .fixture()
            }
        }

        /// The View's `.task` sends `viewDidAppear` again when coming back from a pushed screen.
        @Test
        func viewDidAppearWithLoadedContentShouldNotReload() async {
            var initialState = {SCENE}Feature.State()
            initialState.viewData = .fixture()
            // No client: the testValue fails the test if the request is made.
            let store = makeStore(initialState)

            await store.send(.viewDidAppear)
            await store.finish()
        }

        /// "Try again" with content on screen that fails: the content stays
        /// and the error shows up (the View shows a warning above the content).
        @Test
        func tapRetryWithLoadedContentWhenServiceFailsShouldKeepViewDataAndShowError() async {
            var initialState = {SCENE}Feature.State()
            initialState.viewData = .fixture()
            let store = makeStore(initialState) { deps in
                deps.{SCENE_CAMEL}Client.fetchData = { throw NSError.fixture(message: "connection error") }
            }

            await store.send(.tapRetry) { state in
                state.isLoading = true // viewData does not change
            }
            await store.receive(\.didFail, "connection error") { state in
                state.isLoading = false
                state.errorMessage = "connection error"
            }
        }

        /// Already loaded content stays on screen while reloading.
        @Test
        func tapRetryWithLoadedContentShouldKeepViewDataWhileReloading() async {
            var initialState = {SCENE}Feature.State()
            initialState.viewData = .fixture()
            let store = makeStore(initialState) { deps in
                deps.{SCENE_CAMEL}Client.fetchData = { .fixture() }
            }

            await store.send(.tapRetry) { state in
                state.isLoading = true // viewData does not change
            }
            await store.receive(\.didLoad) { state in
                state.isLoading = false
            }
        }

        @Test
        func tapRetryTwiceShouldCancelFirstRequest() async {
            let clock = TestClock()
            let calls = LockIsolated(0)
            let store = makeStore { deps in
                deps.{SCENE_CAMEL}Client.fetchData = {
                    calls.withValue { count in count += 1 }
                    try await clock.sleep(for: 1)
                    return .fixture()
                }
            }

            await store.send(.tapRetry) { state in
                state.isLoading = true
            }
            await store.send(.tapRetry)
            await clock.advance(by: 1)
            await store.receive(\.didLoad) { state in
                state.isLoading = false
                state.viewData = .fixture()
            }
            #expect(calls.value == 2) // two requests, a single response
        }

        // Navigation

        @Test
        func tapContinueShouldNavigateToNextPage() async {
            let routes = LockIsolated<[{SCENE}Route]>([])
            let store = makeStore(navigate: { route in routes.withValue { list in list.append(route) } })

            await store.send(.tapContinue)
            await store.finish()

            #expect(routes.value == [.nextPage])
        }

        @Test
        func tapCloseShouldNavigateBack() async {
            let routes = LockIsolated<[{SCENE}Route]>([])
            let store = makeStore(navigate: { route in routes.withValue { list in list.append(route) } })

            await store.send(.tapClose)
            await store.finish()

            #expect(routes.value == [.back])
        }

        /// Leaving the screen cancels the fetch: no response arrives after `tapClose`.
        @Test
        func tapCloseWhileLoadingShouldCancelRequestAndNavigateBack() async {
            let clock = TestClock()
            let routes = LockIsolated<[{SCENE}Route]>([])
            let store = makeStore(
                dependencies: { deps in
                    deps.{SCENE_CAMEL}Client.fetchData = {
                        try await clock.sleep(for: 1)
                        return .fixture()
                    }
                },
                navigate: { route in routes.withValue { list in list.append(route) } }
            )

            await store.send(.viewDidAppear) { state in
                state.isLoading = true
            }
            await store.send(.tapClose)
            await clock.advance(by: 1)
            await store.finish() // no receive: the TestStore would fail if didLoad arrived

            #expect(routes.value == [.back])
        }

        /// Regression: the destination's Factory creates a Store (`@MainActor`) inside `navigate`.
        /// If the closure runs off the main thread, the app crashes when navigating.
        @Test
        func navigateShouldRunOnMainThread() async {
            let ranOnMain = LockIsolated<Bool?>(nil)
            let store = makeStore(navigate: { _ in ranOnMain.setValue(Thread.isMainThread) })

            await store.send(.tapContinue)
            await store.finish()

            #expect(ranOnMain.value == true)
        }
    }

    // MARK: - Analytics

    @MainActor
    @Suite("Analytics")
    struct AnalyticsTests {

        /// State passed to the function (the state after the Action). If the scene has
        /// data from outside (`State(itemID:)`), use the same literal across the file.
        let state = {SCENE}Feature.State()

        // Action → event mapping (pure function)

        @Test
        func analyticsEventForDidLoadShouldBeScreenView() {
            let event = {SCENE}Feature.analyticsEvent(for: .didLoad(.fixture()), state: state)
            #expect(event is {SCENE}AnalyticsModel.ScreenViewEvent)
        }

        @Test
        func analyticsEventForTapContinueShouldBeSelectContent() throws {
            let event = try #require({SCENE}Feature.analyticsEvent(for: .tapContinue, state: state) as? {SCENE}AnalyticsModel.SelectContentEvent)
            #expect(event.item == .tapContinue)
        }

        @Test
        func analyticsEventForTapCloseShouldBeSelectContent() throws {
            let event = try #require({SCENE}Feature.analyticsEvent(for: .tapClose, state: state) as? {SCENE}AnalyticsModel.SelectContentEvent)
            #expect(event.item == .tapClose)
        }

        @Test
        func analyticsEventForDidFailShouldBeAlertWithMessage() throws {
            let event = try #require({SCENE}Feature.analyticsEvent(for: .didFail("error"), state: state) as? {SCENE}AnalyticsModel.AlertEvent)
            #expect(event.message == "error")
        }

        @Test
        func analyticsEventForLoadingActionsShouldBeNil() {
            #expect({SCENE}Feature.analyticsEvent(for: .viewDidAppear, state: state) == nil)
            #expect({SCENE}Feature.analyticsEvent(for: .tapRetry, state: state) == nil)
        }

        // Integration: the event reaches the AnalyticsClient

        @Test
        func fullLoadShouldTrackOnlyScreenView() async {
            let events = LockIsolated<[any AnalyticsEvent]>([])
            let store = makeStore { deps in
                deps.{SCENE_CAMEL}Client.fetchData = { .fixture() }
                deps.analytics.track = { event in events.withValue { list in list.append(event) } }
            }

            await store.send(.viewDidAppear) { state in
                state.isLoading = true
            }
            await store.receive(\.didLoad) { state in
                state.isLoading = false
                state.viewData = .fixture()
            }
            await store.finish()

            #expect(events.value.count == 1)
            #expect(events.value.first is {SCENE}AnalyticsModel.ScreenViewEvent)
        }
    }

    // MARK: - Factory

    @MainActor
    @Suite("Factory")
    struct FactoryTests {

        @Test
        func factoryShouldReturnHostingControllerWithInitialState() throws {
            let viewController = {SCENE}Factory.make()

            let hostingController = try #require(
                viewController as? UIHostingController<{SCENE}View>,
                "{SCENE}Factory.make should return UIHostingController<{SCENE}View>"
            )
            #expect(hostingController.rootView.store.state == {SCENE}Feature.State())
        }

        @Test
        func factoryShouldWireNavigateClosure() async throws {
            let routes = LockIsolated<[{SCENE}Route]>([])
            let viewController = {SCENE}Factory.make { route in routes.withValue { list in list.append(route) } }
            let store = try #require((viewController as? UIHostingController<{SCENE}View>)?.rootView.store)

            await store.send(.tapClose).finish()

            #expect(routes.value == [.back])
        }
    }
}

// MARK: - Helpers

/// `makeStore { deps in ... }` (trailing closure = dependencies) or
/// `makeStore(navigate: { route in ... })`. With `State(id:)`, the literal lives only here.
/// Without dependencies, call `makeStore()`: a `{ _ in }` trailing closure is ambiguous
/// and, in Swift 5 mode, goes to `navigate` ("backward matching" warning).
@MainActor
private func makeStore(
    // Optional (not `= State()`): the default value is evaluated outside the MainActor.
    _ initialState: {SCENE}Feature.State? = nil,
    dependencies: (inout DependencyValues) -> Void = { _ in },
    navigate: @escaping @MainActor @Sendable ({SCENE}Route) -> Void = { _ in }
) -> TestStore<{SCENE}Feature.State, {SCENE}Feature.Action> {
    TestStore(
        initialState: initialState ?? {SCENE}Feature.State(),
        reducer: { {SCENE}Feature(navigate: navigate) },
        // A labeled trailing closure only accepts a closure literal; hence the explicit argument.
        withDependencies: dependencies
    )
}
```

### Analytics spec tests (only if P6 passed)

Add them to the Analytics section, comparing the event name and the whole parameter dictionary with the spec:

```swift
@Test
func screenViewEventShouldMatchSpec() {
    let event = {SCENE}AnalyticsModel.ScreenViewEvent()
    #expect(event.name == "<spec>")
    #expect(event.parameters == ["screen_name": "<spec>"])
}
// same for SelectContentEvent (each Item) and AlertEvent
```

Event with a required property (e.g. an id coming from `state`): build it with a literal and check that value in the parameters too:

```swift
let event = {SCENE}AnalyticsModel.ScreenViewEvent(itemID: "item-1")
#expect(event.parameters["item_id"] == "item-1")
```

Never use the template placeholders (`"<spec>"`, the slug derived from the scene name) as the expected value unless the spec confirms them.

---

## `{SCENE}MapperTests.swift`

```swift
import Foundation
import Testing
@testable import {MODULE}

@MainActor
@Suite("{SCENE} Mapper", .timeLimit(.minutes(1)))
struct {SCENE}MapperTests {

    @Test
    func mapShouldConvertResponseIntoViewData() {
        let viewData = {SCENE}Mapper.map(.fixture())

        #expect(viewData == {SCENE}Feature.{SCENE}ViewData())
    }

    /// Fixture contract: the Feature tests use `.fixture()` on both sides.
    @Test
    func mapFixtureResponseShouldProduceFixtureViewData() {
        #expect({SCENE}Mapper.map(.fixture()) == .fixture())
    }
}
```

**Rules**:
- Write the expected `ViewData` **with literal values**; never call the Mapper again to build the expected value.
- `MapperTests` is the **only** place that checks the transformation. The other tests do not call the Mapper.
- In the main test, **a different value per field**.
- Classify each `Response` field:

| Field category | Required tests |
|---|---|
| Direct copy | Covered by the main test |
| Formatting (number, date, currency, percentage) | Main + 1 per edge case **the field's type allows**: `Double` → zero, negative, rounding; integer cents → zero, cents < 10 (`"0.05"`), large value (thousands separator); date → month/year rollover, time zone. A parameterized test with the cases is the preferred format |
| Composed text (prefix, concatenation, `"\(qty)x \(sku)"`) | Covered by the main test, with values that make the format visible |
| `URL` | Valid (main) + `""` → whatever the Mapper returns |
| Optional | Present (main) + `nil` |
| List | Empty + 2 or more items, checking the **order** |
| `enum`/code → text | 1 test per case + unknown value |
| Branch (`if`, `guard`, `??`, `switch`, `filter`) | 1 test per branch |

---

## `{SCENE}ResponseTests.swift`

Guarantees the API contract: the JSON the backend returns decodes into `{SCENE}Response`. It catches `CodingKeys` mistakes, wrong types and required fields the backend may omit — no other test catches these, because the Feature receives the ready-made Response from the client and the Mapper receives the fixture.

```swift
import Foundation
import Testing
@testable import {MODULE}

@MainActor
@Suite("{SCENE} Response", .timeLimit(.minutes(1)))
struct {SCENE}ResponseTests {

    @Test
    func decodeShouldReadEveryFieldFromTheAPIJSON() throws {
        let json = """
        {}
        """

        let response = try decode(json)

        #expect(response == {SCENE}Response())
    }

    private func decode(_ json: String) throws -> {SCENE}Response {
        try JSONDecoder().decode({SCENE}Response.self, from: Data(json.utf8))
    }
}
```

**Rules**:
- The JSON keys come **from the API** (contract, OpenAPI, a real response sample) — **never** copied from the `CodingKeys`, or the test confirms the mistake instead of catching it.
- In the main test, **a different value per field**, and the expected `Response` **with literal values**.
- Use the same `JSONDecoder` (and the same date/key strategies) the Service uses. When decoding happens inside a networking layer, check whether it sets `keyDecodingStrategy`/`dateDecodingStrategy`; if it does not (or you cannot tell), use the default `JSONDecoder()` and record the assumption in the summary.

| `Response` field | Required tests |
|---|---|
| Any field | Covered by the main test |
| Required (non-optional) | JSON without the field → `#expect(throws: DecodingError.self)` — one parameterized test with one case per key (pattern **D**) |
| Optional | 1 test: field missing **and** `null` → `nil` |
| Decoded `enum` | 1 parameterized test: **each valid API value** → the right case (catches a wrong `rawValue`) + 1 test: unknown value → whatever the code does (error, or an `.unknown(value)` fallback case) |
| Nested list | Covered by the main test with 2 items, checking the order |

---

## Execution

### 1. Run

```bash
xcodebuild test \
  -project {Project}.xcodeproj \
  -scheme {Scheme} \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS={version}' \
  -skipMacroValidation \
  -collect-test-diagnostics never \
  -only-testing:{Target}Tests/{SCENE}FeatureTests \
  -only-testing:{Target}Tests/{SCENE}MapperTests \
  -only-testing:{Target}Tests/{SCENE}ResponseTests
```

- `-project` (or `-workspace`): whatever the project uses. Find the `{Scheme}` with `xcodebuild -list`.
- `OS=`: pick, from `xcrun simctl list devices available`, a version **equal to or higher than** the app's deployment target; without `OS=`, xcodebuild may pick an old simulator that cannot install the app.
- `-skipMacroValidation`: required on the command line for the `ComposableKit` macros (in Xcode, approve the macro once).
- `-collect-test-diagnostics never`: without it, **any failing test** makes xcodebuild run `simctl diagnose` for up to ~10 minutes before finishing (and blow the command's time limit).
- Slow CI: the `TestStore` waits 1 s per `receive`/`finish`. Raise it with `TEST_RUNNER_COMPOSABLEKIT_TEST_TIMEOUT=5 xcodebuild test ...` (the `TEST_RUNNER_` prefix forwards `COMPOSABLEKIT_TEST_TIMEOUT` to the test process; with `swift test`, use `COMPOSABLEKIT_TEST_TIMEOUT=5`). Do not use it to hide a test that fails locally.
- Filtering by the outer suite (`{SCENE}FeatureTests`) also runs the nested `@Suite`s (`ReducerTests`, `AnalyticsTests`, `FactoryTests`).
- The xcodebuild console prints **one `passed` line per argument** of a parameterized test, without showing the argument: counting log lines gives more than the number of tests. For the right total and each argument, use `-resultBundlePath <file .xcresult>` and `xcrun xcresulttool get test-results summary` / `tests --path <file .xcresult>`. In the summary, report the **top-level `totalTestCount`/`passedTests`** (tests); the numbers inside `devices` count runs (each argument of a parameterized test counts as one). If running is not possible, go straight to the summary and say so, with the command above filled in.

### 2. Fix until green (at most 3 cycles)

| Failure | Example | What to do |
|---|---|---|
| Test mistake | Does not compile; Action/field with another name | Fix the **test** |
| Undeclared state change | TestStore shows a `− expected / + received` diff | If the received state is right according to the code, fix the closure; if not, it is a scene bug |
| Unchecked Action / effect in flight | "The test finished with N received Action(s)..." | Add the missing `receive` or `await store.finish()` |
| Real bug in the scene | Wrong navigation; analytics spec differs | Do **not** change the test. Report it to the developer |
| Infrastructure | Simulator; missing modules | Report it; do not remove tests |

### 3. Mutation proof

With the suite green, **ask for confirmation**: "May I temporarily change the Feature (and revert it right after) to confirm the tests catch the mistake?"
1. Change something in `body` (e.g. do not reset `isLoading` in `.didLoad`)
2. Run `{SCENE}FeatureTests` — it **must fail**
3. Revert and confirm the file is back to the original; run again — green

Do steps 1–3 in a single command, with a backup copy and guaranteed restore (`trap`), and with `-collect-test-diagnostics never` (with failing tests, without it xcodebuild sits ~10 min in `simctl diagnose` and the command may time out with the Feature still changed):

```bash
FEATURE='<path>/{SCENE}Feature.swift'
BACKUP="$(mktemp)" # or your environment's temporary folder
cp "$FEATURE" "$BACKUP"
trap 'cp "$BACKUP" "$FEATURE"' EXIT
# apply the mutation (sed/edit) and run step 1's xcodebuild with only -only-testing:{Target}Tests/{SCENE}FeatureTests
```

Then confirm with `cmp` that the Feature equals the copy. Without interaction (CI, an agent with prior authorization), the developer's confirmation is the authorization given beforehand.

A rule that follows from a `private static func` shared by `body` and `analyticsEvent` (a condition that decides both navigation and the event): a mutation only in `body` is **not** caught by the analytics tests, and vice versa. So every branch needs a test **on both sides**: in the reducer (navigates/does not navigate) and in `analyticsEvent` (event/`nil`).

---

## Complex scenes (composition)

Each child Feature has its own `{Child}FeatureTests` with a `TestStore`. In the parent Feature, test the integration through the case path:

```swift
await store.send(.showDetail) { state in state.detail = DetailFeature.State() }
await store.send(.detail(.tapSave)) { state in state.detail?.isSaving = true }
await store.send(.rows(.element(id: 1, action: .toggle))) { state in state.rows[id: 1]?.isOn = true }
```

Closing the child (`state.detail = nil`) cancels its effects: test it with `TestClock` + `await store.finish()`.

## Forms (bindings)

```swift
await store.send(.binding(.set(\.email, "a@b.com"))) { state in
    state.email = "a@b.com"
    state.isValid = true
}
// or the shorthand: await store.send(.set(\.email, "a@b.com")) { ... }
```

## Debounce / time

```swift
let clock = TestClock()
let store = TestStore(...) { ... } withDependencies: { deps in deps.continuousClock = clock }
await store.send(.queryChanged("ab")) { state in state.query = "ab" }
await clock.advance(by: 0.3)
await store.receive(\.didSearch) { ... }
```

## Shared state (`@Shared`)

The TestStore assertion closure cannot check `@Shared` fields (the value is a reference). Check them with `#expect(store.state.field == value)` after the `send`.

- With the current `ComposableKitTestSupport.swift` (with `currentTestScope`), **each test has its own `@Shared` values**: do not use `@Suite(.serialized)` or `resetSharedState()` because of `@Shared`. Cases of the same parameterized test share the values. If the target's `ComposableKitTestSupport.swift` is old (no `currentTestScope`), update it (P5).
- `.appStorage` and `.fileStorage` stay in memory only in tests. To verify `.appStorage` persistence, set `deps.defaultAppStorage = UserDefaults(suiteName: "...")` in `withDependencies` (and remove the domain at the end).

---

## Coverage rules — adapting to the real code

| If the scene... | Then... |
|---|---|
| Gained a `tap*` Action | + 1 test with `send` (state) and the effects' `receive`s; + 1 case in `analyticsEvent(for:state:)` |
| Gained a Route | + 1 navigation test (`routes.value == [...]`) |
| Gained a Client endpoint | + success and error tests of the flow that calls it |
| Removed a template Action | Remove the matching tests |
| `Factory.make` takes other parameters | Pass literals in the Factory test |
| `Response`/`ViewData` gained fields | Fixtures with default parameters (keeping the contract) + Mapper tests per category + `ResponseTests` with the API JSON |
| AnalyticsModel with placeholders (P6) | No `*ShouldMatchSpec`; note it in the summary |
| The `State` receives data from outside (`init(id:)`, coming from the Factory) | Use the same literal in every `State(...)`; the Factory test compares the initial state with that literal |
| An endpoint takes a parameter (from the `State` or the `Action`) | + 1 test that captures the argument the client received and compares it with the expected one (pattern **A**) |
| An Action cancels an effect (`.cancel(id:)`, `.merge(.cancel..., ...)`) | + 1 test: effect stuck on a `TestClock`, send the Action, advance the clock, `finish()` without `receive` (pattern **B**) |
| An analytics event has a dynamic property (ids, messages) | The mapping test checks the property's **value**; the integration test does too (pattern **C**) |
| The `Response` has required fields | 1 parameterized test: one key removed per case → `DecodingError` (pattern **D**) |
| `body` or `analyticsEvent` has a branch (`guard`, `if`, `switch` on `state` data) | 1 test per branch — including the one that does nothing (e.g. `tapTrack` without a code does not navigate and sends no event: `routes.value == []`). With optional chaining, **every path that yields `nil` is a branch**: `guard let code = state.viewData?.trackingCode` = no `viewData` **and** `viewData` without a code |
| `body` uses `.onChange(of:)` | 2 tests: the value changes → the reaction's state/effect (with the `send`/`binding` that changes the field); the same value again → nothing (`send` without a closure) |
| A child Feature uses `.dependency(\.x, value)` | Test the **parent**: the child's Action uses the overridden value (in the reducer and in the effect's `receive`) and a child/sibling without the override uses the `withDependencies` one |
| `body` has `._printChanges()` | Not for testing: tell the developer to remove it before shipping (debugging tool) |
| The `Response` has a (closed) `enum` | The "unknown value" is tested in `ResponseTests` (decoding fails or falls back); in `MapperTests`, 1 test per case |

### Coverage rule patterns

Use these formats so the result does not vary between runs of the skill.

**A. Argument sent to the endpoint** (the value comes from the `State`):

```swift
@Test
func viewDidAppearShouldRequestTheIdFromState() async {
    let requestedIDs = LockIsolated<[String]>([])
    let store = makeStore { deps in
        deps.{SCENE_CAMEL}Client.fetchItem = { id in
            requestedIDs.withValue { list in list.append(id) }
            return .fixture()
        }
    }

    await store.send(.viewDidAppear) { state in
        state.isLoading = true
    }
    await store.receive(\.didLoad) { state in
        state.isLoading = false
        state.viewData = .fixture()
    }
    #expect(requestedIDs.value == ["id-from-state"])
}
```

**B. Action that cancels an effect** (no response may arrive afterwards):

```swift
@Test
func tapBackWhileLoadingShouldCancelRequest() async {
    let clock = TestClock()
    let store = makeStore { deps in
        deps.{SCENE_CAMEL}Client.fetchData = {
            try await clock.sleep(for: 1)
            return .fixture()
        }
    }

    await store.send(.viewDidAppear) { state in
        state.isLoading = true
    }
    await store.send(.tapBack)
    await clock.advance(by: 1)
    await store.finish() // no receive: the TestStore would fail if didLoad arrived
}
```

**C. Dynamic analytics property** (the value comes from `state` or from the Action's payload):

```swift
@Test
func analyticsEventForDidLoadShouldCarryTheItemID() throws {
    let event = try #require(
        {SCENE}Feature.analyticsEvent(for: .didLoad(.fixture()), state: {SCENE}Feature.State(itemID: itemID)) as? {SCENE}AnalyticsModel.ScreenViewEvent
    )
    #expect(event.itemID == itemID)
}
```

And **one integration test per event with a dynamic property**, which drives the flow through the `TestStore` and checks the value that reached `AnalyticsClient`. A **conditional event without a dynamic property** (e.g. only sent when there is a code) does not need an integration test: the pure function's branch tests already cover it.

```swift
#expect((events.value.first as? {SCENE}AnalyticsModel.ScreenViewEvent)?.itemID == itemID)
```

**D. Required key missing from the JSON** (in `ResponseTests`, one case per key):

```swift
@Test(arguments: ["keyA", "keyB"]) // the required keys, with the API's names
func decodeWithoutRequiredKeyShouldFail(_ key: String) throws {
    let json = try removing(key, from: apiJSON)

    #expect(throws: DecodingError.self) {
        try decode(json)
    }
}

private func removing(_ key: String, from json: String) throws -> String {
    var object = try #require(try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
    object[key] = nil
    return String(decoding: try JSONSerialization.data(withJSONObject: object), as: UTF8.self)
}
```

Keep the API JSON in an `apiJSON` property of the suite, shared by the main test and the parameterized one. `@Test(arguments:)` arguments must be `Sendable`. Declare the helper types (`RequiredKey` below) and helpers (`removing`, `replacing`, `decode`) **inside the `@Suite`**: at file scope they collide with the other scenes' helpers in the same target ("invalid redeclaration").

Keys **inside a list** (e.g. `"items": [{ "sku": ... }]`): one case per key, removed from the first item:

```swift
enum RequiredKey: CustomStringConvertible, Sendable {
    case root(String)
    case item(String) // removed from the first element of "items"

    var description: String {
        switch self {
        case let .root(key): key
        case let .item(key): "items[0].\(key)"
        }
    }
}

@Test(arguments: [RequiredKey.root("order_id"), .root("items"), .item("sku")])
func decodeWithoutRequiredKeyShouldFail(_ key: RequiredKey) throws { ... }

private func removing(_ key: RequiredKey, from json: String) throws -> String {
    var object = try #require(try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
    switch key {
    case let .root(name):
        object[name] = nil
    case let .item(name):
        var items = try #require(object["items"] as? [[String: Any]])
        items[0][name] = nil
        object["items"] = items
    }
    return String(decoding: try JSONSerialization.data(withJSONObject: object), as: UTF8.self)
}
```

Decoded `enum` — each valid value (with the **API's** name) to the right case:

```swift
@Test(arguments: [("open", {SCENE}Response.Status.open), ("closed", .closed), ("overdue", .overdue)])
func decodeShouldMapEveryStatusValue(_ value: String, _ expected: {SCENE}Response.Status) throws {
    let json = try replacing("status", with: value, in: apiJSON)

    #expect(try decode(json).status == expected)
}
```

Optional **missing and `null`** (two cases in the same parameterized test or two tests):

```swift
private func replacing(_ key: String, with value: Any, in json: String) throws -> String {
    var object = try #require(try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
    object[key] = value // NSNull() for null
    return String(decoding: try JSONSerialization.data(withJSONObject: object), as: UTF8.self)
}

#expect(try decode(removing(.root("tracking_code"), from: apiJSON)).trackingCode == nil)
#expect(try decode(replacing("tracking_code", with: NSNull(), in: apiJSON)).trackingCode == nil)
```

---

## Who implements `navigate` (Coordinator / router)

The scene tests check **which** Route was requested. What each Route **does** (push, pop, present) lives in whoever creates the scene — the module's Coordinator or the app router — and is tested there, once per flow, with a real `UINavigationController`:

```swift
@MainActor
@Suite("AppRouter", .timeLimit(.minutes(1)))
struct AppRouterTests {

    @Test
    func detailsRouteShouldPushDetailsWithTheTappedItem() async throws {
        let navigationController = UINavigationController()
        navigationController.viewControllers = [AppRouter.makeList(in: navigationController)]
        let list = try #require(navigationController.topViewController as? UIHostingController<ListView>)

        await list.rootView.store.send(.tapItem(id: "id-1")).finish()

        let details = try #require(navigationController.topViewController as? UIHostingController<DetailsView>)
        #expect(details.rootView.store.state == DetailsFeature.State(id: "id-1"))
    }

    @Test
    func backRouteShouldPop() async throws {
        let navigationController = UINavigationController()
        let list = AppRouter.makeList(in: navigationController)
        let details = AppRouter.makeDetails(id: "id-1", in: navigationController)
        navigationController.viewControllers = [list, details]
        let scene = try #require(details as? UIHostingController<DetailsView>)

        await scene.rootView.store.send(.tapBack).finish()

        #expect(navigationController.viewControllers == [list])
    }
}
```

Generate these tests when the scene is new in a flow or gains a new Route; if the module's Coordinator already has tests, add only the scene's cases.

## Mandatory rules

1. **Always** `@MainActor` on the suite (the `TestStore` is `@MainActor`).
2. **Always** `TestStore` to test the Feature; a real `Store` only in the Factory test.
3. **Always** override in `withDependencies:` every endpoint the flow calls. The Client's `testValue` fails the test if it is used.
4. **Always** declare every state change in the `send`/`receive` closure. Omit the closure only when the state does not change.
5. **Always** `receive` each Action an effect sends, in order. Prefer `receive(\.case, value)` when the value matters.
6. **Always** `await store.finish()` before checking navigation or analytics sent by effects.
7. **Always** `TestClock` for time (cancellation, debounce, timers). **Never** `Task.sleep` in the test.
8. **Always** compare whole arrays: `#expect(routes.value == [.nextPage])`. **Never** `contains`.
9. **Never** `exhaustivity = .off` without a reason written in the test.
10. **Never** spy classes for dependencies: use closures + `LockIsolated`.
11. **Never** test the View with `@Test`.
12. `@Test` names in descriptive camelCase, without a `test` prefix.
13. Plain imports (`import X`), no `internal import`/`public import`.
14. **Never** call the Mapper outside `MapperTests`: the Feature's expected state is `.fixture()` (fixture contract).
15. **Always** one nested `@Suite` per responsibility in `FeatureTests` (`ReducerTests`, `AnalyticsTests`, `FactoryTests`), each one `@MainActor`. Do not use the names `Reducer`/`Store` (they collide with the package's types).
16. **Always** `.timeLimit(.minutes(1))` on each file's top-level `@Suite` (it applies to the nested ones): a hung test fails in 1 minute instead of holding CI (exception: P9).

## Final checklist

- [ ] Every Action appears in at least one `send` or `receive`.
- [ ] Every Client endpoint has a success **and** an error test.
- [ ] There is a repeated `tapRetry` test (cancellation) when the fetch is `.cancellable(cancelInFlight: true)`.
- [ ] Every Route has a navigation test.
- [ ] Every case of `analyticsEvent(for:state:)` has a test, including the ones that return `nil` and each branch that depends on `state`.
- [ ] Analytics spec checked event by event (or pending item recorded — P6).
- [ ] Factory: type, initial state and `navigate` checked.
- [ ] MapperTests with literal values and classified fields, plus the fixture contract test.
- [ ] ResponseTests with the API's literal JSON: main + missing required keys + missing/`null` optionals + each valid value and one unknown value of each `enum`.
- [ ] No test outside `MapperTests` calls the Mapper.
- [ ] There is a `tapRetry` test with already loaded content (the old `viewData` stays during the reload) **and** one where that reload fails (the content stays and `errorMessage` shows up).
- [ ] There is a `viewDidAppear` test with already loaded content (it does not reload when coming back from a pushed screen).
- [ ] Every endpoint with a parameter has a test of the argument sent (pattern A).
- [ ] Every Action that cancels an effect has a cancellation test (pattern B).
- [ ] Every dynamic analytics property has its value checked, in the function and in an integration test (pattern C).
- [ ] Every branch of `body` and `analyticsEvent` has a test, including the one that does nothing.
- [ ] If the scene gained a Route that changes navigation, whoever implements `navigate` gained/updated its tests. A scene not yet in any flow (nobody calls the Factory): record it in the summary as pending for when it joins the Coordinator/router.
- [ ] There is a `tapClose` test (or another Action that leaves the screen) with a fetch in flight: the response does not arrive afterwards (pattern B).
- [ ] `ComposableKitTestSupport.swift` exists in the target (P5).
- [ ] The suite **ran** and is green, or the summary says it did not run, why, and the command.
- [ ] Mutation proof done (or refusal recorded).
