import ComposableKit
import Foundation

@Reducer
struct HomeDetailsFeature {

    // MARK: - State

    @ObservableState
    struct State: Equatable {
        /// Movie to display: received from Home through the Factory.
        let imdbID: String
        var isLoading = false
        var viewData: HomeDetailsViewData?
        var errorMessage: String?

        init(imdbID: String) {
            self.imdbID = imdbID
        }
    }

    // MARK: - ViewData

    struct HomeDetailsViewData: Equatable {
        let title: String
        let posterURL: URL?
        /// "1994 · 142 min · R"
        let info: String
        let genres: [String]
        let rating: String?
        let plot: String
        let director: String?
        let actors: [String]
    }

    // MARK: - Action
    //
    // `tap*` cases are sent by the View.
    // `did*` cases are sent by effects (network responses, etc.).

    enum Action: Equatable {
        // Lifecycle
        case viewDidAppear

        // User
        case tapRetry
        case tapBack

        // Internal (Effect responses)
        case didLoad(HomeDetailsViewData)
        case didFail(String)
    }

    // `nonisolated`: the app uses default MainActor isolation; the id must be Hashable & Sendable outside the MainActor.
    nonisolated enum CancelID {
        case fetch
    }

    // MARK: - Dependencies

    @Dependency(\.homeDetailsClient) var homeDetailsClient
    @Dependency(\.analytics) var analytics

    /// Navigation: injected by the Factory (whoever creates the scene decides the destination).
    // `nonisolated`: without it, in an app with default MainActor isolation, the compiler drops the
    // closure's `@MainActor` when capturing it in `.run` and it runs off the main thread (crash).
    nonisolated var navigate: @MainActor @Sendable (HomeDetailsRoute) -> Void = { _ in }

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
                return .run { [homeDetailsClient, imdbID = state.imdbID] send in
                    let response = try await homeDetailsClient.fetchMovie(imdbID)
                    await send(.didLoad(HomeDetailsMapper.map(response)))
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

            case .tapBack:
                return .merge(
                    .cancel(id: CancelID.fetch),
                    .run { [navigate] _ in await navigate(.back) }
                )
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
            HomeDetailsAnalyticsModel.ScreenViewEvent(movieID: state.imdbID)
        case .tapBack:
            HomeDetailsAnalyticsModel.SelectContentEvent(item: .tapBack)
        case let .didFail(message):
            HomeDetailsAnalyticsModel.AlertEvent(message: message)
        case .viewDidAppear, .tapRetry:
            nil
        }
    }
}

// MARK: - Route

enum HomeDetailsRoute: Equatable, Sendable {
    case back
}
