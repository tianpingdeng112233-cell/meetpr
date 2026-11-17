import Foundation

/// A session-owned copy of a picked video, retained until delivery or logout.
public struct ChatVideoFile: Hashable, Sendable, Identifiable {
  public static let maximumByteCount: Int64 = 200 * 1024 * 1024
  public var id: URL { fileURL }
  public let fileURL: URL
  public let contentType: String
  public let byteCount: Int64
  public let durationSeconds: Int?
  public let posterData: Data?

  public init(
    fileURL: URL, contentType: String, byteCount: Int64,
    durationSeconds: Int? = nil, posterData: Data? = nil
  ) {
    self.fileURL = fileURL
    self.contentType = contentType
    self.byteCount = byteCount
    self.durationSeconds = durationSeconds
    self.posterData = posterData
  }
}
