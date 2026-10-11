import Foundation // URL, Date, Decimal... (with MemberImportVisibility they do not come through @testable import)
@testable import MovieOMDB

extension HomeDetailsResponse {
    static func fixture(
        title: String = "fixture-title",
        year: String = "fixture-year",
        rated: String = "fixture-rated",
        runtime: String = "fixture-runtime",
        genre: String = "fixture-genre",
        director: String = "fixture-director",
        actors: String = "fixture-actor",
        plot: String = "fixture-plot",
        poster: String = "https://example.com/fixture-poster.jpg",
        imdbRating: String = "fixture-rating",
        imdbID: String = "fixture-imdbID"
    ) -> HomeDetailsResponse {
        HomeDetailsResponse(
            title: title, year: year, rated: rated, runtime: runtime, genre: genre,
            director: director, actors: actors, plot: plot, poster: poster,
            imdbRating: imdbRating, imdbID: imdbID
        )
    }
}

extension HomeDetailsFeature.HomeDetailsViewData {
    static func fixture(
        title: String = "fixture-title",
        posterURL: URL? = URL(string: "https://example.com/fixture-poster.jpg"),
        info: String = "fixture-year · fixture-runtime · fixture-rated",
        genres: [String] = ["fixture-genre"],
        rating: String? = "fixture-rating",
        plot: String = "fixture-plot",
        director: String? = "fixture-director",
        actors: [String] = ["fixture-actor"]
    ) -> HomeDetailsFeature.HomeDetailsViewData {
        HomeDetailsFeature.HomeDetailsViewData(
            title: title, posterURL: posterURL, info: info, genres: genres,
            rating: rating, plot: plot, director: director, actors: actors
        )
    }
}
