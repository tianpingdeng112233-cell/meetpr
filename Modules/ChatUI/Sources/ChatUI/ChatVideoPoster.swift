import SwiftUI

/// Transparent until an image succeeds, leaving each card's original dark fill visible.
public struct ChatVideoPoster: View {
  let url: URL?
  @State private var image: Image?
  @State private var loadedURL: URL?

  public init(url: URL?) { self.url = url }

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
          #if os(iOS)
            if let decoded = UIImage(data: data) { image = Image(uiImage: decoded) }
          #elseif os(macOS)
            if let decoded = NSImage(data: data) { image = Image(nsImage: decoded) }
          #endif
          loadedURL = url
        } catch {
          // Missing, expired and offline posters all keep the original fill.
        }
      }
  }
}
