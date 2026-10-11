import Foundation

enum HomeMapper {
    static func map(_ result: HomeResponse) -> HomeFeature.HomeViewData {
        HomeFeature.HomeViewData(
            movies: result.search.map { movie in
                HomeFeature.HomeViewData.Movie(
                    id: movie.imdbID,
                    title: movie.title,
                    year: movie.year,
                    posterURL: posterURL(from: movie.poster)
                )
            }
        )
    }

    /// OMDb uses "N/A" when the movie has no poster.
    static func posterURL(from poster: String) -> URL? {
        guard poster != "N/A" else { return nil }
        return URL(string: poster)
    }
}
