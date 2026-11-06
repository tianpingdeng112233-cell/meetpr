import Foundation

public struct ChatVideoCoverPresentation: Equatable, Sendable {
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
