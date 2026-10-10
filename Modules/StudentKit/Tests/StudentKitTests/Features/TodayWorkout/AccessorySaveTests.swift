import CoreModels
import Foundation
import Networking
import RepositoryContracts
import Testing

@testable import StudentKit

@MainActor
@Test func accessorySaveCancelOverwriteAndVideoGuardUseNormalLogs() async throws {
  let logs = InMemoryStudentTrainingLogRepository()
  let fixture = try await accessoryFixture(logs: logs)
  let model = fixture.model
  let draft = try #require(model.currentDrafts?.first)
  #expect(await model.saveAccessoryRow(AccessoryRow(draft: draft, previous: nil, unit: .kg)))
  let saved = try #require(model.currentDrafts?.first)
  #expect(saved.completed)
  #expect(saved.actualRPE == nil)
  #expect(model.restTimer?.totalSeconds == 60)
  #expect(!model.showsRestTimerExplanation)
  let stored = try #require(
    try await logs.fetchLogsForExercise(
      studentID: StudentDemoSeed.studentID, planExerciseID: draft.planExerciseID
    ).first)
  let request = CreateSetLogRequestDTO(
    planExerciseID: stored.planExerciseID, setIndex: stored.setIndex, weightKg: stored.weightKg,
    reps: stored.reps, rpe: stored.rpe, completed: stored.completed, failed: stored.failed)
  let body = try #require(
    JSONSerialization.jsonObject(with: JSONEncoder().encode(request))
      as? [String: Any])
  #expect(body["rpe"] == nil)
  #expect(body["completed"] as? Bool == true)
  #expect(body["failed"] as? Bool == false)
  #expect(
    !(await model.saveAccessoryRow(
      AccessoryRow(draft: saved, previous: nil, unit: .kg, hasVideo: true))))
  #expect(model.currentDrafts?.first?.completed == true)
  #expect(model.actionErrorMessage != nil)
  #expect(await model.saveAccessoryRow(AccessoryRow(draft: saved, previous: nil, unit: .lb)))
  let canceled = try #require(
    try await logs.fetchLogsForExercise(
      studentID: StudentDemoSeed.studentID, planExerciseID: draft.planExerciseID
    ).first)
  #expect(!canceled.completed && !canceled.failed)
  #expect(canceled.weightKg == 60 && canceled.reps == 12)
  var retry = AccessoryRow(
    draft: try #require(model.currentDrafts?.first), previous: nil, unit: .kg)
  retry.input = AccessoryInput(weight: "65", reps: "10", rpe: "7.5")
  #expect(await model.saveAccessoryRow(retry))
  var overwrite = AccessoryRow(
    draft: try #require(model.currentDrafts?.first), previous: nil, unit: .kg, hasVideo: true)
  overwrite.input.weight = "70"
  #expect(await model.saveAccessoryRow(overwrite))
  let updated = try #require(
    try await logs.fetchLogsForExercise(
      studentID: StudentDemoSeed.studentID, planExerciseID: draft.planExerciseID
    ).first)
  #expect(updated.completed && updated.weightKg == 70 && updated.rpe == 7.5)
  #expect(updated.id == stored.id)
}

@MainActor
func accessoryFixture(
  logs: any StudentTrainingLogRepository, coachRest: Int? = nil, accessoryRest: Int = 60,
  includeFollowingMainLift: Bool = false,
  activity: any RestTimerActivityControlling = NoOpRestTimerActivityController()
) async throws -> (
  model: TodayWorkoutViewModel, day: StudentPlanDay
) {
  let now = Date(timeIntervalSince1970: 1_768_262_400)
  let exercise = Exercise(
    id: UUID(), name: "Row", exerciseType: .accessory,
    isCompetitionLift: false, muscleGroups: [], equipment: [], createdAt: now)
  let planExercise = StudentPlanExercise(
    id: UUID(), exercise: exercise, sequenceIndex: 0,
    prescribedSets: (0..<3).map {
      PrescribedSet(
        id: UUID(), setIndex: $0, weightKg: 60, reps: 12, rpe: 8, restSeconds: coachRest)
    })
  let following = includeFollowingMainLift ? StudentDemoSeed.makePlanView().days[0].exercises : []
  let day = StudentPlanDay(id: UUID(), date: now, exercises: [planExercise] + following)
  let plan = StudentPlanView(cycleID: UUID(), weekIndex: 1, startDate: now, days: [day])
  let defaults = try #require(UserDefaults(suiteName: "spec089.\(UUID().uuidString)"))
  UserDefaultsRestTimerSettingsStore(defaults: defaults).setAccessorySeconds(
    accessoryRest, for: StudentDemoSeed.studentID)
  let model = TodayWorkoutViewModel(
    plans: InMemoryStudentPlanRepository(
      store: TestStudentPlanStore(seed: [StudentDemoSeed.studentID: plan])),
    logs: logs, restTimerSettings: UserDefaultsRestTimerSettingsStore(defaults: defaults),
    restTimerActivityController: activity,
    now: { now })
  await model.load(dayID: day.id, studentID: StudentDemoSeed.studentID)
  model.accessoryVideosLoaded = true
  return (model, day)
}

