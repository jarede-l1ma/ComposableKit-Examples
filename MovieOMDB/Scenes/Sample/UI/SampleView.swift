import ComposableKit
import SwiftUI
import UIKit

// PLACEHOLDER: replace this View with the real layout of the scene.
// When replacing it, keep the "View contract" of the ComposableKit architecture guide (section 9).

struct SampleView: View {
    @ObservedObject var store: StoreOf<SampleFeature>

    var body: some View {
        VStack(spacing: 0) {
            // Outside the content: "Close" also works while loading and on error.
            HStack {
                Spacer()
                Button {
                    store.send(.tapClose)
                } label: {
                    Image(systemName: "xmark")
                        .font(.title3.weight(.semibold))
                        .frame(width: 44, height: 44)
                }
                .tint(.primary)
                .accessibilityLabel("Close")
            }
            .padding(.horizontal, 8)

            Group {
                if let viewData = store.viewData {
                    // Loaded content stays on screen during "Try again";
                    // if the new attempt fails, the warning appears above it.
                    if let errorMessage = store.errorMessage {
                        errorBanner(message: errorMessage)
                    }
                    contentView(viewData: viewData)
                } else if store.isLoading {
                    ProgressView()
                } else if let errorMessage = store.errorMessage {
                    errorView(message: errorMessage)
                } else {
                    ProgressView() // idle
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task { await store.send(.viewDidAppear).finish() }
    }

    @ViewBuilder
    private func contentView(viewData: SampleFeature.SampleViewData) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // TODO: build the real layout of the scene here
            VStack(alignment: .leading, spacing: 24) {
                Text("Scene title")
                    .font(.largeTitle.bold())
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)

            Spacer()

            Button {
                store.send(.tapContinue)
            } label: {
                Text("Continue")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .padding(24)
        }
    }

    /// Reload failure with content on screen.
    @ViewBuilder
    private func errorBanner(message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(message)
                .font(.body)

            Button("Try again") {
                store.send(.tapRetry)
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }

    @ViewBuilder
    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)

            Button {
                store.send(.tapRetry)
            } label: {
                Text("Try again")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
    }
}

// MARK: - Factory

@MainActor
enum SampleFactory {
    static func make(
        navigate: @escaping @MainActor @Sendable (SampleRoute) -> Void = { _ in }
    ) -> UIViewController {
        let store = Store(initialState: SampleFeature.State()) {
            SampleFeature(navigate: navigate)
        }
        return UIHostingController(rootView: SampleView(store: store))
    }
}

// MARK: - Preview

#Preview {
    SampleView(
        store: Store(initialState: SampleFeature.State()) {
            SampleFeature()
        } withDependencies: { deps in
            // TODO: return mock data for the Preview
            deps.sampleClient.fetchData = { SampleResponse() }
            deps.analytics.track = { _ in }
        }
    )
}
