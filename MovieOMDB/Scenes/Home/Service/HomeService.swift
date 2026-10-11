import ComposableKit
import Foundation

// MARK: - Response
//
// OMDb search format (`GET /?s=<term>`). `nonisolated`: the app uses default
// MainActor isolation and the `Decodable` must work outside it.

nonisolated struct HomeResponse: Decodable, Equatable, Sendable {
    let search: [Movie]
    let totalResults: String

    struct Movie: Decodable, Equatable, Sendable {
        let title: String
        let year: String
        let imdbID: String
        let type: String
        let poster: String

        enum CodingKeys: String, CodingKey {
            case title = "Title"
            case year = "Year"
            case imdbID
            case type = "Type"
            case poster = "Poster"
        }
    }

    enum CodingKeys: String, CodingKey {
        case search = "Search"
        case totalResults
    }
}

// MARK: - Client (the Feature's dependency)
//
// The Feature uses the client through `@Dependency(\.homeClient)`. In tests, each
// endpoint is overridden: `deps.homeClient.fetchData = { .fixture() }`.

struct HomeClient: Sendable {
    var fetchData: @Sendable () async throws -> HomeResponse
}

extension HomeClient: DependencyKey {
    static let liveValue = HomeClient(
        fetchData: { try await HomeService().fetchData() }
    )

    static let testValue = HomeClient(
        fetchData: { throw UnimplementedError("HomeClient.fetchData") }
    )
}

extension DependencyValues {
    var homeClient: HomeClient {
        get { self[HomeClient.self] }
        set { self[HomeClient.self] = newValue }
    }
}

// MARK: - Implementation
//
// MovieOMDB: the script's template uses `URLSession` here. MovieOMDB has no API key,
// so the "request" goes to `OMDBFakeAPI`, which returns OMDb's JSON.

final class HomeService: Sendable {
    func fetchData() async throws -> HomeResponse {
        let data = try await OMDBFakeAPI.search()
        return try JSONDecoder().decode(HomeResponse.self, from: data)
    }
}
