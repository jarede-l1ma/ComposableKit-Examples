import Foundation
import Testing
@testable import MovieOMDB

// API contract: OMDb search (`GET /?s=<term>`).
// The keys below are OMDb's (https://www.omdbapi.com), not the CodingKeys.

@MainActor
@Suite("Home Response", .timeLimit(.minutes(1)))
struct HomeResponseTests {

    /// OMDb response with 2 movies. `"Response"` comes from the API and is not used by the app.
    private let apiJSON = """
    {
      "Search": [
        {
          "Title": "The Shawshank Redemption",
          "Year": "1994",
          "imdbID": "tt0111161",
          "Type": "movie",
          "Poster": "https://example.com/shawshank.jpg"
        },
        {
          "Title": "The Godfather",
          "Year": "1972",
          "imdbID": "tt0068646",
          "Type": "series",
          "Poster": "N/A"
        }
      ],
      "totalResults": "2",
      "Response": "True"
    }
    """

    @Test
    func decodeShouldReadEveryFieldFromTheAPIJSON() throws {
        let response = try decode(apiJSON)

        #expect(response == HomeResponse(
            search: [
                HomeResponse.Movie(
                    title: "The Shawshank Redemption",
                    year: "1994",
                    imdbID: "tt0111161",
                    type: "movie",
                    poster: "https://example.com/shawshank.jpg"
                ),
                HomeResponse.Movie(
                    title: "The Godfather",
                    year: "1972",
                    imdbID: "tt0068646",
                    type: "series",
                    poster: "N/A"
                ),
            ],
            totalResults: "2"
        ))
    }

    /// Every Response field is required: without any of them, decoding fails.
    @Test(arguments: [
        RequiredKey.root("Search"),
        .root("totalResults"),
        .movie("Title"),
        .movie("Year"),
        .movie("imdbID"),
        .movie("Type"),
        .movie("Poster"),
    ])
    func decodeWithoutRequiredKeyShouldFail(_ key: RequiredKey) throws {
        let json = try removing(key, from: apiJSON)

        #expect(throws: DecodingError.self) {
            try decode(json)
        }
    }

    // MARK: - Helpers

    enum RequiredKey: CustomStringConvertible, Sendable {
        case root(String)
        case movie(String) // removed from the first item of "Search"

        var description: String {
            switch self {
            case let .root(key): key
            case let .movie(key): "Search[0].\(key)"
            }
        }
    }

    /// Same decoder as `HomeService`.
    private func decode(_ json: String) throws -> HomeResponse {
        try JSONDecoder().decode(HomeResponse.self, from: Data(json.utf8))
    }

    private func removing(_ key: RequiredKey, from json: String) throws -> String {
        var object = try #require(try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
        switch key {
        case let .root(name):
            object[name] = nil
        case let .movie(name):
            var movies = try #require(object["Search"] as? [[String: Any]])
            movies[0][name] = nil
            object["Search"] = movies
        }
        return String(decoding: try JSONSerialization.data(withJSONObject: object), as: UTF8.self)
    }
}
