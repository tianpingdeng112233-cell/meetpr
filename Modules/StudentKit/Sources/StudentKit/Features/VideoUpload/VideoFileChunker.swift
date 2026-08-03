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

  /// Materializes every chunk as a file suitable for a background URLSession
  /// upload task. Existing files are replaced so a retry never reuses a
  /// partially written chunk left by a terminated process.
  public func writeParts(from fileURL: URL, to directory: URL) throws -> [URL] {
    let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
    guard let totalBytes = attributes[.size] as? Int64 else {
      throw VideoUploadError.fileUnreadable
    }
    let count = try partCount(totalBytes: totalBytes)
    try? FileManager.default.removeItem(at: directory)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    do {
      return try (1...count).map { partNumber in
        let destination = partFileURL(partNumber: partNumber, in: directory)
        try readPart(partNumber: partNumber, from: fileURL).write(
          to: destination,
          options: .atomic
        )
        return destination
      }
    } catch {
      try? FileManager.default.removeItem(at: directory)
      throw error
    }
  }

  /// Materializes one selected chunk without replacing sibling files that
  /// may still be owned by background URLSession tasks.
  public func writePart(partNumber: Int, from fileURL: URL, to directory: URL) throws -> URL {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let destination = partFileURL(partNumber: partNumber, in: directory)
    try readPart(partNumber: partNumber, from: fileURL).write(to: destination, options: .atomic)
    return destination
  }

  public func partFileURL(partNumber: Int, in directory: URL) -> URL {
    directory.appending(path: "part-\(partNumber).chunk")
  }
}
