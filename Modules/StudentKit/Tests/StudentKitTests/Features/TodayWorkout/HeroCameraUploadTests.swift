import CoreModels
import Foundation
import Testing

@testable import StudentKit

/// Exercises the public calls made by TodayWorkoutView.attachDirectCameraVideo:
/// resolve the live row, mint an incomplete log, then hand the clip to the uploader.
@MainActor
@Test(arguments: [false, true])
func heroCameraFirstUploadDoesNotRequireEntryPrefill(editsArriveDuringCapture: Bool) async throws {
  let now = Date(timeIntervalSince1970: 1_768_262_400)
  let studentID = StudentDemoSeed.studentID
  let exercise = Exercise(
    id: UUID(), name: "Squat", exerciseType: .mainLift, isCompetitionLift: true,
    muscleGroups: [], equipment: [], createdAt: now)
  let prescribed = PrescribedSet(id: UUID(), setIndex: 0, loadMode: .freeWeight, reps: nil)
  let planExercise = StudentPlanExercise(
    id: UUID(), exercise: exercise, sequenceIndex: 0, prescribedSets: [prescribed])
  let day = StudentPlanDay(id: UUID(), date: now, exercises: [planExercise])
  let plan = StudentPlanView(cycleID: UUID(), weekIndex: 1, startDate: now, days: [day])
  let logs = InMemoryStudentTrainingLogRepository()
  let workout = TodayWorkoutViewModel(
    plans: InMemoryStudentPlanRepository(store: TestStudentPlanStore(seed: [studentID: plan])),
    logs: logs, now: { now })
  await workout.load(dayID: day.id, studentID: studentID)
  let target = try #require(workout.currentDrafts?.first)
  #expect(target.loggedSetID == nil && target.actualWeight == nil && target.actualReps == nil)
  #expect(SetVideoButtonDestination.resolve(for: nil, cameraAvailable: true) == .camera)

  // The camera captures a stable set ID, not a snapshot of editor text.
  if editsArriveDuringCapture {
    workout.updateWeight(rowIndex: 0, weight: 82.5)
    workout.updateReps(rowIndex: 0, reps: 5)
  }
  let rowIndex = try #require(workout.currentDrafts?.firstIndex { $0.id == target.id })
  let setLogID = try #require(await workout.ensureLoggedSetID(rowIndex: rowIndex))
  #expect(workout.actionErrorMessage == nil)
  let saved = try #require(
    try await logs.fetchLogsForExercise(studentID: studentID, planExerciseID: planExercise.id).first
  )
  #expect(saved.id == setLogID && !saved.completed)
  #expect(saved.weightKg == (editsArriveDuringCapture ? 82.5 : 0))
  #expect(saved.reps == (editsArriveDuringCapture ? 5 : 0))

  let harness = VideoUploadHarness()
  defer { try? FileManager.default.removeItem(at: harness.filesDirectory) }
  let suiteName = "hero-camera-upload-\(UUID().uuidString)"
  let defaults = try #require(UserDefaults(suiteName: suiteName))
  defer { defaults.removePersistentDomain(forName: suiteName) }
  let video = VideoAttachmentViewModel(manager: harness.manager, consentDefaults: defaults)
  await video.start(studentID: studentID)
  await video.attach(
    sourceURL: harness.sourceURL, setLogID: setLogID, studentID: studentID, trainingDate: now)
  try await waitUntilOnMain {
    let status = video.rowStates[setLogID]?.attachment.status
    return status == .uploaded || status == .failed
  }
  #expect(video.rowStates[setLogID]?.attachment.status == .uploaded)
  #expect(video.lastErrorMessage == nil)
  #expect(await harness.service.partAttempts == [1: 1, 2: 1, 3: 1])
  #expect(workout.currentDrafts?.first?.completed == false)
}
