// TODO: event names and parameters are placeholders until you have the tracking spec.
// `sample` (screen_name) was derived from the scene name: check it against the spec.
enum SampleAnalyticsModel {
    struct ScreenViewEvent: AnalyticsEvent {
        let name = "screen_view"
        var parameters: [String: String] { ["screen_name": "sample"] }
    }

    struct SelectContentEvent: AnalyticsEvent {
        let name = "select_content"
        let item: Item
        var parameters: [String: String] { ["screen_name": "sample", "item": item.rawValue] }

        enum Item: String {
            case tapContinue = "continue"
            case tapClose = "close"
        }
    }

    struct AlertEvent: AnalyticsEvent {
        let name = "alert"
        let message: String
        var parameters: [String: String] { ["screen_name": "sample", "message": message] }
    }
}
