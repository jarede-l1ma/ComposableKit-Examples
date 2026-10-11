import ComposableKit
import SwiftUI
import UIKit

// POC layout (OMDb style). It follows the "View contract" in docs/ARCHITECTURE.md (section 9).

struct HomeView: View {
    @ObservedObject var store: StoreOf<HomeFeature>

    var body: some View {
        Group {
            if let viewData = store.viewData {
                contentView(viewData: viewData) // stays on screen during "Try again"
            } else if store.isLoading {
                ProgressView()
            } else if let errorMessage = store.errorMessage {
                errorView(message: errorMessage)
            } else {
                ProgressView() // idle
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { await store.send(.viewDidAppear).finish() }
    }

    @ViewBuilder
    private func contentView(viewData: HomeFeature.HomeViewData) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                Text("Movies")
                    .font(.largeTitle.bold())
                    .padding(.bottom, 8)

                ForEach(viewData.movies) { movie in
                    movieRow(movie)
                }
            }
            .padding(24)
        }
    }

    private func movieRow(_ movie: HomeFeature.HomeViewData.Movie) -> some View {
        Button {
            store.send(.tapMovie(id: movie.id))
        } label: {
            HStack(spacing: 16) {
                PosterImage(url: movie.posterURL)
                    .frame(width: 72)

                VStack(alignment: .leading, spacing: 4) {
                    Text(movie.title)
                        .font(.headline)
                        .multilineTextAlignment(.leading)
                    Text(movie.year)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(movie.title), \(movie.year)")
        .accessibilityAddTraits(.isButton)
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
enum HomeFactory {
    static func make(
        navigate: @escaping @MainActor @Sendable (HomeRoute) -> Void = { _ in }
    ) -> UIViewController {
        let store = Store(initialState: HomeFeature.State()) {
            HomeFeature(navigate: navigate)
        }
        return UIHostingController(rootView: HomeView(store: store))
    }
}

// MARK: - Preview

#Preview {
    HomeView(
        store: Store(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: { deps in
            // The POC API is already fake (OMDBFakeAPI); the Preview uses the liveValue.
            deps.analytics.track = { _ in }
        }
    )
}
