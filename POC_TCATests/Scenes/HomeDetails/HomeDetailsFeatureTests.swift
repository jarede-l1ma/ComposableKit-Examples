import Foundation
import ComposableKit
import SwiftUI // UIHostingController.rootView (MemberImportVisibility)
import Testing
@testable import POC_TCA

// ╔══════════════════════════════════════════════════════════════╗
// ║  HomeDetails Feature Tests                                   ║
// ║  Reducer (state, effects, navigation) · Analytics · Factory  ║
// ║  The Mapper is not called here: the expected value is        ║
// ║  `.fixture()` (fixture contract, enforced in MapperTests).   ║
// ╚══════════════════════════════════════════════════════════════╝

private let imdbID = "tt0111161"

@MainActor
@Suite("HomeDetails Feature", .timeLimit(.minutes(1)))
struct HomeDetailsFeatureTests {

    // MARK: - Reducer

    @MainActor
    @Suite("Reducer")
    struct ReducerTests {

        @Test
        func viewDidAppearWhenServiceSucceedsShouldShowViewData() async {
            let store = makeStore { deps in
                deps.homeDetailsClient.fetchMovie = { _ in .fixture() }
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
        func viewDidAppearShouldRequestTheImdbIDFromState() async {
            let requestedIDs = LockIsolated<[String]>([])
            let store = makeStore { deps in
                deps.homeDetailsClient.fetchMovie = { id in
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
            #expect(requestedIDs.value == [imdbID])
        }

        @Test
        func viewDidAppearWhenServiceFailsShouldShowError() async {
            let store = makeStore { deps in
                deps.homeDetailsClient.fetchMovie = { _ in throw NSError.fixture(message: "connection error") }
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
            var initialState = HomeDetailsFeature.State(imdbID: imdbID)
            initialState.errorMessage = "previous error"
            let store = makeStore(initialState) { deps in
                deps.homeDetailsClient.fetchMovie = { _ in .fixture() }
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
            var initialState = HomeDetailsFeature.State(imdbID: imdbID)
            initialState.viewData = .fixture()
            // No client: the testValue fails the test if the request is made.
            let store = makeStore(initialState) { _ in }

            await store.send(.viewDidAppear)
            await store.finish()
        }

        /// Already loaded content stays on screen while reloading.
        @Test
        func tapRetryWithLoadedContentShouldKeepViewDataWhileReloading() async {
            var initialState = HomeDetailsFeature.State(imdbID: imdbID)
            initialState.viewData = .fixture(title: "old title")
            let store = makeStore(initialState) { deps in
                deps.homeDetailsClient.fetchMovie = { _ in .fixture() }
            }

            await store.send(.tapRetry) { state in
                state.isLoading = true // viewData antigo continua
            }
            await store.receive(\.didLoad) { state in
                state.isLoading = false
                state.viewData = .fixture()
            }
        }

        @Test
        func tapRetryTwiceShouldCancelFirstRequest() async {
            let clock = TestClock()
            let calls = LockIsolated(0)
            let store = makeStore { deps in
                deps.homeDetailsClient.fetchMovie = { _ in
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
        func tapBackShouldNavigateBack() async {
            let routes = LockIsolated<[HomeDetailsRoute]>([])
            let store = TestStore(initialState: HomeDetailsFeature.State(imdbID: imdbID)) {
                HomeDetailsFeature(navigate: { route in routes.withValue { list in list.append(route) } })
            }

            await store.send(.tapBack)
            await store.finish()

            #expect(routes.value == [.back])
        }

        /// `tapBack` also cancels the fetch: no `didLoad` arrives after going back.
        @Test
        func tapBackWhileLoadingShouldCancelRequest() async {
            let clock = TestClock()
            let store = makeStore { deps in
                deps.homeDetailsClient.fetchMovie = { _ in
                    try await clock.sleep(for: 1)
                    return .fixture()
                }
            }

            await store.send(.viewDidAppear) { state in
                state.isLoading = true
            }
            await store.send(.tapBack)
            await clock.advance(by: 1)
            await store.finish()
        }

        /// Regression: the destination's Factory creates a Store (`@MainActor`) inside `navigate`.
        /// If the closure runs off the main thread, the app crashes when navigating.
        @Test
        func navigateShouldRunOnMainThread() async {
            let ranOnMain = LockIsolated<Bool?>(nil)
            let store = TestStore(initialState: HomeDetailsFeature.State(imdbID: imdbID)) {
                HomeDetailsFeature(navigate: { _ in ranOnMain.setValue(Thread.isMainThread) })
            }

            await store.send(.tapBack)
            await store.finish()

            #expect(ranOnMain.value == true)
        }
    }

    // MARK: - Analytics

    @MainActor
    @Suite("Analytics")
    struct AnalyticsTests {

        /// State passed to the function (the state after the Action).
        let state = HomeDetailsFeature.State(imdbID: imdbID)

        // Action → event mapping (pure function)

        @Test
        func analyticsEventForDidLoadShouldBeScreenViewWithImdbID() throws {
            let event = try #require(
                HomeDetailsFeature.analyticsEvent(for: .didLoad(.fixture()), state: state) as? HomeDetailsAnalyticsModel.ScreenViewEvent
            )
            #expect(event.movieID == imdbID)
        }

        @Test
        func analyticsEventForTapBackShouldBeSelectContent() throws {
            let event = try #require(
                HomeDetailsFeature.analyticsEvent(for: .tapBack, state: state) as? HomeDetailsAnalyticsModel.SelectContentEvent
            )
            #expect(event.item == .tapBack)
        }

        @Test
        func analyticsEventForDidFailShouldBeAlertWithMessage() throws {
            let event = try #require(
                HomeDetailsFeature.analyticsEvent(for: .didFail("error"), state: state) as? HomeDetailsAnalyticsModel.AlertEvent
            )
            #expect(event.message == "error")
        }

        @Test
        func analyticsEventForLoadingActionsShouldBeNil() {
            #expect(HomeDetailsFeature.analyticsEvent(for: .viewDidAppear, state: state) == nil)
            #expect(HomeDetailsFeature.analyticsEvent(for: .tapRetry, state: state) == nil)
        }

        // Integration: the event reaches the AnalyticsClient

        @Test
        func fullLoadShouldTrackOnlyScreenView() async {
            let events = LockIsolated<[any AnalyticsEvent]>([])
            let store = makeStore { deps in
                deps.homeDetailsClient.fetchMovie = { _ in .fixture() }
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
            #expect((events.value.first as? HomeDetailsAnalyticsModel.ScreenViewEvent)?.movieID == imdbID)
        }
    }

    // MARK: - Factory

    @MainActor
    @Suite("Factory")
    struct FactoryTests {

        @Test
        func factoryShouldReturnHostingControllerWithInitialState() throws {
            let viewController = HomeDetailsFactory.make(imdbID: imdbID)

            let hostingController = try #require(
                viewController as? UIHostingController<HomeDetailsView>,
                "HomeDetailsFactory.make should return UIHostingController<HomeDetailsView>"
            )
            #expect(hostingController.rootView.store.state == HomeDetailsFeature.State(imdbID: imdbID))
        }

        @Test
        func factoryShouldWireNavigateClosure() async throws {
            let routes = LockIsolated<[HomeDetailsRoute]>([])
            let viewController = HomeDetailsFactory.make(imdbID: imdbID) { route in routes.withValue { list in list.append(route) } }
            let store = try #require((viewController as? UIHostingController<HomeDetailsView>)?.rootView.store)

            await store.send(.tapBack).finish()

            #expect(routes.value == [.back])
        }
    }
}

// MARK: - Helpers

@MainActor
private func makeStore(
    // Optional (not `= State()`): the default value is evaluated outside the MainActor.
    _ initialState: HomeDetailsFeature.State? = nil,
    dependencies: (inout DependencyValues) -> Void
) -> TestStore<HomeDetailsFeature.State, HomeDetailsFeature.Action> {
    TestStore(
        initialState: initialState ?? HomeDetailsFeature.State(imdbID: imdbID),
        reducer: { HomeDetailsFeature() },
        // A labeled trailing closure only accepts a closure literal; hence the explicit argument.
        withDependencies: dependencies
    )
}
