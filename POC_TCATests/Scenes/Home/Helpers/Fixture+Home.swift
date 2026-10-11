import Foundation
@testable import POC_TCA

extension HomeResponse {
    static func fixture(
        search: [HomeResponse.Movie] = [.fixture()],
        totalResults: String = "1"
    ) -> HomeResponse {
        HomeResponse(search: search, totalResults: totalResults)
    }
}

extension HomeResponse.Movie {
    static func fixture(
        title: String = "fixture-title",
        year: String = "fixture-year",
        imdbID: String = "fixture-imdbID",
        type: String = "movie",
        poster: String = "https://example.com/fixture-poster.jpg"
    ) -> HomeResponse.Movie {
        HomeResponse.Movie(title: title, year: year, imdbID: imdbID, type: type, poster: poster)
    }
}

extension HomeFeature.HomeViewData {
    static func fixture(movies: [HomeFeature.HomeViewData.Movie] = [.fixture()]) -> HomeFeature.HomeViewData {
        HomeFeature.HomeViewData(movies: movies)
    }
}

extension HomeFeature.HomeViewData.Movie {
    static func fixture(
        id: String = "fixture-imdbID",
        title: String = "fixture-title",
        year: String = "fixture-year",
        posterURL: URL? = URL(string: "https://example.com/fixture-poster.jpg")
    ) -> HomeFeature.HomeViewData.Movie {
        HomeFeature.HomeViewData.Movie(id: id, title: title, year: year, posterURL: posterURL)
    }
}
