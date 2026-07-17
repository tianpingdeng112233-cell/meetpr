import Foundation
import Testing

@testable import StudentKit

private func makeTempMovieFile() throws -> URL {
  let url = FileManager.default.temporaryDirectory
    .appendingPathComponent("trim-completion-test-\(UUID().uuidString).mov")
  try Data("movie".utf8).write(to: url)
  return url
}

@Test func trimCompletionSaveDeliversEditedURLOnceAndRemovesSource() throws {
  let sourceURL = try makeTempMovieFile()
  let editedURL = try makeTempMovieFile()
  var outcomes: [VideoTrimCompletion.Outcome] = []
  let completion = VideoTrimCompletion(sourceURL: sourceURL) { outcomes.append($0) }

  completion.saved(editedVideoPath: editedURL.path)
  completion.saved(editedVideoPath: editedURL.path)

  #expect(outcomes == [.saved(editedURL)])
  #expect(!FileManager.default.fileExists(atPath: sourceURL.path))
  #expect(FileManager.default.fileExists(atPath: editedURL.path))
  try? FileManager.default.removeItem(at: editedURL)
}

@Test func trimCompletionSaveKeepsSourceWhenEditedInPlace() throws {
  let sourceURL = try makeTempMovieFile()
  var outcomes: [VideoTrimCompletion.Outcome] = []
  let completion = VideoTrimCompletion(sourceURL: sourceURL) { outcomes.append($0) }

  completion.saved(editedVideoPath: sourceURL.path)

  #expect(outcomes == [.saved(sourceURL)])
  #expect(FileManager.default.fileExists(atPath: sourceURL.path))
  try? FileManager.default.removeItem(at: sourceURL)
}

@Test func trimCompletionCancelRemovesSourceAndIgnoresLaterSave() throws {
  let sourceURL = try makeTempMovieFile()
  var outcomes: [VideoTrimCompletion.Outcome] = []
  let completion = VideoTrimCompletion(sourceURL: sourceURL) { outcomes.append($0) }

  completion.cancelled()
  completion.saved(editedVideoPath: sourceURL.path)

  #expect(outcomes == [.cancelled])
  #expect(!FileManager.default.fileExists(atPath: sourceURL.path))
}

@Test func trimCompletionFailureRemovesSourceAndReportsOnce() throws {
  let sourceURL = try makeTempMovieFile()
  var outcomes: [VideoTrimCompletion.Outcome] = []
  let completion = VideoTrimCompletion(sourceURL: sourceURL) { outcomes.append($0) }

  completion.failed()
  completion.failed()

  #expect(outcomes == [.failed])
  #expect(!FileManager.default.fileExists(atPath: sourceURL.path))
}

@Test func singleShotRunsBodyExactlyOnce() {
  let singleShot = SingleShot()
  var runCount = 0

  singleShot.run { runCount += 1 }
  singleShot.run { runCount += 1 }

  #expect(runCount == 1)
}
