import ComposableKit
import Foundation

@Reducer
struct SampleFeature {

    // MARK: - State

    @ObservableState
    struct State: Equatable {
        var isLoading = false
        var viewData: SampleViewData?
        var errorMessage: String?
    }

    // MARK: - ViewData

    // `nonisolated`: the ViewData (and its fixtures in tests, including in
    // `@Test(arguments:)`) is used outside the MainActor in apps with default
    // MainActor isolation; without default isolation, nothing changes.
    nonisolated struct SampleViewData: Equatable {
        // TODO: fill in with the display data — produced by the Mapper from the Response.
    }

    // MARK: - Action
    //
    // `tap*` cases are sent by the View.
    // `did*` cases are sent by effects (network responses, etc.).

    enum Action: Equatable {
        // Lifecycle
        case viewDidAppear

        // User
        case tapContinue
        case tapRetry
        case tapClose

        // Internal (Effect responses)
        case didLoad(SampleViewData)
        case didFail(String)
    }


    // `nonisolated`: in apps with default MainActor isolation, the id must be
    // Hashable & Sendable outside the MainActor (without default isolation, nothing changes).
    nonisolated enum CancelID {
        case fetch
    }

    // MARK: - Dependencies

    @Dependency(\.sampleClient) var sampleClient
    @Dependency(\.analytics) var analytics

    /// Navigation: injected by the Factory (whoever creates the scene decides the destination).
    // `nonisolated`: without it, in an app with default MainActor isolation, the compiler drops the
    // closure's `@MainActor` when capturing it in `.run` and it runs off the main thread (crash).
    nonisolated var navigate: @MainActor @Sendable (SampleRoute) -> Void = { _ in }

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
                return .run { [sampleClient] send in
                    let response = try await sampleClient.fetchData()
                    await send(.didLoad(SampleMapper.map(response)))
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

            case .tapContinue:
                return .run { [navigate] _ in await navigate(.nextPage) }

            case .tapClose:
                // Leaving the screen cancels the in-flight fetch (and its URLSession request).
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
            SampleAnalyticsModel.ScreenViewEvent()
        case .tapContinue:
            SampleAnalyticsModel.SelectContentEvent(item: .tapContinue)
        case .tapClose:
            SampleAnalyticsModel.SelectContentEvent(item: .tapClose)
        case let .didFail(message):
            SampleAnalyticsModel.AlertEvent(message: message)
        case .viewDidAppear, .tapRetry:
            nil
        }
    }
}

// MARK: - Route

enum SampleRoute: Equatable, Sendable {
    case back
    case nextPage
    // TODO: add cases with data if the next scene needs to receive information
}
