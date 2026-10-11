import ComposableKit
import Foundation

@Reducer
struct HomeFeature {

    // MARK: - State

    @ObservableState
    struct State: Equatable {
        var isLoading = false
        var viewData: HomeViewData?
        var errorMessage: String?
    }

    // MARK: - ViewData

    struct HomeViewData: Equatable {
        var movies: [Movie]

        struct Movie: Equatable, Identifiable {
            let id: String // imdbID
            let title: String
            let year: String
            let posterURL: URL?
        }
    }

    // MARK: - Action
    //
    // `tap*` cases are sent by the View.
    // `did*` cases are sent by effects (network responses, etc.).

    enum Action: Equatable {
        // Lifecycle
        case viewDidAppear

        // User
        case tapMovie(id: String)
        case tapRetry

        // Internal (Effect responses)
        case didLoad(HomeViewData)
        case didFail(String)
    }

    // `nonisolated`: the app uses default MainActor isolation; the id must be Hashable & Sendable outside the MainActor.
    nonisolated enum CancelID {
        case fetch
    }

    // MARK: - Dependencies

    @Dependency(\.homeClient) var homeClient
    @Dependency(\.analytics) var analytics

    /// Navigation: injected by the Factory (whoever creates the scene decides the destination).
    // `nonisolated`: without it, in an app with default MainActor isolation, the compiler drops the
    // closure's `@MainActor` when capturing it in `.run` and it runs off the main thread (crash).
    nonisolated var navigate: @MainActor @Sendable (HomeRoute) -> Void = { _ in }

    // MARK: - Body

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .viewDidAppear, .tapRetry:
                // The View sends `viewDidAppear` on every appearance (including when coming
                // back from a pushed screen): with content on screen, it does not reload.
                if action == .viewDidAppear, state.viewData != nil { return .none }
                state.isLoading = true
                state.errorMessage = nil
                return .run { [homeClient] send in
                    let response = try await homeClient.fetchData()
                    await send(.didLoad(HomeMapper.map(response)))
                } catch: { error, send in
                    await send(.didFail(error.localizedDescription))
                }
                .cancellable(id: CancelID.fetch, cancelInFlight: true)

            case let .didLoad(viewData):
                state.isLoading = false
                state.viewData = viewData
                return .none

            case let .didFail(message):
                state.isLoading = false
                state.errorMessage = message
                return .none

            case let .tapMovie(id):
                return .run { [navigate] _ in await navigate(.movieDetails(imdbID: id)) }
            }
        }

        // Centralized analytics: one event per Action. It receives the already
        // updated state, for events with State data (ids, codes).
        Reduce { state, action in
            if let event = Self.analyticsEvent(for: action, state: state) {
                analytics.track(event)
            }
            return .none
        }
    }

    // MARK: - Analytics

    /// `state` is the state **after** the Action: use it when the event needs
    /// screen data (e.g. `itemID: state.itemID`).
    static func analyticsEvent(for action: Action, state: State) -> (any AnalyticsEvent)? {
        switch action {
        case .didLoad:
            HomeAnalyticsModel.ScreenViewEvent()
        case let .tapMovie(id):
            HomeAnalyticsModel.SelectContentEvent(item: .tapMovie, movieID: id)
        case let .didFail(message):
            HomeAnalyticsModel.AlertEvent(message: message)
        case .viewDidAppear, .tapRetry:
            nil
        }
    }
}

// MARK: - Route

enum HomeRoute: Equatable, Sendable {
    case movieDetails(imdbID: String)
}
