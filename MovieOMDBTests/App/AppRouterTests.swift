import ComposableKit
import SwiftUI // UIHostingController.rootView (MemberImportVisibility)
import Testing
import UIKit
@testable import MovieOMDB

// AppRouter implements the scenes' `navigate` (the Coordinator's role).
// The scene tests check which Route is requested; here we check what each
// Route does to the navigation stack.

@MainActor
@Suite("AppRouter", .timeLimit(.minutes(1)))
struct AppRouterTests {

    @Test
    func makeHomeShouldReturnHomeScene() {
        let navigationController = UINavigationController()

        let viewController = AppRouter.makeHome(in: navigationController)

        #expect(viewController is UIHostingController<HomeView>)
    }

    @Test
    func movieDetailsRouteShouldPushHomeDetailsWithTheTappedMovie() async throws {
        let navigationController = UINavigationController()
        navigationController.viewControllers = [AppRouter.makeHome(in: navigationController)]
        let home = try #require(navigationController.topViewController as? UIHostingController<HomeView>)

        await home.rootView.store.send(.tapMovie(id: "tt0468569")).finish()

        #expect(navigationController.viewControllers.count == 2)
        let details = try #require(navigationController.topViewController as? UIHostingController<HomeDetailsView>)
        #expect(details.rootView.store.state == HomeDetailsFeature.State(imdbID: "tt0468569"))
    }

    @Test
    func backRouteFromHomeDetailsShouldPopToHome() async throws {
        let navigationController = UINavigationController()
        let home = AppRouter.makeHome(in: navigationController)
        let details = AppRouter.makeHomeDetails(imdbID: "tt0468569", in: navigationController)
        navigationController.viewControllers = [home, details]
        let detailsScene = try #require(details as? UIHostingController<HomeDetailsView>)

        await detailsScene.rootView.store.send(.tapBack).finish()

        #expect(navigationController.viewControllers == [home])
    }
}
