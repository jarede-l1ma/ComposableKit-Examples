//
//  POC_TCAApp.swift
//  POC_TCA
//
//  Created by Jarede Lima on 29/09/26.
//

import SwiftUI
import UIKit

@main
struct POC_TCAApp: App {
    var body: some Scene {
        WindowGroup {
            RootNavigationView()
                .ignoresSafeArea()
        }
    }
}

// MARK: - Root
//
// Bridge between the POC's SwiftUI App and UIKit navigation: each scene is
// created by its Factory (UIViewController) and pushed onto a
// UINavigationController. The native bar is hidden because each scene draws
// its own (close/back button in the View).

private struct RootNavigationView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UINavigationController {
        let navigationController = UINavigationController()
        navigationController.setNavigationBarHidden(true, animated: false)
        navigationController.viewControllers = [AppRouter.makeHome(in: navigationController)]
        return navigationController
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}
}

// MARK: - AppRouter
//
// The Coordinator's role: whoever creates the scene decides what each Route does,
// by injecting the `navigate` closure into the Factory.

enum AppRouter {
    static func makeHome(in navigationController: UINavigationController) -> UIViewController {
        HomeFactory.make { [weak navigationController] route in
            guard let navigationController else { return }

            switch route {
            case let .movieDetails(imdbID):
                navigationController.pushViewController(
                    makeHomeDetails(imdbID: imdbID, in: navigationController),
                    animated: true
                )
            }
        }
    }

    static func makeHomeDetails(imdbID: String, in navigationController: UINavigationController) -> UIViewController {
        HomeDetailsFactory.make(imdbID: imdbID) { [weak navigationController] route in
            switch route {
            case .back:
                navigationController?.popViewController(animated: true)
            }
        }
    }
}
