import Foundation

public struct ChatVideoCoverPresentation: Equatable, Sendable {
  public static func frameSize(imageSize: CGSize?, availableWidth: CGFloat) -> CGSize {
    guard let imageSize, imageSize.width > 0, imageSize.height > imageSize.width,
      imageSize.width.isFinite, imageSize.height.isFinite
    else { return CGSize(width: availableWidth, height: 150) }
    return CGSize(width: max(135, 240 * imageSize.width / imageSize.height), height: 240)
  }

  public let posterURL: URL?
  public let durationText: String?

  public init(posterURL: URL?, durationSeconds: Int?) {
    self.posterURL = posterURL.flatMap { url in
      guard ["http", "https"].contains(url.scheme?.lowercased() ?? ""), url.host != nil else {
        return nil
      }
      return url
    }
    if let durationSeconds, durationSeconds >= 0 {
      let seconds = durationSeconds % 60
      durationText = "\(durationSeconds / 60):\(seconds < 10 ? "0" : "")\(seconds)"
    } else {
      durationText = nil
    }
  }
}
