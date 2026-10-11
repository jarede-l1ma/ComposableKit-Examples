import Foundation
import Testing
@testable import POC_TCA

// HomeDetailsResponse → HomeDetailsViewData fields:
//   title                → copied as is
//   poster               → URL (branch: "N/A" or empty → nil)
//   year, runtime, rated → info: joined with " · ", skipping "N/A"/empty
//   genre, actors        → comma-separated lists (order kept; empty items dropped)
//   imdbRating, director → optional ("N/A" → nil)
//   plot                 → `??` branch: "N/A" → "Plot unavailable."
//   imdbID               → ignored by the Mapper
// All go through `value(_:)`: leading/trailing spaces are trimmed.

@MainActor
@Suite("HomeDetails Mapper", .timeLimit(.minutes(1)))
struct HomeDetailsMapperTests {

    @Test
    func mapShouldConvertResponseIntoViewData() {
        let viewData = HomeDetailsMapper.map(.fixture(
            title: "The Shawshank Redemption",
            year: "1994",
            rated: "R",
            runtime: "142 min",
            genre: "Drama",
            director: "Frank Darabont",
            actors: "Tim Robbins, Morgan Freeman",
            plot: "Two prisoners form a friendship.",
            poster: "https://example.com/poster.jpg",
            imdbRating: "9.3",
            imdbID: "tt0111161"
        ))

        #expect(viewData == HomeDetailsFeature.HomeDetailsViewData(
            title: "The Shawshank Redemption",
            posterURL: URL(string: "https://example.com/poster.jpg"),
            info: "1994 · 142 min · R",
            genres: ["Drama"],
            rating: "9.3",
            plot: "Two prisoners form a friendship.",
            director: "Frank Darabont",
            actors: ["Tim Robbins", "Morgan Freeman"]
        ))
    }

    /// Fixture contract: the Feature tests use `.fixture()` on both sides.
    @Test
    func mapFixtureResponseShouldProduceFixtureViewData() {
        #expect(HomeDetailsMapper.map(.fixture()) == .fixture())
    }

    // MARK: - Poster (URL)

    @Test
    func mapWithNotAvailablePosterShouldReturnNilURL() {
        #expect(HomeDetailsMapper.map(.fixture(poster: "N/A")).posterURL == nil)
    }

    @Test
    func mapWithEmptyPosterShouldReturnNilURL() {
        #expect(HomeDetailsMapper.map(.fixture(poster: "")).posterURL == nil)
    }

    // MARK: - info (year, runtime, rated joined)

    @Test
    func mapShouldSkipNotAvailablePartsOfInfo() {
        let viewData = HomeDetailsMapper.map(.fixture(year: "2008", rated: "N/A", runtime: "152 min"))

        #expect(viewData.info == "2008 · 152 min")
    }

    @Test
    func mapWithoutAnyInfoPartShouldReturnEmptyInfo() {
        let viewData = HomeDetailsMapper.map(.fixture(year: "N/A", rated: "", runtime: "N/A"))

        #expect(viewData.info == "")
    }

    // MARK: - Listas (genres, actors)

    @Test
    func mapShouldSplitGenresKeepingOrderAndTrimming() {
        let viewData = HomeDetailsMapper.map(.fixture(genre: "Action,  Crime ,Drama"))

        #expect(viewData.genres == ["Action", "Crime", "Drama"])
    }

    @Test
    func mapShouldDropEmptyItemsFromLists() {
        let viewData = HomeDetailsMapper.map(.fixture(actors: "Uma Thurman, , Samuel L. Jackson"))

        #expect(viewData.actors == ["Uma Thurman", "Samuel L. Jackson"])
    }

    @Test
    func mapWithNotAvailableListsShouldReturnEmptyLists() {
        let viewData = HomeDetailsMapper.map(.fixture(genre: "N/A", actors: ""))

        #expect(viewData.genres == [])
        #expect(viewData.actors == [])
    }

    // MARK: - Opcionais e fallback

    @Test
    func mapWithNotAvailableRatingAndDirectorShouldReturnNil() {
        let viewData = HomeDetailsMapper.map(.fixture(director: "N/A", imdbRating: "N/A"))

        #expect(viewData.rating == nil)
        #expect(viewData.director == nil)
    }

    @Test
    func mapWithNotAvailablePlotShouldUseFallbackText() {
        #expect(HomeDetailsMapper.map(.fixture(plot: "N/A")).plot == "Plot unavailable.")
    }

    @Test
    func mapShouldTrimSpacesAroundValues() {
        let viewData = HomeDetailsMapper.map(.fixture(director: "  Christopher Nolan  ", imdbRating: " 9.0 "))

        #expect(viewData.director == "Christopher Nolan")
        #expect(viewData.rating == "9.0")
    }
}
