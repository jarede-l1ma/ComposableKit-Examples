import ComposableKit

// MARK: - Analytics
//
// Analytics dependency used by the Features (`@Dependency(\.analytics)`).
// It must exist ONCE per module (or in a shared module). In production it forwards
// to your analytics SDK; in tests it does nothing, unless the test overrides
// `deps.analytics.track` to capture events.

/// An analytics event. Each scene declares its events in `<Scene>AnalyticsModel`.
// `nonisolated`: in apps with default MainActor isolation, events are created and
// read outside the MainActor (without default isolation, nothing changes).
nonisolated protocol AnalyticsEvent {
    var name: String { get }
    var parameters: [String: String] { get }
}

struct AnalyticsClient: Sendable {
    var track: @Sendable (any AnalyticsEvent) -> Void
}

extension AnalyticsClient: DependencyKey {
    static let liveValue = AnalyticsClient { event in
        // TODO: forward to your analytics SDK (Firebase, Amplitude, ...).
        print("[Analytics] \(event.name) \(event.parameters)")
    }

    static let testValue = AnalyticsClient { _ in }
}

extension DependencyValues {
    var analytics: AnalyticsClient {
        get { self[AnalyticsClient.self] }
        set { self[AnalyticsClient.self] = newValue }
    }
}
