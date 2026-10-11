import ComposableKit
import Foundation

// MARK: - Response
//
// OMDb detail format (`GET /?i=<imdbID>`). `nonisolated`: the app uses default
// MainActor isolation and the `Decodable` must work outside it.

nonisolated struct HomeDetailsResponse: Decodable, Equatable, Sendable {
    let title: String
    let year: String
    let rated: String
    let runtime: String
    let genre: String
    let director: String
    let actors: String
    let plot: String
    let poster: String
    let imdbRating: String
    let imdbID: String

    enum CodingKeys: String, CodingKey {
        case title = "Title"
        case year = "Year"
        case rated = "Rated"
        case runtime = "Runtime"
        case genre = "Genre"
        case director = "Director"
        case actors = "Actors"
        case plot = "Plot"
        case poster = "Poster"
        case imdbRating
        case imdbID
    }
}

// MARK: - Client (the Feature's dependency)
//
// The Feature uses the client through `@Dependency(\.homeDetailsClient)`. In tests, each
// endpoint is overridden: `deps.homeDetailsClient.fetchMovie = { _ in .fixture() }`.

struct HomeDetailsClient: Sendable {
    var fetchMovie: @Sendable (_ imdbID: String) async throws -> HomeDetailsResponse
}

extension HomeDetailsClient: DependencyKey {
    static let liveValue = HomeDetailsClient(
        fetchMovie: { imdbID in try await HomeDetailsService().fetchMovie(imdbID: imdbID) }
    )

    static let testValue = HomeDetailsClient(
        fetchMovie: { _ in throw UnimplementedError("HomeDetailsClient.fetchMovie") }
    )
}

extension DependencyValues {
    var homeDetailsClient: HomeDetailsClient {
        get { self[HomeDetailsClient.self] }
        set { self[HomeDetailsClient.self] = newValue }
    }
}

// MARK: - Implementation
//
// POC: the script's template uses `URLSession` here. The POC has no API key,
// so the "request" goes to `OMDBFakeAPI`, which returns OMDb's JSON.

final class HomeDetailsService: Sendable {
    func fetchMovie(imdbID: String) async throws -> HomeDetailsResponse {
        let data = try await OMDBFakeAPI.movie(imdbID: imdbID)
        return try JSONDecoder().decode(HomeDetailsResponse.self, from: data)
    }
}
