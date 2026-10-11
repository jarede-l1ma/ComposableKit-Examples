import Foundation
import Testing
@testable import POC_TCA

// HomeResponse.Movie fields:
//   imdbID, title, year → copied as is
//   poster              → URL (branch: "N/A" → nil; otherwise URL(string:))
//   type                → ignored by the Mapper
// HomeResponse.search   → list (order preserved)
// HomeResponse.totalResults → ignored by the Mapper

@MainActor
@Suite("Home Mapper", .timeLimit(.minutes(1)))
struct HomeMapperTests {

    @Test
    func mapShouldConvertResponseIntoViewData() {
        let viewData = HomeMapper.map(.fixture(search: [
            .fixture(title: "The Shawshank Redemption", year: "1994", imdbID: "tt0111161", poster: "https://example.com/a.jpg"),
        ]))

        #expect(viewData == HomeFeature.HomeViewData(movies: [
            HomeFeature.HomeViewData.Movie(
                id: "tt0111161",
                title: "The Shawshank Redemption",
                year: "1994",
                posterURL: URL(string: "https://example.com/a.jpg")
            ),
        ]))
    }

    /// Fixture contract: the Feature tests use `.fixture()` on both sides.
    @Test
    func mapFixtureResponseShouldProduceFixtureViewData() {
        #expect(HomeMapper.map(.fixture()) == .fixture())
    }

    // MARK: - Lista

    @Test
    func mapWithEmptySearchShouldReturnNoMovies() {
        let viewData = HomeMapper.map(.fixture(search: [], totalResults: "0"))

        #expect(viewData == HomeFeature.HomeViewData(movies: []))
    }

    @Test
    func mapWithSeveralMoviesShouldKeepTheOrder() {
        let viewData = HomeMapper.map(.fixture(search: [
            .fixture(imdbID: "tt3"),
            .fixture(imdbID: "tt1"),
            .fixture(imdbID: "tt2"),
        ], totalResults: "3"))

        #expect(viewData.movies.map(\.id) == ["tt3", "tt1", "tt2"])
    }

    // MARK: - Poster (URL + "N/A" branch)

    @Test
    func mapWithNotAvailablePosterShouldReturnNilURL() {
        let viewData = HomeMapper.map(.fixture(search: [.fixture(poster: "N/A")]))

        #expect(viewData.movies.first?.posterURL == nil)
    }

    @Test
    func mapWithEmptyPosterShouldReturnNilURL() {
        let viewData = HomeMapper.map(.fixture(search: [.fixture(poster: "")]))

        #expect(viewData.movies.first?.posterURL == nil)
    }
}
