enum HomeDetailsAnalyticsModel {
    struct ScreenViewEvent: AnalyticsEvent {
        let name = "screen_view"
        let movieID: String // imdbID of the displayed movie
        var parameters: [String: String] { ["screen_name": "home-details", "movie_id": movieID] }
    }

    struct SelectContentEvent: AnalyticsEvent {
        let name = "select_content"
        let item: Item
        var parameters: [String: String] { ["screen_name": "home-details", "item": item.rawValue] }

        enum Item: String {
            case tapBack = "back"
        }
    }

    struct AlertEvent: AnalyticsEvent {
        let name = "alert"
        let message: String
        var parameters: [String: String] { ["screen_name": "home-details", "message": message] }
    }
}
