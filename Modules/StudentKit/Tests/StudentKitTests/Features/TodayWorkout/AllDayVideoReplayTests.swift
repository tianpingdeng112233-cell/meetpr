import CoreModels
import DesignSystem
import Foundation
import SwiftUI
import Testing
import ViewInspector

@testable import StudentKit

@MainActor
struct AllDayVideoReplayTests {
  @Test func completedSetRowRetainsItsVideoControl() throws {
    let day = StudentAddedTestPlan.unsettledDemo().days[0]
    let draft = try #require(TodayWorkoutViewModel.makeDrafts(for: day, existingLogs: []).first)
    let row = AllDaySetRow(draft: draft, viewModel: nil, editable: false, onVideo: {})
    let video = try row.inspect().find(AllDaySetVideoButton.self).actualView()
    #expect(!video.editable)
    #expect(video.draft.id == draft.id)
  }

  @Test func completedExerciseKeepsDeliveredVideoAndOpensReadOnlyReplay() async throws {
    let day = StudentAddedTestPlan.unsettledDemo().days[0]
    var draft = try #require(TodayWorkoutViewModel.makeDrafts(for: day, existingLogs: []).first)
    draft.loggedSetID = UUID()
    draft.completed = true
    let video = StudentVideo(
      id: UUID(), setLogID: draft.loggedSetID, planExerciseID: nil,
      contentType: "video/mp4", sizeBytes: 100, filename: nil, createdAt: .now, loggedAt: nil)
    let harness = VideoUploadHarness()
    let replay = CompletedVideoReplayModel(
      services: VideoUploadServices(
        manager: harness.manager, replayRepository: ReplayRepository(videos: [video])),
      feedback: nil)
    await replay.load(studentID: StudentDemoSeed.studentID)
    var editingOpened = false
    let view = AllDaySetVideoButton(
      draft: draft, trainingDate: day.scheduledDate, editable: false, uploads: nil,
      replay: replay, onEditVideo: { editingOpened = true })
    let button = try view.inspect().find(
      viewWithAccessibilityIdentifier: "allDay.camera.\(draft.id)"
    ).button()
    #expect(
      try button.labelView().find(ViewType.Image.self).foregroundStyleShapeStyle(Color.self)
        == Color.MeetPR.success)
    try button.tap()
    #expect(replay.selected?.video == .remote(video.id))
    #expect(!editingOpened)
    #expect(replay.selected?.badge.exerciseName == draft.displayExerciseName)
  }

  @Test func uploadingTurnsFromYellowToGreenAndSurvivesDayCompletion() async throws {
    let day = StudentAddedTestPlan.unsettledDemo().days[0]
    var draft = try #require(TodayWorkoutViewModel.makeDrafts(for: day, existingLogs: []).first)
    let setID = UUID()
    draft.loggedSetID = setID
    let harness = VideoUploadHarness()
    await harness.service.setPartDelay(.milliseconds(250))
    let uploads = VideoAttachmentViewModel(manager: harness.manager)
    let replay = CompletedVideoReplayModel(
      services: VideoUploadServices(manager: harness.manager), feedback: nil)
    await replay.load(studentID: StudentDemoSeed.studentID)
    await uploads.start(studentID: StudentDemoSeed.studentID)
    await uploads.attach(
      sourceURL: harness.sourceURL, setLogID: setID, studentID: StudentDemoSeed.studentID)
    try await waitUntilOnMain { uploads.rowStates[setID]?.attachment.status == .uploading }
    var editingOpened = false
    let editable = AllDaySetVideoButton(
      draft: draft, trainingDate: day.scheduledDate, editable: true, uploads: uploads,
      replay: replay, onEditVideo: { editingOpened = true })
    #expect(try color(of: editable) == Color.MeetPR.gold500)
    try await waitUntilOnMain { uploads.rowStates[setID]?.attachment.status == .uploaded }
    #expect(try color(of: editable) == Color.MeetPR.success)
    try editable.inspect().find(ViewType.Button.self).tap()
    #expect(editingOpened)
    let completed = AllDaySetVideoButton(
      draft: draft, trainingDate: day.scheduledDate, editable: false, uploads: uploads,
      replay: replay, onEditVideo: { Issue.record("Completed video opened the editor") })
    #expect(try color(of: completed) == Color.MeetPR.success)
    try completed.inspect().find(ViewType.Button.self).tap()
    let attachment = try #require(uploads.rowStates[setID]?.attachment)
    #expect(replay.selected?.video == .local(attachment.id))
    let source = try await replay.source(for: .local(attachment.id))
    if case .local(let url) = source {
      #expect(FileManager.default.fileExists(atPath: url.path))
    } else {
      Issue.record("Expected the retained local video to remain playable")
    }
  }

  @Test func completedSetWithoutVideoDoesNotOfferRecording() throws {
    let day = StudentAddedTestPlan.unsettledDemo().days[0]
    let draft = try #require(TodayWorkoutViewModel.makeDrafts(for: day, existingLogs: []).first)
    let view = AllDaySetVideoButton(
      draft: draft, trainingDate: day.scheduledDate, editable: false, uploads: nil,
      replay: nil, onEditVideo: {})
    #expect(try view.inspect().findAll(ViewType.Button.self).isEmpty)
  }

  @Test func newerServerVideoPlaysInsteadOfOpeningAnOlderLocalAttachment() async throws {
    let day = StudentAddedTestPlan.unsettledDemo().days[0]
    var draft = try #require(TodayWorkoutViewModel.makeDrafts(for: day, existingLogs: []).first)
    let setID = UUID()
    draft.loggedSetID = setID
    let harness = VideoUploadHarness()
    try await harness.repository.save(
      VideoAttachment(
        id: UUID(), setLogID: setID, studentID: StudentDemoSeed.studentID,
        status: .failed, contentType: "video/mp4", durationSeconds: 5, sizeBytes: 100,
        recordedAt: Date(timeIntervalSince1970: 10)))
    let video = StudentVideo(
      id: UUID(), setLogID: setID, planExerciseID: nil, contentType: "video/mp4",
      sizeBytes: 100, filename: nil, createdAt: Date(timeIntervalSince1970: 20), loggedAt: nil)
    let replay = CompletedVideoReplayModel(
      services: VideoUploadServices(
        manager: harness.manager, replayRepository: ReplayRepository(videos: [video])),
      feedback: nil)
    await replay.load(studentID: StudentDemoSeed.studentID)
    let view = AllDaySetVideoButton(
      draft: draft, trainingDate: day.scheduledDate, editable: true, uploads: nil,
      replay: replay, onEditVideo: { Issue.record("Opened the obsolete local video") })
    #expect(try color(of: view) == Color.MeetPR.success)
    try view.inspect().find(ViewType.Button.self).tap()
    #expect(replay.selected?.video == .remote(video.id))
  }

  private func color(of view: AllDaySetVideoButton) throws -> Color {
    try view.inspect().find(ViewType.Image.self).foregroundStyleShapeStyle(Color.self)
  }

}

private struct ReplayRepository: StudentReplayVideoRepository {
  let videos: [StudentVideo]
  func fetchVideos(studentID: UUID) async throws -> [StudentVideo] { videos }
  func playbackURL(videoID: UUID) async throws -> URL {
    URL(fileURLWithPath: "/unused-test-video.mp4")
  }
}
