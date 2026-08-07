import Foundation

enum RecorderVideoTrimFiles {
  static func makeWorkingCopy(of sourceURL: URL) throws -> URL {
    let pathExtension = sourceURL.pathExtension.isEmpty ? "mov" : sourceURL.pathExtension
    let destinationURL = FileManager.default.temporaryDirectory
      .appending(path: "meetpr-camera-trim-\(UUID().uuidString).\(pathExtension)")
    try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
    return destinationURL
  }

  static func removeOriginal(_ originalURL: URL?, replacingWith replacementURL: URL) {
    guard let originalURL, originalURL.standardizedFileURL != replacementURL.standardizedFileURL
    else {
      return
    }
    try? FileManager.default.removeItem(at: originalURL)
  }
}

/// Single owner for the recorder review file. The controller may replace the
/// original with an edited file, relinquish it to upload, or tear it down;
/// every transition consumes the previous ownership exactly once.
struct RecorderReviewFileOwner {
  private(set) var url: URL?
  private(set) var ownsFile = false

  mutating func takeOwnership(of url: URL) {
    removeOwnedReviewFile()
    self.url = url
    ownsFile = true
  }

  mutating func replaceReviewFile(with editedURL: URL) {
    let originalURL = url
    url = editedURL
    ownsFile = true
    RecorderVideoTrimFiles.removeOriginal(originalURL, replacingWith: editedURL)
  }

  mutating func relinquishReviewFile() -> URL? {
    let relinquishedURL = url
    url = nil
    ownsFile = false
    return relinquishedURL
  }

  mutating func removeOwnedReviewFile() {
    if ownsFile, let url {
      try? FileManager.default.removeItem(at: url)
    }
    url = nil
    ownsFile = false
  }
}
