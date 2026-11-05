import CoreModels
import Foundation
import Networking
import RepositoryContracts
import Testing

@testable import StudentKit

@MainActor
struct CameraPersistenceFixture {
  let studentID = UUID()
  let now = Date(timeIntervalSince1970: 1_793_448_000)
  let otherDay: StudentPlanDay
  let day: StudentPlanDay
  let logs = CameraCanonicalLogs()
  let plans: InMemoryStudentPlanRepository
  let workout: TodayWorkoutViewModel

  init(setCount: Int = 3) {
    let exercise = Exercise(
      id: UUID(), name: "Bench", exerciseType: .mainLift, isCompetitionLift: true,
      muscleGroups: [], equipment: [], createdAt: now)
    let sets = (0..<setCount).map {
      PrescribedSet(id: UUID(), setIndex: $0, weightKg: 75, loadMode: .freeWeight, reps: 3)
    }
    day = StudentPlanDay(
      id: UUID(), date: now,
      exercises: [
        StudentPlanExercise(id: UUID(), exercise: exercise, sequenceIndex: 0, prescribedSets: sets)
      ])
    otherDay = StudentPlanDay(id: UUID(), date: now.addingTimeInterval(-86_400), exercises: [])
    let plan = StudentPlanView(
      cycleID: UUID(), weekIndex: 1, startDate: otherDay.date, days: [otherDay, day])
    let fixedNow = now
    plans = InMemoryStudentPlanRepository(
      store: TestStudentPlanStore(seed: [studentID: plan]), now: { fixedNow })
    workout = TodayWorkoutViewModel(plans: plans, logs: logs, now: { fixedNow })
  }

  func load() async {
    await workout.load(dayID: day.id, studentID: studentID)
  }

  func rows(local: [VideoAttachment]) throws -> [CompletedDayPresentation.Row] {
    let currentDay = try #require(workout.planDays.first { $0.id == day.id })
    let drafts = try #require(workout.currentDrafts)
    let overview = CompletedDayPresentation(
      presentation: TodayWorkoutPresentation(
        day: currentDay, drafts: drafts, references: [:], started: true),
      addedDrafts: [], unit: .kg, local: local)
    return try #require(overview.exercises.first).rows
  }
}

/// Models the documented repository contract: the server owns canonical slot IDs.
actor CameraCanonicalLogs: StudentTrainingLogRepository {
  nonisolated let canonicalIDs = (0..<3).map { _ in UUID() }
  private(set) var submittedIDs: [Int: UUID] = [:]
  private let store = InMemoryStudentTrainingLogRepository()
  private var offline = false
  func setOffline(_ value: Bool) { offline = value }
  private var shouldPauseWrite = false
  private var writeContinuation: CheckedContinuation<Void, Never>?
  var isWritePaused: Bool { writeContinuation != nil }

  func pauseNextWrite() { shouldPauseWrite = true }
  func releaseWrite() {
    writeContinuation?.resume()
    writeContinuation = nil
  }

  func recordSet(_ log: StudentSetLog) async throws -> StudentSetLog {
    if submittedIDs[log.setIndex] == nil { submittedIDs[log.setIndex] = log.id }
    if shouldPauseWrite {
      shouldPauseWrite = false
      await withCheckedContinuation { writeContinuation = $0 }
    }
    if offline { throw URLError(.notConnectedToInternet) }
    return try await store.recordSet(
      StudentSetLog(
        id: canonicalIDs[log.setIndex], studentID: log.studentID,
        planExerciseID: log.planExerciseID, exerciseID: log.exerciseID, setIndex: log.setIndex,
        loggedAt: log.loggedAt, loggedDate: log.loggedDate, weightKg: log.weightKg,
        reps: log.reps, rpe: log.rpe, actualRIR: log.actualRIR,
        completed: log.completed, failed: log.failed))
  }

  func fetchLogs(studentID: UUID, in dateRange: ClosedRange<Date>) async throws -> [StudentSetLog] {
    try await store.fetchLogs(studentID: studentID, in: dateRange)
  }

  func fetchLogsForExercise(studentID: UUID, planExerciseID: UUID) async throws -> [StudentSetLog] {
    try await store.fetchLogsForExercise(studentID: studentID, planExerciseID: planExerciseID)
  }
}

struct CameraPendingDiskHarness {
  let root: URL

  init() {
    root = FileManager.default.temporaryDirectory.appending(path: "pending-camera-\(UUID())")
  }

  func repository() -> BackendVideoAttachmentRepository {
    let api = APIClient(environment: ["MEETPR_API_BASE_URL": "https://camera-test.invalid"]) { _ in
      throw URLError(.notConnectedToInternet)
    }
    return BackendVideoAttachmentRepository(
      api: api, session: CameraNoSession(), directory: root.appending(path: "records"))
  }

  func manager(repository: BackendVideoAttachmentRepository, now: Date) -> VideoUploadManager {
    VideoUploadManager(
      service: MockVideoUploadService(), exporter: MockVideoExporter(), repository: repository,
      configuration: VideoUploadHarness.testConfiguration(),
      filesDirectory: root.appending(path: "files"), now: { now })
  }
}

private struct CameraNoSession: SessionStateReader {
  func accessToken() async throws -> String { throw URLError(.userAuthenticationRequired) }
  func currentUser() async throws -> User { throw SessionStateReaderError.missingCurrentUser }
}
