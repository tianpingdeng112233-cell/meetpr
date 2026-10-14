import CoreModels
import Foundation
import Testing

@testable import StudentKit

private actor AddedFailureRepository: StudentAddedLogRepository {
  let storage = InMemoryStudentTrainingLogRepository()
  var failNext = false
  var suspended = false
  var started = false
  var gate: CheckedContinuation<Void, Never>?
  var startGate: CheckedContinuation<Void, Never>?
  var requests: [StudentAddedSetLog] = []

  func configure(fail: Bool = false, suspend: Bool = false) {
    started = false
    failNext = fail
    suspended = suspend
  }
  func waitForWrite() async {
    if started { return }
    await withCheckedContinuation { startGate = $0 }
  }
  func release() {
    gate?.resume()
    gate = nil
    suspended = false
  }
  func recordAddedSet(_ log: StudentAddedSetLog) async throws -> StudentAddedSetLog {
    requests.append(log)
    started = true
    startGate?.resume()
    startGate = nil
    if suspended { await withCheckedContinuation { gate = $0 } }
    if failNext {
      failNext = false
      throw URLError(.notConnectedToInternet)
    }
    return try await storage.recordAddedSet(log)
  }
  func recordSet(_ log: StudentSetLog) async throws -> StudentSetLog {
    if failNext {
      failNext = false
      throw URLError(.notConnectedToInternet)
    }
    return try await storage.recordSet(log)
  }
  func deleteAddedSet(id: UUID, studentID: UUID) async throws {
    started = true
    startGate?.resume()
    startGate = nil
    if suspended { await withCheckedContinuation { gate = $0 } }
    try await storage.deleteAddedSet(id: id, studentID: studentID)
  }
  func fetchAllLogs(studentID: UUID, in range: ClosedRange<Date>) async throws -> StudentWorkoutLogs
  {
    try await storage.fetchAllLogs(studentID: studentID, in: range)
  }
  func fetchLogs(studentID: UUID, in range: ClosedRange<Date>) async throws -> [StudentSetLog] {
    try await storage.fetchLogs(studentID: studentID, in: range)
  }
  func fetchLogsForExercise(studentID: UUID, planExerciseID: UUID) async throws -> [StudentSetLog] {
    try await storage.fetchLogsForExercise(studentID: studentID, planExerciseID: planExerciseID)
  }
}

private final class AddedTestClock: @unchecked Sendable {
  private let lock = NSLock()
  private var instant = Date(timeIntervalSince1970: 1_792_030_800)
  func now() -> Date { lock.withLock { instant } }
  func advance() { lock.withLock { instant += 86_400 } }
}

@MainActor
@Test func addedFailureKeepsInputAndPinnedDateAcrossRetry() async throws {
  let clock = AddedTestClock()
  let plan = StudentAddedTestPlan.unsettledDemo()
  let day = try #require(plan.days.first)
  let repository = AddedFailureRepository()
  let model = TodayWorkoutViewModel(
    plans: InMemoryStudentPlanRepository(
      store: TestStudentPlanStore(seed: [StudentDemoSeed.studentID: plan])),
    logs: repository, now: { clock.now() })
  await model.load(dayID: day.id, studentID: StudentDemoSeed.studentID)
  let exercise = try #require(plan.days.last?.exercises.last?.exercise)
  model.addStudentExercise(exercise)
  let draft = try #require(model.currentDrafts?.first { $0.isStudentAdded })
  var row = AccessoryRow(draft: draft, previous: nil, unit: .kg)
  row.input = AccessoryInput(weight: "42.5", reps: "8", rpe: "")
  await repository.configure(fail: true)
  #expect(await model.saveAccessoryRow(row) == false)
  let retained = try #require(model.currentDrafts?.first { $0.isStudentAdded })
  #expect(retained.actualWeight == 42.5)
  #expect(retained.actualReps == 8)
  clock.advance()
  #expect(await model.saveAccessoryRow(AccessoryRow(draft: retained, previous: nil, unit: .kg)))
  let requests = await repository.requests
  #expect(requests.count == 2)
  #expect(requests[0].loggedDate == requests[1].loggedDate)
  #expect(requests[1].planDayID == day.id)
}

