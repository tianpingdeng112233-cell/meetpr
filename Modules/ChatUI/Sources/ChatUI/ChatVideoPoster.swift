import SwiftUI

/// Transparent until an image succeeds, leaving each card's original dark fill visible.
public struct ChatVideoPoster: View {
  let url: URL?
  let videoID: UUID?
  @State private var image: Image?
  @State private var loadedURL: URL?

  public init(url: URL?, videoID: UUID? = nil) {
    self.url = url
    self.videoID = videoID
  }

  public var body: some View {
    Color.clear
      .overlay {
        if loadedURL == url, let image {
          image.resizable().scaledToFill()
        }
      }
      .clipped()
      .accessibilityHidden(true)
      .task(id: url) {
        image = nil
        loadedURL = nil
        guard let url else { return }
        do {
          let data = try await ChatPosterLoader.shared.data(for: url)
          try Task.checkCancellation()
          let size: CGSize?
          #if os(iOS)
            let decoded = UIImage(data: data)
            image = decoded.map { Image(uiImage: $0) }
            size = decoded?.size
          #elseif os(macOS)
            let decoded = NSImage(data: data)
            image = decoded.map { Image(nsImage: $0) }
            size = decoded?.size
          #endif
          if let videoID {
            ChatVideoPosterDimensions.shared.remember(size, for: videoID)
          }
          loadedURL = url
        } catch {
          guard !Task.isCancelled else { return }
          if let videoID {
            ChatVideoPosterDimensions.shared.remember(nil, for: videoID)
          }
          // Missing, expired and offline posters all keep the original fill.
        }
      }
  }
}
