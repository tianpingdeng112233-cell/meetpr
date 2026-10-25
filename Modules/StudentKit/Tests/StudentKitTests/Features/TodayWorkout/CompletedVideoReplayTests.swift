import CoreModels
import Foundation
import Testing

@testable import StudentKit

@MainActor
struct CompletedVideoReplayTests {
  @Test func completedExerciseReservesVideoSpaceForItsRowsOnly() throws {
    let day = try #require(StudentDemoSeed.makePlanView().days.first)
    var drafts = TodayWorkoutViewModel.makeDrafts(for: day, existingLogs: [])
    let setLogID = UUID()
    drafts[0].loggedSetID = setLogID
    drafts[0].completed = true
    let presentation = TodayWorkoutPresentation(
      day: day, drafts: drafts, references: [:], started: true)
    let empty = CompletedDayPresentation(
      presentation: presentation, addedDrafts: [], unit: .kg)
    #expect(empty.exercises.allSatisfy { !$0.reservesVideoSpace })
    let withVideo = CompletedDayPresentation(
      presentation: presentation, addedDrafts: [], unit: .kg,
      videos: [video(setLogID: setLogID, at: 10)])
    #expect(try #require(withVideo.exercises.first).reservesVideoSpace)
    #expect(withVideo.exercises.dropFirst().allSatisfy { !$0.reservesVideoSpace })
    for status in [VideoAttachment.Status.pending, .uploading, .failed] {
      let upload = VideoAttachment(
        id: UUID(), setLogID: setLogID, studentID: UUID(), status: status,
        contentType: "video/mp4", durationSeconds: 8, sizeBytes: 100,
        localFileName: "clip.mp4", recordedAt: .now)
      let uploading = CompletedDayPresentation(
        presentation: presentation, addedDrafts: [], unit: .kg, local: [upload])
      let exercise = try #require(uploading.exercises.first)
      #expect(exercise.reservesVideoSpace)
      #expect(exercise.rows.allSatisfy { $0.video == nil })
      #expect(uploading.exercises.dropFirst().allSatisfy { !$0.reservesVideoSpace })
    }
  }

  @Test func completedRowsUseServerSetLogIDsAndNewestVideo() throws {
    let day = try #require(StudentDemoSeed.makePlanView().days.first)
    var drafts = TodayWorkoutViewModel.makeDrafts(for: day, existingLogs: [])
    drafts[0].completed = true
    let setLogID = UUID()
    drafts[0].loggedSetID = setLogID
    let older = video(setLogID: setLogID, at: 10)
    let latest = video(setLogID: setLogID, at: 20)
    let overview = CompletedDayPresentation(
      presentation: TodayWorkoutPresentation(
        day: day, drafts: drafts, references: [:], started: true),
      addedDrafts: [], unit: .kg, videos: [latest, older])
    let rows = try #require(overview.exercises.first).rows
    #expect(rows[0].video == .remote(latest.id))
    #expect(rows[1].video == nil)
  }

  @Test func unfinishedUploadSuppressesOlderServerVideoAndUploadedBecomesPlayable() {
    let setID = UUID()
    let server = video(setLogID: setID, at: 10)
    var local = VideoAttachment(
      id: UUID(), setLogID: setID, studentID: UUID(), status: .uploading,
      contentType: "video/mp4", durationSeconds: 8, sizeBytes: 100,
      localFileName: "clip.mp4", recordedAt: Date(timeIntervalSince1970: 20))
    for status in [VideoAttachment.Status.pending, .uploading, .failed] {
      local.status = status
      #expect(CompletedSetVideo.resolve(setLogID: setID, videos: [server], local: [local]) == nil)
    }
    local.status = .uploaded
    #expect(
      CompletedSetVideo.resolve(setLogID: setID, videos: [server], local: [local])
        == .local(local.id))
    let newerServer = video(setLogID: setID, at: 30)
    #expect(
      CompletedSetVideo.resolve(setLogID: setID, videos: [newerServer], local: [local])
        == .remote(newerServer.id))
  }

  @Test func reviewedMeansLatestFeedbackForExactVideoID() {
    let videoID = UUID()
    let older = feedback(videoID: videoID, at: 10)
    let latest = feedback(videoID: videoID, at: 30)
    let unrelated = feedback(videoID: UUID(), at: 40)
    #expect(
      CompletedSetVideo.latestFeedback(videoID: videoID, items: [latest, unrelated, older])?.id
        == latest.id)
    #expect(CompletedSetVideo.latestFeedback(videoID: videoID, items: [unrelated]) == nil)
    #expect(
      CompletedSetVideo.latestFeedback(videoID: nil, items: [feedback(videoID: nil, at: 50)]) == nil
    )
  }

  private func feedback(videoID: UUID?, at seconds: Double) -> CoachFeedback {
    CoachFeedback(
      id: UUID(), coachID: UUID(), studentID: UUID(), videoID: videoID,
      text: "Review", postedAt: Date(timeIntervalSince1970: seconds))
  }

  private func video(setLogID: UUID, at seconds: Double) -> StudentVideo {
    StudentVideo(
      id: UUID(), setLogID: setLogID, planExerciseID: nil, contentType: "video/mp4",
      sizeBytes: 100, filename: nil, createdAt: Date(timeIntervalSince1970: seconds), loggedAt: nil)
  }
}
