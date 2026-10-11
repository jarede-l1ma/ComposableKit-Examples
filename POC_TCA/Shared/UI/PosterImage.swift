import SwiftUI

// MARK: - Movie poster
//
// Loads the remote image with `AsyncImage` (iOS 15+) and shows a placeholder
// while loading or if the image fails. Used by the Home and HomeDetails scenes.

struct PosterImage: View {
    let url: URL?
    var cornerRadius: CGFloat = 8

    var body: some View {
        AsyncImage(url: url, transaction: Transaction(animation: .easeInOut)) { phase in
            switch phase {
            case let .success(image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            case .failure:
                placeholder(systemName: "film")
            case .empty:
                placeholder(systemName: nil)
            @unknown default:
                placeholder(systemName: "film")
            }
        }
        .aspectRatio(2 / 3, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .accessibilityHidden(true)
    }

    private func placeholder(systemName: String?) -> some View {
        ZStack {
            Color.secondary.opacity(0.15)
            if let systemName {
                Image(systemName: systemName)
                    .font(.title)
                    .foregroundStyle(.secondary)
            } else {
                ProgressView()
            }
        }
    }
}
