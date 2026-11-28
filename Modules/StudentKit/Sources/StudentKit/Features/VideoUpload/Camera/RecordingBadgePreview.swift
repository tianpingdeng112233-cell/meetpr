#if os(iOS)
  import AVFoundation
  import ChatUI
  import SwiftUI

  /// Fit to the letterboxed video, including recordings with a rotation transform.
  struct RecordingBadgePreview: View {
    let url: URL
    let badge: VideoBadgeInfo
    @State private var aspect: CGSize = .zero

    var body: some View {
      GeometryReader { proxy in
        if aspect.width > 0, aspect.height > 0 {
          let rect = AVMakeRect(
            aspectRatio: aspect, insideRect: CGRect(origin: .zero, size: proxy.size))
          VideoBadgeExportOverlay(info: badge, size: rect.size)
            .position(x: rect.midX, y: rect.midY)
        }
      }
      .allowsHitTesting(false)
      .task(id: url) {
        aspect = .zero
        let asset = AVURLAsset(url: url)
        guard let track = try? await asset.loadTracks(withMediaType: .video).first,
          let size = try? await track.load(.naturalSize),
          let transform = try? await track.load(.preferredTransform), !Task.isCancelled
        else { return }
        aspect = CGRect(origin: .zero, size: size).applying(transform).standardized.size
      }
    }
  }
#endif
