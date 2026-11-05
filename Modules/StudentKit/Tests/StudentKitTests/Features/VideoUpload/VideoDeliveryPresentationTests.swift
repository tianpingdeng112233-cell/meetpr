import CoreModels
import Foundation
import Testing

@testable import StudentKit

@Suite("Video delivery failure presentation")
struct VideoDeliveryPresentationTests {
  @Test("first failure stays visible through backoff and retry until delivery")
  func firstFailureIsVisibleUntilDelivered() {
    let date = Date(timeIntervalSince1970: 1_794_000_000)
    var video = VideoAttachment(
      id: UUID(), setLogID: UUID(), studentID: UUID(), status: .pending,
      contentType: "video/mp4", durationSeconds: 30, sizeBytes: 100, recordedAt: date)
    #expect(!VideoDeliveryPresentation.hasFailure(video))
    video.firstUploadFailureAt = date
    #expect(VideoDeliveryPresentation.hasFailure(video))
    video.status = .uploading
    #expect(VideoDeliveryPresentation.hasFailure(video))
    video.status = .uploaded
    #expect(!VideoDeliveryPresentation.hasFailure(video))
    video.status = .pending
    video.firstUploadFailureAt = nil
    video.pendingDraftID = UUID()
    #expect(VideoDeliveryPresentation.hasFailure(video))
  }
  @Test @MainActor func dayAndExerciseFailuresShareTheSameProjection() throws {
    let day = try #require(StudentDemoSeed.makePlanView().days.first)
    var drafts = TodayWorkoutViewModel.makeDrafts(for: day, existingLogs: [])
    drafts[0].loggedSetID = UUID()
    let failed = VideoAttachment(
      id: UUID(), setLogID: try #require(drafts[0].loggedSetID), studentID: UUID(),
      status: .uploading,
      contentType: "video/mp4", durationSeconds: 30, sizeBytes: 100,
      recordedAt: day.scheduledDate, firstUploadFailureAt: day.scheduledDate)
    let pending = VideoAttachment(
      id: UUID(), setLogID: UUID(), studentID: failed.studentID, status: .failed,
      contentType: "video/mp4", durationSeconds: 30, sizeBytes: 100,
      recordedAt: day.scheduledDate, pendingDraftID: drafts[1].id,
      pendingSetSlot: drafts[1].pendingVideoSlot)
    let projection = VideoDeliveryPresentation(
      drafts: drafts, trainingDate: day.scheduledDate, attachments: [failed, pending])
    #expect(projection.failureCount == 2)
    #expect(projection.failedDraftIDs == [drafts[0].id, drafts[1].id])
    let presentation = TodayWorkoutPresentation(
      day: day, drafts: drafts, references: [:], started: true)
    let completed = CompletedDayPresentation(
      presentation: presentation, addedDrafts: [], unit: .kg, local: [failed, pending])
    #expect(completed.exercises[0].rows[0].videoFailed)
    #expect(completed.exercises[0].rows[1].videoFailed)
    #expect(!completed.exercises[0].rows[2].videoFailed)
  }

}