@MainActor
@Test func addedWriteFinishingAfterDaySwitchKeepsCanonicalID() async throws {
  let plan = StudentAddedTestPlan.unsettledDemo()
  let day = try #require(plan.days.first)
  let repository = AddedFailureRepository()
  let model = TodayWorkoutViewModel(
    plans: InMemoryStudentPlanRepository(
      store: TestStudentPlanStore(seed: [StudentDemoSeed.studentID: plan])),
    logs: repository)
  await model.load(dayID: day.id, studentID: StudentDemoSeed.studentID)
  let exercise = try #require(plan.days.last?.exercises.last?.exercise)
  model.addStudentExercise(exercise)
  let draft = try #require(model.currentDrafts?.first { $0.isStudentAdded })
  var row = AccessoryRow(draft: draft, previous: nil, unit: .kg)
  row.input = AccessoryInput(weight: "30", reps: "10", rpe: "")
  await repository.configure(suspend: true)
  let save = Task { await model.saveAccessoryRow(row) }
  await repository.waitForWrite()
  await model.load(dayID: plan.days[1].id, studentID: StudentDemoSeed.studentID)
  await repository.release()
  #expect(await save.value)
  await model.load(dayID: day.id, studentID: StudentDemoSeed.studentID)
  let restored = try #require(model.currentDrafts?.first { $0.isStudentAdded })
  #expect(restored.completed)
  #expect(restored.loggedSetID != nil)
  #expect(await model.removeStudentRow(id: restored.id))
  #expect(
    try await repository.fetchAllLogs(
      studentID: StudentDemoSeed.studentID, in: .distantPast ... .distantFuture
    ).added.isEmpty)
}

@MainActor
@Test func extraFailureKeepsInputAndCanRetry() async throws {
  let plan = StudentAddedTestPlan.unsettledDemo()
  let repository = AddedFailureRepository()
  let model = TodayWorkoutViewModel(
    plans: InMemoryStudentPlanRepository(
      store: TestStudentPlanStore(seed: [StudentDemoSeed.studentID: plan])),
    logs: repository)
  await model.load(dayID: plan.days[0].id, studentID: StudentDemoSeed.studentID)
  model.addExtraSet(exerciseID: plan.days[0].exercises[0].id)
  let index = try #require(model.currentDrafts?.firstIndex { $0.isExtra })
  model.updateWeight(rowIndex: index, weight: 77.5)
  model.updateReps(rowIndex: index, reps: 3)
  await repository.configure(fail: true)
  #expect(await model.commitSet(rowIndex: index) == false)
  #expect(model.currentDrafts?[index].actualWeight == 77.5)
  #expect(model.currentDrafts?[index].actualReps == 3)
  #expect(await model.commitSet(rowIndex: index))
}

@MainActor
@Test func deletingLastAddedRowDuringDaySwitchClearsDatePin() async throws {
  let clock = AddedTestClock()
  let plan = StudentAddedTestPlan.unsettledDemo()
  let day = plan.days[0]
  let repository = AddedFailureRepository()
  let model = TodayWorkoutViewModel(
    plans: InMemoryStudentPlanRepository(
      store: TestStudentPlanStore(seed: [StudentDemoSeed.studentID: plan])),
    logs: repository, now: { clock.now() })
  await model.load(dayID: day.id, studentID: StudentDemoSeed.studentID)
  let exercise = try #require(plan.days.last?.exercises.last?.exercise)
  model.addStudentExercise(exercise)
  let draft = try #require(model.currentDrafts?.first { $0.isStudentAdded })
  var row = AccessoryRow(draft: draft, previous: nil, unit: .kg)
  row.input = AccessoryInput(weight: "30", reps: "10", rpe: "")
  #expect(await model.saveAccessoryRow(row))
  await repository.configure(suspend: true)
  let deletion = Task { await model.removeStudentRow(id: draft.id) }
  await repository.waitForWrite()
  await model.load(dayID: plan.days[1].id, studentID: StudentDemoSeed.studentID)
  await repository.release()
  #expect(await deletion.value)
  clock.advance()
  await model.load(dayID: day.id, studentID: StudentDemoSeed.studentID)
  model.addStudentExercise(exercise)
  let newDraft = try #require(model.currentDrafts?.first { $0.isStudentAdded })
  var newRow = AccessoryRow(draft: newDraft, previous: nil, unit: .kg)
  newRow.input = row.input
  #expect(await model.saveAccessoryRow(newRow))
  let requests = await repository.requests
  #expect(requests.count == 2)
  #expect(requests[0].loggedDate != requests[1].loggedDate)
}
