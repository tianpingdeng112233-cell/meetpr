import AVFoundation
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

@Test func recorderTrimWorkingCopyPreservesOriginalUntilEditIsAccepted() throws {
  let originalURL = try makeTempMovieFile()
  let workingURL = try RecorderVideoTrimFiles.makeWorkingCopy(of: originalURL)

  #expect(workingURL != originalURL)
  #expect(try Data(contentsOf: workingURL) == Data(contentsOf: originalURL))
  #expect(FileManager.default.fileExists(atPath: originalURL.path))

  try? FileManager.default.removeItem(at: workingURL)
  try? FileManager.default.removeItem(at: originalURL)
}

@Test func acceptingRecorderTrimRemovesOriginalAndKeepsEditedFile() throws {
  let originalURL = try makeTempMovieFile()
  let editedURL = try makeTempMovieFile()

  RecorderVideoTrimFiles.removeOriginal(originalURL, replacingWith: editedURL)

  #expect(!FileManager.default.fileExists(atPath: originalURL.path))
  #expect(FileManager.default.fileExists(atPath: editedURL.path))
  try? FileManager.default.removeItem(at: editedURL)
}

@Test func trimSuggestionHidesForCurrentSessionAfterCompletedTrim() {
  var state = RecorderTrimSuggestionState(isPermanentlyDisabled: false)

  #expect(state.shouldShow)
  state.completeTrim()

  #expect(!state.shouldShow)
  #expect(!state.isPermanentlyDisabled)
}

@Test func trimSuggestionPermanentDismissalPersists() throws {
  let suiteName = "RecorderTrimSuggestionPreferenceTests.\(UUID().uuidString)"
  let defaults = try #require(UserDefaults(suiteName: suiteName))
  defer { defaults.removePersistentDomain(forName: suiteName) }

  #expect(!RecorderTrimSuggestionPreference.isPermanentlyDisabled(in: defaults))
  RecorderTrimSuggestionPreference.disablePermanently(in: defaults)

  let reloadedDefaults = try #require(UserDefaults(suiteName: suiteName))
  #expect(RecorderTrimSuggestionPreference.isPermanentlyDisabled(in: reloadedDefaults))
  let state = RecorderTrimSuggestionState(
    isPermanentlyDisabled:
      RecorderTrimSuggestionPreference.isPermanentlyDisabled(in: reloadedDefaults)
  )
  #expect(!state.shouldShow)
}

@Test func trimSessionDismissalAndRecorderShutdownCleanBothOwnedFilesOnce() throws {
  let originalURL = try makeTempMovieFile()
  let workingURL = try RecorderVideoTrimFiles.makeWorkingCopy(of: originalURL)
  var outcomes: [VideoTrimCompletion.Outcome] = []
  let session = VideoTrimSession(
    sourceURL: workingURL,
    maxDurationSeconds: 120,
    onSave: { outcomes.append(.saved($0)) },
    onCancel: { outcomes.append(.cancelled) },
    onFailure: { outcomes.append(.failed) }
  )
  var owner = RecorderReviewFileOwner()
  owner.takeOwnership(of: originalURL)

  session.cancelled()
  session.cancelled()
  owner.removeOwnedReviewFile()
  owner.removeOwnedReviewFile()

  #expect(outcomes == [.cancelled])
  #expect(!FileManager.default.fileExists(atPath: workingURL.path))
  #expect(!FileManager.default.fileExists(atPath: originalURL.path))
}

@Test func realMediaTrimHandoffUsesEditedURLForEveryReviewConsumer() async throws {
  let fixture = try await VideoExportFixture.make(.init(frameCount: 30))
  defer { fixture.remove() }
  let workingURL = try RecorderVideoTrimFiles.makeWorkingCopy(of: fixture.sourceURL)
  let editedURL = fixture.directory.appending(path: "trimmed.mov")
  try FileManager.default.copyItem(at: fixture.sourceURL, to: editedURL)

  var appliedTrimURL: URL?
  let session = VideoTrimSession(
    sourceURL: workingURL,
    maxDurationSeconds: 120,
    onSave: { appliedTrimURL = $0 },
    onCancel: {},
    onFailure: {}
  )
  var owner = RecorderReviewFileOwner()
  owner.takeOwnership(of: fixture.sourceURL)

  session.saved(editedVideoPath: editedURL.path)
  let acceptedURL = try #require(appliedTrimURL)
  owner.replaceReviewFile(with: acceptedURL)

  let playbackURL = try #require(owner.url)
  let photoLibrarySaveURL = playbackURL
  let relinquishedURL = owner.relinquishReviewFile()
  let onPickedURL = try #require(relinquishedURL)
  let duration = try await AVURLAsset(url: playbackURL).load(.duration)
  let videoTracks = try await AVURLAsset(url: playbackURL).loadTracks(withMediaType: .video)

  #expect(playbackURL == editedURL)
  #expect(photoLibrarySaveURL == editedURL)
  #expect(onPickedURL == editedURL)
  #expect(duration.seconds > 0)
  #expect(!videoTracks.isEmpty)
  #expect(!FileManager.default.fileExists(atPath: workingURL.path))
  #expect(!FileManager.default.fileExists(atPath: fixture.sourceURL.path))
  #expect(FileManager.default.fileExists(atPath: editedURL.path))
}
