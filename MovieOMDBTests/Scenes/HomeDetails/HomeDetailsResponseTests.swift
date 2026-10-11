import Foundation
import Testing
@testable import MovieOMDB

// API contract: OMDb detail (`GET /?i=<imdbID>`).
// The keys below are OMDb's (https://www.omdbapi.com), not the CodingKeys.

@MainActor
@Suite("HomeDetails Response", .timeLimit(.minutes(1)))
struct HomeDetailsResponseTests {

    /// Full OMDb response. Keys the app does not use (Released, Writer,
    /// Ratings, Response...) are here on purpose: they must be ignored.
    private let apiJSON = """
    {
      "Title": "The Dark Knight",
      "Year": "2008",
      "Rated": "PG-13",
      "Released": "18 Jul 2008",
      "Runtime": "152 min",
      "Genre": "Action, Crime, Drama",
      "Director": "Christopher Nolan",
      "Writer": "Jonathan Nolan, Christopher Nolan",
      "Actors": "Christian Bale, Heath Ledger, Aaron Eckhart",
      "Plot": "Batman faces the Joker.",
      "Language": "English",
      "Country": "United States, United Kingdom",
      "Poster": "https://example.com/dark-knight.jpg",
      "Ratings": [{ "Source": "Internet Movie Database", "Value": "9.0/10" }],
      "Metascore": "84",
      "imdbRating": "9.0",
      "imdbVotes": "2,900,000",
      "imdbID": "tt0468569",
      "Type": "movie",
      "Response": "True"
    }
    """

    @Test
    func decodeShouldReadEveryFieldFromTheAPIJSON() throws {
        let response = try decode(apiJSON)

        #expect(response == HomeDetailsResponse(
            title: "The Dark Knight",
            year: "2008",
            rated: "PG-13",
            runtime: "152 min",
            genre: "Action, Crime, Drama",
            director: "Christopher Nolan",
            actors: "Christian Bale, Heath Ledger, Aaron Eckhart",
            plot: "Batman faces the Joker.",
            poster: "https://example.com/dark-knight.jpg",
            imdbRating: "9.0",
            imdbID: "tt0468569"
        ))
    }

    /// Every field the app reads is required: without any of them, decoding fails.
    @Test(arguments: [
        "Title", "Year", "Rated", "Runtime", "Genre", "Director",
        "Actors", "Plot", "Poster", "imdbRating", "imdbID",
    ])
    func decodeWithoutRequiredKeyShouldFail(_ key: String) throws {
        let json = try removing(key, from: apiJSON)

        #expect(throws: DecodingError.self) {
            try decode(json)
        }
    }

    // MARK: - Helpers

    /// Same decoder as `HomeDetailsService`.
    private func decode(_ json: String) throws -> HomeDetailsResponse {
        try JSONDecoder().decode(HomeDetailsResponse.self, from: Data(json.utf8))
    }

    private func removing(_ key: String, from json: String) throws -> String {
        var object = try #require(try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
        object[key] = nil
        return String(decoding: try JSONSerialization.data(withJSONObject: object), as: UTF8.self)
    }
}
