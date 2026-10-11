import ComposableKit
import Foundation

// MARK: - Response
//
// `nonisolated`: the `Decodable` and the test fixtures are used outside the
// MainActor (in apps with default MainActor isolation; without it, nothing changes).

nonisolated struct SampleResponse: Decodable, Equatable, Sendable {
    // TODO: replace with the real fields of the API response
}

// MARK: - Client (the Feature's dependency)
//
// The Feature uses the client through `@Dependency(\.sampleClient)`. In tests, each
// endpoint is overridden: `deps.sampleClient.fetchData = { .fixture() }`.

struct SampleClient: Sendable {
    var fetchData: @Sendable () async throws -> SampleResponse
}

extension SampleClient: DependencyKey {
    static let liveValue = SampleClient(
        fetchData: { try await SampleService().fetchData() }
    )

    static let testValue = SampleClient(
        fetchData: { throw UnimplementedError("SampleClient.fetchData") }
    )
}

extension DependencyValues {
    var sampleClient: SampleClient {
        get { self[SampleClient.self] }
        set { self[SampleClient.self] = newValue }
    }
}

// MARK: - Implementation
//
// `URLSession` with async/await: cancelling the effect (`.cancel(id:)`,
// `cancelInFlight`) cancels the request too. Swap it for your app's networking
// layer if it has one; keep the `async throws` signature.

nonisolated struct SampleService: Sendable {
    var baseURL = URL(string: "https://api.example.com")! // TODO: your API's base URL
    var session: URLSession = .shared

    func fetchData() async throws -> SampleResponse {
        let url = baseURL.appendingPathComponent("sample") // TODO: the real endpoint
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(SampleResponse.self, from: data)
    }
}
