import Foundation

enum HomeDetailsMapper {
    static func map(_ result: HomeDetailsResponse) -> HomeDetailsFeature.HomeDetailsViewData {
        HomeDetailsFeature.HomeDetailsViewData(
            title: result.title,
            posterURL: value(result.poster).flatMap(URL.init(string:)),
            info: [result.year, result.runtime, result.rated].compactMap { value($0) }.joined(separator: " · "),
            genres: list(result.genre),
            rating: value(result.imdbRating),
            plot: value(result.plot) ?? "Plot unavailable.",
            director: value(result.director),
            actors: list(result.actors)
        )
    }

    /// OMDb uses "N/A" for fields without a value.
    private static func value(_ field: String) -> String? {
        let trimmed = field.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty || trimmed == "N/A" ? nil : trimmed
    }

    /// OMDb fields with several values are comma-separated ("Crime, Drama").
    private static func list(_ field: String) -> [String] {
        guard let field = value(field) else { return [] }
        return field.split(separator: ",").compactMap { value(String($0)) }
    }
}
