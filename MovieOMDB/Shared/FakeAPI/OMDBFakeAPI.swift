import Foundation

// MARK: - Fake API in the OMDb API format (https://www.omdbapi.com)
//
// MovieOMDB does not call the real OMDb (it requires an API key). This "API" returns
// JSON in the same format as the two endpoints used:
//   - search: GET /?s=<term>   → { "Search": [...], "totalResults": "5", "Response": "True" }
//   - detail: GET /?i=<imdbID> → { "Title": ..., "Plot": ..., "Response": "True" }
// The Services decode this JSON into their Responses, as they would from the network.
// Posters: real images from TMDB's CDN (loaded by AsyncImage).

nonisolated enum OMDBFakeAPI {
    enum APIError: LocalizedError, Equatable {
        case movieNotFound(imdbID: String)

        var errorDescription: String? {
            switch self {
            case .movieNotFound:
                "Movie not found."
            }
        }
    }

    /// Simulated network latency.
    static let latency: UInt64 = 600_000_000

    /// `GET /?s=<term>`: summary list of the movies.
    static func search() async throws -> Data {
        try await Task.sleep(nanoseconds: latency)
        let results = catalog.map { movie in
            movie.filter { ["Title", "Year", "imdbID", "Type", "Poster"].contains($0.key) }
        }
        return try JSONSerialization.data(withJSONObject: [
            "Search": results,
            "totalResults": String(results.count),
            "Response": "True",
        ])
    }

    /// `GET /?i=<imdbID>`: details of a movie.
    static func movie(imdbID: String) async throws -> Data {
        try await Task.sleep(nanoseconds: latency)
        guard var movie = catalog.first(where: { $0["imdbID"] == imdbID }) else {
            throw APIError.movieNotFound(imdbID: imdbID)
        }
        movie["Response"] = "True"
        return try JSONSerialization.data(withJSONObject: movie)
    }

    // MARK: - Data

    private static let catalog: [[String: String]] = [
        [
            "Title": "The Shawshank Redemption",
            "Year": "1994",
            "Rated": "R",
            "Runtime": "142 min",
            "Genre": "Drama",
            "Director": "Frank Darabont",
            "Actors": "Tim Robbins, Morgan Freeman, Bob Gunton",
            "Plot": "Sentenced to life in prison for a crime he says he did not commit, banker Andy Dufresne spends years at Shawshank prison. There he befriends Red and finds, through hope and patience, a path to freedom.",
            "Poster": "https://image.tmdb.org/t/p/w500/q6y0Go1tsGEsmtFryDOJo3dEmqu.jpg",
            "imdbRating": "9.3",
            "imdbID": "tt0111161",
            "Type": "movie",
        ],
        [
            "Title": "The Godfather",
            "Year": "1972",
            "Rated": "R",
            "Runtime": "175 min",
            "Genre": "Crime, Drama",
            "Director": "Francis Ford Coppola",
            "Actors": "Marlon Brando, Al Pacino, James Caan",
            "Plot": "Don Vito Corleone runs one of the most powerful mafia families in New York. When an attempt on his life threatens the patriarch, his youngest son Michael, who wanted nothing to do with the family business, is pulled into the center of power.",
            "Poster": "https://image.tmdb.org/t/p/w500/3bhkrj58Vtu7enYsRolD1fZdja1.jpg",
            "imdbRating": "9.2",
            "imdbID": "tt0068646",
            "Type": "movie",
        ],
        [
            "Title": "The Dark Knight",
            "Year": "2008",
            "Rated": "PG-13",
            "Runtime": "152 min",
            "Genre": "Action, Crime, Drama",
            "Director": "Christopher Nolan",
            "Actors": "Christian Bale, Heath Ledger, Aaron Eckhart",
            "Plot": "With the help of Lieutenant Gordon and District Attorney Harvey Dent, Batman takes on Gotham's organized crime. Until the Joker appears, an unpredictable criminal willing to plunge the city into chaos.",
            "Poster": "https://image.tmdb.org/t/p/w500/qJ2tW6WMUDux911r6m7haRef0WH.jpg",
            "imdbRating": "9.0",
            "imdbID": "tt0468569",
            "Type": "movie",
        ],
        [
            "Title": "Pulp Fiction",
            "Year": "1994",
            "Rated": "R",
            "Runtime": "154 min",
            "Genre": "Crime, Drama",
            "Director": "Quentin Tarantino",
            "Actors": "John Travolta, Uma Thurman, Samuel L. Jackson",
            "Plot": "Two hitmen, a crime boss's wife, a boxer on the run and a pair of robbers have their stories intertwined in Los Angeles, told out of order.",
            "Poster": "https://image.tmdb.org/t/p/w500/d5iIlFn5s0ImszYzBPb8JPIfbXD.jpg",
            "imdbRating": "8.9",
            "imdbID": "tt0110912",
            "Type": "movie",
        ],
        [
            "Title": "Inception",
            "Year": "2010",
            "Rated": "PG-13",
            "Runtime": "148 min",
            "Genre": "Action, Adventure, Sci-Fi",
            "Director": "Christopher Nolan",
            "Actors": "Leonardo DiCaprio, Joseph Gordon-Levitt, Elliot Page",
            "Plot": "Dom Cobb is an expert at stealing secrets from the subconscious during sleep. His chance to get his old life back is the reverse mission: planting an idea in the mind of a billionaire heir.",
            "Poster": "https://image.tmdb.org/t/p/w500/9gk7adHYeDvHkCSEqAvQNLV5Uge.jpg",
            "imdbRating": "8.8",
            "imdbID": "tt1375666",
            "Type": "movie",
        ],
    ]
}
