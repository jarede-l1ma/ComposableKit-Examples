enum HomeAnalyticsModel {
    struct ScreenViewEvent: AnalyticsEvent {
        let name = "screen_view"
        var parameters: [String: String] { ["screen_name": "home"] }
    }

    struct SelectContentEvent: AnalyticsEvent {
        let name = "select_content"
        let item: Item
        let movieID: String // imdbID of the tapped movie
        var parameters: [String: String] { ["screen_name": "home", "item": item.rawValue, "movie_id": movieID] }

        enum Item: String {
            case tapMovie = "movie_card"
        }
    }

    struct AlertEvent: AnalyticsEvent {
        let name = "alert"
        let message: String
        var parameters: [String: String] { ["screen_name": "home", "message": message] }
    }
}
