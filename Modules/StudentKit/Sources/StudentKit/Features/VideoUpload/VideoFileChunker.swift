import Foundation

/// Slices the exported video file into fixed-size multipart chunks.
/// Reads one part at a time through `FileHandle` so a 200 MB fallback video
/// never sits fully in memory.
public struct VideoFileChunker: Sendable {
  public let partSizeBytes: Int

  public init(partSizeBytes: Int) {
    precondition(partSizeBytes > 0, "partSizeBytes must be positive")
    self.partSizeBytes = partSizeBytes
  }

  /// Number of parts needed for `totalBytes`; an exact multiple of the part
  /// size produces no trailing empty part.
  public func partCount(totalBytes: Int64) throws -> Int {
    guard totalBytes > 0 else {
      throw VideoUploadError.emptyFile
    }
    let size = Int64(partSizeBytes)
    return Int((totalBytes + size - 1) / size)
  }

  /// Reads the chunk for 1-based `partNumber` from `fileURL`.
  public func readPart(partNumber: Int, from fileURL: URL) throws -> Data {
    precondition(partNumber >= 1, "partNumber is 1-based")
    let handle = try FileHandle(forReadingFrom: fileURL)
    defer { try? handle.close() }

    let offset = UInt64(partNumber - 1) * UInt64(partSizeBytes)
    try handle.seek(toOffset: offset)
    guard let data = try handle.read(upToCount: partSizeBytes), !data.isEmpty else {
      throw VideoUploadError.fileUnreadable
    }
    return data
  }
}
