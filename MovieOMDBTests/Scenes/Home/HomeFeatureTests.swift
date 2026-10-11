import Foundation
import ComposableKit
import SwiftUI // UIHostingController.rootView (MemberImportVisibility)
import Testing
@testable import MovieOMDB

// ╔══════════════════════════════════════════════════════════════╗
// ║  Home Feature Tests                                          ║
// ║  Reducer (state, effects, navigation) · Analytics · Factory  ║
// ║  The Mapper is not called here: the expected value is        ║
// ║  `.fixture()` (fixture contract, enforced in MapperTests).   ║
// ╚══════════════════════════════════════════════════════════════╝

@MainActor
@Suite("Home Feature", .timeLimit(.minutes(1)))
struct HomeFeatureTests {

    // MARK: - Reducer

    @MainActor
    @Suite("Reducer")
    struct ReducerTests {

        @Test
        func viewDidAppearWhenServiceSucceedsShouldShowViewData() async {
            let store = makeStore { deps in
                deps.homeClient.fetchData = { .fixture() }
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
                deps.homeClient.fetchData = { throw NSError.fixture(message: "connection error") }
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
            var initialState = HomeFeature.State()
            initialState.errorMessage = "previous error"
            let store = makeStore(initialState) { deps in
                deps.homeClient.fetchData = { .fixture() }
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
            var initialState = HomeFeature.State()
            initialState.viewData = .fixture()
            // No client: the testValue fails the test if the request is made.
            let store = makeStore(initialState) { _ in }

            await store.send(.viewDidAppear)
            await store.finish()
        }

        /// Already loaded content stays on screen while reloading.
        @Test
        func tapRetryWithLoadedContentShouldKeepViewDataWhileReloading() async {
            var initialState = HomeFeature.State()
            initialState.viewData = .fixture(movies: [.fixture(id: "tt-antigo")])
            let store = makeStore(initialState) { deps in
                deps.homeClient.fetchData = { .fixture() }
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
                deps.homeClient.fetchData = {
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
        func tapMovieShouldNavigateToMovieDetails() async {
            let routes = LockIsolated<[HomeRoute]>([])
            let store = TestStore(initialState: HomeFeature.State()) {
                HomeFeature(navigate: { route in routes.withValue { list in list.append(route) } })
            }

            await store.send(.tapMovie(id: "tt0111161"))
            await store.finish()

            #expect(routes.value == [.movieDetails(imdbID: "tt0111161")])
        }

        /// Regression: the destination's Factory creates a Store (`@MainActor`) inside `navigate`.
        /// If the closure runs off the main thread, the app crashes when navigating.
        @Test
        func navigateShouldRunOnMainThread() async {
            let ranOnMain = LockIsolated<Bool?>(nil)
            let store = TestStore(initialState: HomeFeature.State()) {
                HomeFeature(navigate: { _ in ranOnMain.setValue(Thread.isMainThread) })
            }

            await store.send(.tapMovie(id: "tt0111161"))
            await store.finish()

            #expect(ranOnMain.value == true)
        }
    }

    // MARK: - Analytics

    @MainActor
    @Suite("Analytics")
    struct AnalyticsTests {

        /// State passed to the function (the state after the Action).
        let state = HomeFeature.State()

        // Action → event mapping (pure function)

        @Test
        func analyticsEventForDidLoadShouldBeScreenView() {
            let event = HomeFeature.analyticsEvent(for: .didLoad(.fixture()), state: state)
            #expect(event is HomeAnalyticsModel.ScreenViewEvent)
        }

        @Test
        func analyticsEventForTapMovieShouldBeSelectContentWithImdbID() throws {
            let event = try #require(
                HomeFeature.analyticsEvent(for: .tapMovie(id: "tt0111161"), state: state) as? HomeAnalyticsModel.SelectContentEvent
            )
            #expect(event.item == .tapMovie)
            #expect(event.movieID == "tt0111161")
        }

        @Test
        func analyticsEventForDidFailShouldBeAlertWithMessage() throws {
            let event = try #require(HomeFeature.analyticsEvent(for: .didFail("error"), state: state) as? HomeAnalyticsModel.AlertEvent)
            #expect(event.message == "error")
        }

        @Test
        func analyticsEventForLoadingActionsShouldBeNil() {
            #expect(HomeFeature.analyticsEvent(for: .viewDidAppear, state: state) == nil)
            #expect(HomeFeature.analyticsEvent(for: .tapRetry, state: state) == nil)
        }

        // Integration: the event reaches the AnalyticsClient

        @Test
        func fullLoadShouldTrackOnlyScreenView() async {
            let events = LockIsolated<[any AnalyticsEvent]>([])
            let store = makeStore { deps in
                deps.homeClient.fetchData = { .fixture() }
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
            #expect(events.value.first is HomeAnalyticsModel.ScreenViewEvent)
        }
    }

    // MARK: - Factory

    @MainActor
    @Suite("Factory")
    struct FactoryTests {

        @Test
        func factoryShouldReturnHostingControllerWithInitialState() throws {
            let viewController = HomeFactory.make()

            let hostingController = try #require(
                viewController as? UIHostingController<HomeView>,
                "HomeFactory.make should return UIHostingController<HomeView>"
            )
            #expect(hostingController.rootView.store.state == HomeFeature.State())
        }

        @Test
        func factoryShouldWireNavigateClosure() async throws {
            let routes = LockIsolated<[HomeRoute]>([])
            let viewController = HomeFactory.make { route in routes.withValue { list in list.append(route) } }
            let store = try #require((viewController as? UIHostingController<HomeView>)?.rootView.store)

            await store.send(.tapMovie(id: "tt0111161")).finish()

            #expect(routes.value == [.movieDetails(imdbID: "tt0111161")])
        }
    }
}

// MARK: - Helpers

@MainActor
private func makeStore(
    // Optional (not `= State()`): the default value is evaluated outside the MainActor.
    _ initialState: HomeFeature.State? = nil,
    dependencies: (inout DependencyValues) -> Void
) -> TestStore<HomeFeature.State, HomeFeature.Action> {
    TestStore(
        initialState: initialState ?? HomeFeature.State(),
        reducer: { HomeFeature() },
        // A labeled trailing closure only accepts a closure literal; hence the explicit argument.
        withDependencies: dependencies
    )
}
