import CoreModels
import Foundation
import Testing

@testable import StudentKit

/// A recording held to the cap must still be uploadable. The recorder appends
/// the frame that first reaches `maxDurationSeconds` and only then asks the
/// session to stop, so the finished file runs a frame past the cap; `enqueue`
/// used to reject that outright, losing a take the app itself had capped.
@Test func enqueueAcceptsARecordingThatRanOneFramePastTheCap() async throws {
  let configuration = VideoUploadHarness.testConfiguration()
  // 120s cap + one frame at 30fps.
  let overshoot = configuration.maxDurationSeconds + 1.0 / 30.0
  let harness = VideoUploadHarness(exporter: MockVideoExporter(duration: overshoot))

  let record = try await harness.manager.enqueue(
    sourceURL: harness.sourceURL,
    setLogID: UUID(),
    studentID: UUID()
  )

  #expect(record.durationSeconds == overshoot)
}

/// Pinned just past the grace rather than far beyond it: a wildly-too-long
/// clip would also be refused by a grace that had silently grown, so only a
/// boundary case actually holds the window at half a second.
@Test func enqueueRejectsTheFirstClipPastTheGrace() async throws {
  let configuration = VideoUploadHarness.testConfiguration()
  let justPastGrace =
    configuration.maxDurationSeconds + VideoUploadManager.durationGraceSeconds + 0.001
  let harness = VideoUploadHarness(exporter: MockVideoExporter(duration: justPastGrace))

  await #expect(
    throws: VideoUploadError.durationExceedsLimit(
      seconds: justPastGrace,
      maxSeconds: configuration.maxDurationSeconds
    )
  ) {
    try await harness.manager.enqueue(
      sourceURL: harness.sourceURL,
      setLogID: UUID(),
      studentID: UUID()
    )
  }
}
