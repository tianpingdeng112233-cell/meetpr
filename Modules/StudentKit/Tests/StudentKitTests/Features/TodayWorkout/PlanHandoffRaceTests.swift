import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import StudentKit

@MainActor
@Test(arguments: [false, true])
func handoffLateResponseCannotReplaceEditedWorkout(browsing: Bool) async throws {
  let fixture = HandoffWorkoutFixture()
  let repository = DelayedHandoffRepository(current: fixture.current, next: fixture.upcoming)
  let model = TodayWorkoutViewModel(
    plans: repository, logs: InMemoryStudentTrainingLogRepository())
  await model.load(dayID: nil, studentID: StudentDemoSeed.studentID)
  let dayID = model.currentDay?.id
  await repository.pauseNextRead()
  let navigation = Task {
    if browsing {
      await model.browseAdjacentPlan(forward: true)
    } else {
      await model.enterTraining()
    }
  }
  await repository.waitUntilPaused()
  model.updateWeight(rowIndex: 0, weight: 123)
  await repository.resume()
  await navigation.value
  #expect(model.displayedPlan?.cycleID == fixture.current.cycleID)
  #expect(model.currentDay?.id == dayID)
  #expect(model.currentDrafts?.first?.actualWeight == 123)
  #expect(!model.isPreviewingPlan)
}

private actor DelayedHandoffRepository: StudentPlanRepository {
  let current: StudentPlanView
  let next: StudentPlanView
  private var shouldPause = false
  private var continuation: CheckedContinuation<Void, Never>?

  init(current: StudentPlanView, next: StudentPlanView) {
    self.current = current
    self.next = next
  }

  func fetchCurrentPlan(studentID: UUID) async throws -> StudentPlanView? {
    guard shouldPause else { return current }
    await pause()
    return next
  }

  func fetchCycleDays(studentID: UUID) async throws -> [StudentPlanDay] { current.days }

  func fetchPlan(id: UUID, studentID: UUID) async throws -> StudentPlanView? {
    if shouldPause { await pause() }
    return id == next.cycleID ? next : current
  }

  func pauseNextRead() { shouldPause = true }

  private func pause() async {
    shouldPause = false
    await withCheckedContinuation { continuation = $0 }
  }

  func waitUntilPaused() async {
    while continuation == nil { await Task.yield() }
  }

  func resume() {
    continuation?.resume()
    continuation = nil
  }
}

@MainActor
@Test(arguments: ["enter", "browse", "return"])
func handoffRechecksVisibleInteractionAfterPlanResponse(action: String) async throws {
  let fixture = HandoffWorkoutFixture()
  let repository = DelayedHandoffRepository(current: fixture.current, next: fixture.upcoming)
  let model = TodayWorkoutViewModel(
    plans: repository, logs: InMemoryStudentTrainingLogRepository())
  await model.load(dayID: nil, studentID: StudentDemoSeed.studentID)
  if action == "return" { await model.browseAdjacentPlan(forward: true) }
  let original = model.displayedPlan
  var safe = true
  await repository.pauseNextRead()
  let navigation = Task {
    switch action {
    case "enter": await model.enterTraining(isSafe: { safe })
    case "browse": await model.browseAdjacentPlan(forward: true, isSafe: { safe })
    default: await model.returnToCurrentPlan(isSafe: { safe })
    }
  }
  await repository.waitUntilPaused()
  safe = false  // The view now has an open keypad/camera or an active upload.
  await repository.resume()
  await navigation.value
  #expect(model.displayedPlan == original)
}

@MainActor
@Test func handoffRechecksVisibleInteractionAfterLogResponse() async throws {
  let fixture = HandoffWorkoutFixture()
  let logs = DelayedHandoffLogs()
  let model = TodayWorkoutViewModel(plans: fixture.repository, logs: logs)
  await model.load(dayID: nil, studentID: StudentDemoSeed.studentID)
  let original = model.currentDay
  var safe = true
  await fixture.repository.advance()
  await logs.pauseNextRead()
  let navigation = Task { await model.enterTraining(isSafe: { safe }) }
  await logs.waitUntilPaused()
  safe = false
  await logs.resume()
  await navigation.value
  #expect(model.planProjection?.cycleID == fixture.current.cycleID)
  #expect(model.currentDay == original)
}

private actor DelayedHandoffLogs: StudentTrainingLogRepository {
  private var shouldPause = false
  private var continuation: CheckedContinuation<Void, Never>?
  func recordSet(_ log: StudentSetLog) async throws -> StudentSetLog { log }
  func fetchLogs(studentID: UUID, in dateRange: ClosedRange<Date>) async throws -> [StudentSetLog] {
    if shouldPause {
      shouldPause = false
      await withCheckedContinuation { continuation = $0 }
    }
    return []
  }
  func fetchLogsForExercise(studentID: UUID, planExerciseID: UUID) async throws -> [StudentSetLog] {
    []
  }
  func pauseNextRead() { shouldPause = true }
  func waitUntilPaused() async {
    while continuation == nil { await Task.yield() }
  }
  func resume() {
    continuation?.resume()
    continuation = nil
  }
}
