#if os(iOS)
  import AVFoundation
  import UIKit

  struct VideoTrimThumbnail: Identifiable {
    let id: Int
    let image: UIImage
  }

  struct VideoTrimThumbnailGenerator {
    func thumbnails(
      sourceURL: URL,
      durationSeconds: Double,
      count: Int
    ) async -> [VideoTrimThumbnail] {
      guard durationSeconds > 0, count > 0 else { return [] }
      let asset = AVURLAsset(url: sourceURL)
      let generator = AVAssetImageGenerator(asset: asset)
      generator.appliesPreferredTrackTransform = true
      generator.maximumSize = CGSize(width: 320, height: 180)
      generator.requestedTimeToleranceBefore = .zero
      generator.requestedTimeToleranceAfter = .zero

      var thumbnails: [VideoTrimThumbnail] = []
      for index in 0..<count {
        guard !Task.isCancelled else { return [] }
        let fraction = (Double(index) + 0.5) / Double(count)
        let time = CMTime(
          seconds: durationSeconds * fraction,
          preferredTimescale: 600
        )
        do {
          let result = try await generator.image(at: time)
          thumbnails.append(
            VideoTrimThumbnail(id: index, image: UIImage(cgImage: result.image))
          )
        } catch {
          // Thumbnail generation is decorative. One unsupported frame should
          // degrade the entire strip to handles instead of blocking trimming.
          return []
        }
      }
      return thumbnails
    }
  }
#endif
