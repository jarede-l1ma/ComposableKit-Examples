import ComposableKit
import SwiftUI
import UIKit

// MovieOMDB layout (OMDb style). It follows the "View contract" in docs/ARCHITECTURE.md (section 9).

struct HomeDetailsView: View {
    @ObservedObject var store: StoreOf<HomeDetailsFeature>

    var body: some View {
        VStack(spacing: 0) {
            // Outside the Group: "Back" is also available while loading and on error.
            HStack {
                Button {
                    store.send(.tapBack)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title3.weight(.semibold))
                        .frame(width: 44, height: 44)
                }
                .tint(.primary)
                .accessibilityLabel("Back")
                Spacer()
            }
            .padding(.horizontal, 8)

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
        }
        .task { await store.send(.viewDidAppear).finish() }
    }

    @ViewBuilder
    private func contentView(viewData: HomeDetailsFeature.HomeDetailsViewData) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PosterImage(url: viewData.posterURL, cornerRadius: 16)
                    .frame(maxWidth: 280)
                    .shadow(color: .black.opacity(0.25), radius: 16, y: 8)
                    .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 8) {
                    Text(viewData.title)
                        .font(.largeTitle.bold())

                    if !viewData.info.isEmpty {
                        Text(viewData.info)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if let rating = viewData.rating {
                        Label("\(rating) / 10 on IMDb", systemImage: "star.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.orange)
                    }
                }

                if !viewData.genres.isEmpty {
                    genresView(viewData.genres)
                }

                section("Plot", text: viewData.plot)

                if let director = viewData.director {
                    section("Director", text: director)
                }

                if !viewData.actors.isEmpty {
                    section("Cast", text: viewData.actors.joined(separator: "\n"))
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    private func genresView(_ genres: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(genres, id: \.self) { genre in
                    Text(genre)
                        .font(.footnote.weight(.medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.secondary.opacity(0.15)))
                }
            }
        }
    }

    private func section(_ title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(text)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
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
enum HomeDetailsFactory {
    static func make(
        imdbID: String,
        navigate: @escaping @MainActor @Sendable (HomeDetailsRoute) -> Void = { _ in }
    ) -> UIViewController {
        let store = Store(initialState: HomeDetailsFeature.State(imdbID: imdbID)) {
            HomeDetailsFeature(navigate: navigate)
        }
        return UIHostingController(rootView: HomeDetailsView(store: store))
    }
}

// MARK: - Preview

#Preview {
    HomeDetailsView(
        store: Store(initialState: HomeDetailsFeature.State(imdbID: "tt0111161")) {
            HomeDetailsFeature()
        } withDependencies: { deps in
            // The MovieOMDB API is already fake (OMDBFakeAPI); the Preview uses the liveValue.
            deps.analytics.track = { _ in }
        }
    )
}
