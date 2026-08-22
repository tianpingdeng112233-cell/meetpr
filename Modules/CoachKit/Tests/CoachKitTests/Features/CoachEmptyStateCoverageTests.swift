import CoreModels
import Foundation
import RepositoryContracts
import SwiftUI
import Testing
import ViewInspector

@testable import CoachKit

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test("roster shows loading before empty and distinguishes search misses")
func rosterEmptyStatePriority() throws {
  #expect(
    StudentRosterContentState.resolve(
      loadState: .loading,
      hasStudents: false,
      hasSearchQuery: false
    ) == .loading
  )
  #expect(
    StudentRosterContentState.resolve(
      loadState: .loaded,
      hasStudents: false,
      hasSearchQuery: false
    ) == .emptyRoster
  )
  #expect(
    StudentRosterContentState.resolve(
      loadState: .loaded,
      hasStudents: false,
      hasSearchQuery: true
    ) == .noMatches
  )

  let inspected = try CoachRosterEmptyState(
    title: CoachRosterStrings.noStudents,
    description: CoachRosterStrings.noStudentsSubtitle,
    systemImage: "person.badge.plus"
  ).inspect()
  _ = try inspected.find(text: CoachRosterStrings.noStudents)
  _ = try inspected.find(text: CoachRosterStrings.noStudentsSubtitle)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test("receiving inbox never renders empty before its initial load finishes")
func receivingInboxLoadingPrecedesEmpty() {
  #expect(
    CoachReceivingContentState.resolve(
      videoState: .idle,
      hasChatError: false,
      rowsAreEmpty: true
    ) == .loading
  )
  #expect(
    CoachReceivingContentState.resolve(
      videoState: .loading,
      hasChatError: false,
      rowsAreEmpty: true
    ) == .loading
  )
  #expect(
    CoachReceivingContentState.resolve(
      videoState: .loaded,
      hasChatError: false,
      rowsAreEmpty: true
    ) == .empty
  )
  #expect(
    CoachReceivingContentState.resolve(
      videoState: .failed,
      hasChatError: false,
      rowsAreEmpty: true
    ) == .failed
  )
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test("video set information distinguishes unlinked videos from load failures")
func videoSetInformationStatesAreVisible() async throws {
  let unlinkedItem = VideoInboxFixtures.item()
  let unlinkedQueue = await loadedQueue(for: unlinkedItem)
  let unlinkedModel = VideoFeedbackDetailModel(item: unlinkedItem)
  await unlinkedModel.prepare(
    videoQueue: unlinkedQueue,
    trainingLogs: EmptyStudentTrainingLogRepository()
  )
  #expect(unlinkedModel.setInfoState == .unlinked)

  let linkedItem = VideoInboxFixtures.item(setLogID: UUID(), planExerciseID: UUID())
  let linkedQueue = await loadedQueue(for: linkedItem)
  let missingLogModel = VideoFeedbackDetailModel(item: linkedItem)
  await missingLogModel.prepare(
    videoQueue: linkedQueue,
    trainingLogs: EmptyStudentTrainingLogRepository()
  )
  #expect(missingLogModel.setInfoState == .failed)

  let failedModel = VideoFeedbackDetailModel(item: linkedItem)
  await failedModel.prepare(
    videoQueue: linkedQueue,
    trainingLogs: FailingSetInfoTrainingLogRepository()
  )
  #expect(failedModel.setInfoState == .failed)

  let inspected = try VideoSetInfoStatusView(state: .failed).inspect()
  _ = try inspected.find(text: CoachVideoFeedbackStrings.setInfoLoadFailed)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test("student detail replaces the zero-progress plan shell with guidance")
func studentDetailNoPlanState() throws {
  #expect(StudentPlanCardState.resolve(loadState: .loading, hasPlan: false) == .loading)
  #expect(StudentPlanCardState.resolve(loadState: .failed("error"), hasPlan: false) == .failed)
  #expect(StudentPlanCardState.resolve(loadState: .loaded, hasPlan: false) == .empty)

  let inspected = try StudentPlanStatusView(state: .empty).inspect()
  _ = try inspected.find(text: CoachDetailStrings.noPlan)
  _ = try inspected.find(text: CoachDetailStrings.noPlanSubtitle)
  #expect(throws: (any Error).self) {
    try inspected.find(text: CoachDetailStrings.weekProgress(completed: 0, total: 0))
  }
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test("dashboard with zero students shows invitation guidance")
func dashboardZeroStudentsState() throws {
  let inspected = try CoachTodayNoStudentsState().inspect()

  _ = try inspected.find(text: CoachTodayStrings.noStudents)
  _ = try inspected.find(text: CoachTodayStrings.noStudentsSubtitle)
  #expect(throws: (any Error).self) {
    try inspected.find(text: CoachTodayStrings.allDone)
  }
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test("planning step zero replaces empty student sections with guidance")
func planningStepZeroNoStudentsState() throws {
  let inspected = try PlanningNoStudentsState().inspect()

  _ = try inspected.find(text: CoachPlanningStrings.noStudents)
  _ = try inspected.find(text: CoachPlanningStrings.noStudentsSubtitle)
  #expect(throws: (any Error).self) {
    try inspected.find(text: "\(CoachPlanningStrings.active) (0)".uppercased())
  }
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test("single-student video list renders loading, failure, and empty distinctly")
func studentPendingVideosStatePriority() {
  #expect(
    StudentPendingVideosContentState.resolve(
      loadState: .loading,
      sectionsAreEmpty: true
    ) == .loading
  )
  #expect(
    StudentPendingVideosContentState.resolve(
      loadState: .failed,
      sectionsAreEmpty: true
    ) == .failed
  )
  #expect(
    StudentPendingVideosContentState.resolve(
      loadState: .loaded,
      sectionsAreEmpty: true
    ) == .empty
  )
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
private func loadedQueue(for item: PendingVideoItem) async -> CoachVideoQueueViewModel {
  let queue = CoachVideoQueueViewModel(
    repository: InMemoryCoachVideoQueueRepository(
      seed: [item],
      playbackURLs: [item.id: URL(fileURLWithPath: "/tmp/video.mp4")]
    )
  )
  await queue.loadIfNeeded()
  return queue
}

private struct FailingSetInfoTrainingLogRepository: StudentTrainingLogRepository {
  func recordSet(_ log: StudentSetLog) async throws -> StudentSetLog {
    throw CoachFeatureTestError()
  }

  func fetchLogs(
    studentID: UUID,
    in dateRange: ClosedRange<Date>
  ) async throws -> [StudentSetLog] {
    throw CoachFeatureTestError()
  }

  func fetchLogsForExercise(
    studentID: UUID,
    planExerciseID: UUID
  ) async throws -> [StudentSetLog] {
    throw CoachFeatureTestError()
  }
}