@MainActor
@Test func accessoryBatchKeepsSuccessfulRowsAndRetriesWithoutRest() async throws {
  let logs = FailOnceTrainingLogRepository(failingAttempt: 2)
  let fixture = try await accessoryFixture(logs: logs)
  let model = fixture.model
  var rows = try #require(model.currentDrafts).map {
    AccessoryRow(draft: $0, previous: nil, unit: .kg)
  }
  rows[2].input.weight = ""
  let result = await model.completeAccessoryRows(rows)
  #expect(result.written == 1 && result.skipped == 1 && result.failed)
  #expect(await logs.storedLogs().count == 1)
  #expect(model.restTimer == nil)
  #expect(model.actionErrorMessage != nil)
  rows = try #require(model.currentDrafts).map {
    AccessoryRow(draft: $0, previous: nil, unit: .kg)
  }
  let retry = await model.completeAccessoryRows(rows)
  #expect(retry.written == 2 && retry.skipped == 0 && !retry.failed)
  #expect(await logs.storedLogs().count == 3)
  #expect(model.currentDrafts?.allSatisfy(\.completed) == true)
  #expect(model.restTimer == nil)
}

@MainActor
@Test func accessoryRestHonorsPreferenceAndCoachAndStopsAtExerciseBoundary() async throws {
  let custom = try await accessoryFixture(
    logs: InMemoryStudentTrainingLogRepository(), accessoryRest: 90)
  let first = try #require(custom.model.currentDrafts?.first)
  #expect(await custom.model.saveAccessoryRow(AccessoryRow(draft: first, previous: nil, unit: .kg)))
  #expect(custom.model.restTimer?.totalSeconds == 90)
  let coach = try await accessoryFixture(
    logs: InMemoryStudentTrainingLogRepository(), coachRest: 75,
    accessoryRest: 90, includeFollowingMainLift: true)
  for index in [2, 0, 1] {
    let draft = try #require(coach.model.currentDrafts?[index])
    #expect(
      await coach.model.saveAccessoryRow(AccessoryRow(draft: draft, previous: nil, unit: .kg)))
    if index != 1 { #expect(coach.model.restTimer?.totalSeconds == 75) }
  }
  #expect(coach.model.restTimer == nil)
  #expect(coach.model.currentDrafts?.contains { !$0.completed } == true)
  #expect(!coach.model.showsRestTimerExplanation)
}

@MainActor
@Test func accessoryUneditedPoundsPreservesPrescriptionAndWaitsForVideoHydration() async throws {
  let logs = InMemoryStudentTrainingLogRepository()
  let fixture = try await accessoryFixture(logs: logs)
  let model = fixture.model
  let first = try #require(model.currentDrafts?.first)
  #expect(await model.saveAccessoryRow(AccessoryRow(draft: first, previous: nil, unit: .lb)))
  #expect(model.currentDrafts?.first?.actualWeight == 60)
  let saved = try #require(model.currentDrafts?.first)
  model.accessoryVideosLoaded = false
  #expect(!(await model.saveAccessoryRow(AccessoryRow(draft: saved, previous: nil, unit: .lb))))
  #expect(model.currentDrafts?.first?.completed == true)
  #expect(model.actionErrorMessage == StudentStrings.localized(.dashboardView004))
  model.accessoryVideosLoaded = true
  #expect(await model.saveAccessoryRow(AccessoryRow(draft: saved, previous: nil, unit: .lb)))
  #expect(model.currentDrafts?.first?.completed == false)
}

