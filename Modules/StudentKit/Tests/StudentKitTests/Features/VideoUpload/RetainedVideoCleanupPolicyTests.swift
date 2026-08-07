import CoreModels
import Foundation
import Testing

@testable import StudentKit

@Suite("Retained set-video cleanup")
struct RetainedVideoCleanupPolicyTests {
  private let now = Date(timeIntervalSince1970: 1_785_974_400)

  @Test("today's uploaded video is retained")
  func retainsToday() {
    let file = makeFile(trainingDate: now, recordedAt: now, sizeBytes: 100)

    let removals = RetainedVideoCleanupPolicy.attachmentIDsToRemove(
      from: [file],
      now: now,
      calendar: utcCalendar
    )

    #expect(removals.isEmpty)
  }

  @Test("a previous-day uploaded video is removed")
  func removesPreviousDay() {
    let file = makeFile(
      trainingDate: now.addingTimeInterval(-86_400),
      recordedAt: now.addingTimeInterval(-86_400),
      sizeBytes: 100
    )

    let removals = RetainedVideoCleanupPolicy.attachmentIDsToRemove(
      from: [file],
      now: now,
      calendar: utcCalendar
    )

    #expect(removals == [file.attachmentID])
  }

  @Test("over-limit cleanup removes oldest uploaded files until within the limit")
  func removesOldestToMeetLimit() {
    let oldest = makeFile(
      trainingDate: now,
      recordedAt: now.addingTimeInterval(-300),
      sizeBytes: 200
    )
    let middle = makeFile(
      trainingDate: now,
      recordedAt: now.addingTimeInterval(-200),
      sizeBytes: 200
    )
    let newest = makeFile(
      trainingDate: now,
      recordedAt: now.addingTimeInterval(-100),
      sizeBytes: 200
    )

    let removals = RetainedVideoCleanupPolicy.attachmentIDsToRemove(
      from: [newest, oldest, middle],
      now: now,
      calendar: utcCalendar,
      byteLimit: 500
    )

    #expect(removals == [oldest.attachmentID])
  }

  @Test("cleanup never removes in-flight or failed files")
  func leavesUploadPipelineFilesAlone() {
    let files = [
      makeFile(status: .pending, trainingDate: now.addingTimeInterval(-86_400)),
      makeFile(status: .uploading, trainingDate: now.addingTimeInterval(-86_400)),
      makeFile(status: .failed, trainingDate: now.addingTimeInterval(-86_400)),
    ]

    let removals = RetainedVideoCleanupPolicy.attachmentIDsToRemove(
      from: files,
      now: now,
      calendar: utcCalendar,
      byteLimit: 0
    )

    #expect(removals.isEmpty)
  }

  @Test("device-local day handles midnight across a daylight-saving transition")
  func usesDeviceLocalDayAcrossDST() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))
    let localNoonAfterDSTJump = try Date("2026-03-08T19:00:00Z", strategy: .iso8601)
    let previousLocalDay = makeFile(
      trainingDate: try Date("2026-03-08T07:30:00Z", strategy: .iso8601)
    )
    let sameLocalDayAfterJump = makeFile(
      trainingDate: try Date("2026-03-08T10:30:00Z", strategy: .iso8601)
    )

    let removals = RetainedVideoCleanupPolicy.attachmentIDsToRemove(
      from: [previousLocalDay, sameLocalDayAfterJump],
      now: localNoonAfterDSTJump,
      calendar: calendar
    )

    #expect(removals == [previousLocalDay.attachmentID])
  }

  @Test("the 500 MB guardrail removes only when total bytes exceed the exact limit")
  func enforcesExactDefaultByteLimit() {
    let exactlyAtLimit = makeFile(
      trainingDate: now,
      recordedAt: now.addingTimeInterval(-1),
      sizeBytes: RetainedVideoCleanupPolicy.defaultByteLimit
    )
    let oneByteOver = makeFile(
      trainingDate: now,
      sizeBytes: RetainedVideoCleanupPolicy.defaultByteLimit + 1
    )

    let exactRemovals = RetainedVideoCleanupPolicy.attachmentIDsToRemove(
      from: [exactlyAtLimit],
      now: now,
      calendar: utcCalendar
    )
    let overRemovals = RetainedVideoCleanupPolicy.attachmentIDsToRemove(
      from: [oneByteOver],
      now: now,
      calendar: utcCalendar
    )

    #expect(exactRemovals.isEmpty)
    #expect(overRemovals == [oneByteOver.attachmentID])
  }

  private var utcCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
    return calendar
  }

  private func makeFile(
    status: VideoAttachment.Status = .uploaded,
    trainingDate: Date,
    recordedAt: Date? = nil,
    sizeBytes: Int64 = 100
  ) -> RetainedVideoFile {
    RetainedVideoFile(
      attachmentID: UUID(),
      status: status,
      trainingDate: trainingDate,
      recordedAt: recordedAt ?? trainingDate,
      sizeBytes: sizeBytes
    )
  }
}