@MainActor
@Test func accessoryOverwriteRestMatchesLiveActivity() async throws {
  let activity = AccessoryActivitySpy()
  let fixture = try await accessoryFixture(
    logs: InMemoryStudentTrainingLogRepository(), coachRest: 75, accessoryRest: 90,
    activity: activity)
  let model = fixture.model
  let first = try #require(model.currentDrafts?.first)
  #expect(await model.saveAccessoryRow(AccessoryRow(draft: first, previous: nil, unit: .kg)))
  #expect(activity.seconds == model.restTimer?.totalSeconds)
  #expect(activity.endsAt == model.restTimer?.endsAt)
  #expect(activity.seconds == 75)
  model.skipRestTimer()
  var edited = AccessoryRow(
    draft: try #require(model.currentDrafts?.first), previous: nil, unit: .kg)
  edited.input.reps = "11"
  #expect(await model.saveAccessoryRow(edited))
  #expect(model.restTimer?.totalSeconds == 75)
  #expect(activity.seconds == model.restTimer?.totalSeconds)
  #expect(activity.endsAt == model.restTimer?.endsAt)
  let pending = try #require(model.currentDrafts).map {
    AccessoryRow(draft: $0, previous: nil, unit: .kg)
  }
  model.skipRestTimer()
  #expect(await model.completeAccessoryRows(pending).written == 2)
  #expect(model.restTimer == nil && activity.seconds == nil)
}

@MainActor
private final class AccessoryActivitySpy: RestTimerActivityControlling {
  var seconds: Int?
  var endsAt: Date?
  func start(endsAt: Date, totalSeconds: Int) {
    self.endsAt = endsAt
    seconds = totalSeconds
  }
  func update(endsAt: Date, totalSeconds: Int) {
    self.endsAt = endsAt
    seconds = totalSeconds
  }
  func end() {
    seconds = nil
    endsAt = nil
  }
}

@MainActor
@Test func accessoryFinalPendingSetDoesNotRestWhenAnotherSetFailed() async throws {
  let fixture = try await accessoryFixture(logs: InMemoryStudentTrainingLogRepository())
  let model = fixture.model
  #expect(await model.commitSet(rowIndex: 0, failed: true))
  for index in [1, 2] {
    let row = AccessoryRow(
      draft: try #require(model.currentDrafts?[index]), previous: nil, unit: .kg)
    #expect(await model.saveAccessoryRow(row))
  }
  #expect(model.restTimer == nil)
}

@MainActor
@Test func accessoryCancellationRequiresSuccessfulAttachmentSnapshot() async {
  let harness = VideoUploadHarness()
  let loaded = VideoAttachmentViewModel(manager: harness.manager)
  #expect(!loaded.hasLoadedAttachments)
  await loaded.start(studentID: UUID())
  #expect(loaded.hasLoadedAttachments)
  let unavailable = VideoAttachmentViewModel(
    manager: VideoUploadManager(
      service: MockVideoUploadService(), exporter: MockVideoExporter(),
      repository: UnavailableAccessoryVideos()))
  await unavailable.start(studentID: UUID())
  #expect(!unavailable.hasLoadedAttachments)
}

private struct UnavailableAccessoryVideos: VideoAttachmentRepository {
  struct Failure: Error {}
  func fetchAll(studentID: UUID) async throws -> [VideoAttachment] { throw Failure() }
  func save(_ attachment: VideoAttachment) async throws {}
  func persistUploadedPart(
    _ part: VideoUploadedPart, recordID: UUID,
    expectedUploadGeneration: Int
  ) async throws -> VideoAttachment? { nil }
  func fetch(id: UUID) async throws -> VideoAttachment? { nil }
  func fetch(setLogID: UUID) async throws -> [VideoAttachment] { [] }
  func delete(id: UUID) async throws {}
  func playbackURL(for attachment: VideoAttachment) async throws -> URL? { nil }
}

@MainActor
@Test func accessoryReloadAndWeightOverwritePreserveEmptyRPE() async throws {
  let logs = InMemoryStudentTrainingLogRepository()
  let fixture = try await accessoryFixture(logs: logs)
  let model = fixture.model
  let first = try #require(model.currentDrafts?.first)
  #expect(first.actualRPE == 8)
  let unrecorded = AccessoryRow(draft: first, previous: nil, unit: .kg)
  #expect(unrecorded.input.rpe.isEmpty && unrecorded.rpePlaceholder == "8")
  #expect(await model.saveAccessoryRow(unrecorded))
  let logID = try #require(model.currentDrafts?.first?.loggedSetID)
  await model.load(dayID: fixture.day.id, studentID: StudentDemoSeed.studentID)
  let reloaded = try #require(model.currentDrafts?.first)
  #expect(reloaded.loggedSetID == logID && reloaded.actualRPE == nil)
  var row = AccessoryRow(draft: reloaded, previous: nil, unit: .kg)
  #expect(row.input.rpe.isEmpty)
  row.input.weight = "65"
  #expect(await model.saveAccessoryRow(row))
  let stored = try #require(
    try await logs.fetchLogsForExercise(
      studentID: StudentDemoSeed.studentID, planExerciseID: first.planExerciseID
    ).first)
  #expect(stored.id == logID && stored.weightKg == 65 && stored.rpe == nil)
}
