import Foundation
import Networking
import RepositoryContracts
import Testing

@testable import StudentKit

@Test func crossDayVisitIsScopedToStudentPlanAndDay() throws {
  let name = UUID().uuidString
  let defaults = try #require(UserDefaults(suiteName: name))
  defer { defaults.removePersistentDomain(forName: name) }
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
  let visits = WorkoutResumeVisits(defaults: defaults, calendar: calendar)
  let student = UUID()
  let plan = UUID()
  let day = UUID()
  let otherDay = UUID()
  let first = Date(timeIntervalSince1970: 1_795_478_400)
  let later = first.addingTimeInterval(172_800)
  #expect(visits.open(student: student, plan: plan, day: day, today: first, prompt: true) == nil)
  #expect(
    visits.open(student: student, plan: plan, day: otherDay, today: later, prompt: true) == nil)
  #expect(visits.open(student: student, plan: plan, day: day, today: later, prompt: true) == first)
  #expect(visits.open(student: UUID(), plan: plan, day: day, today: later, prompt: true) == nil)
  visits.continueDay(student: student, plan: plan, day: day, today: later)
  #expect(visits.open(student: student, plan: plan, day: day, today: later, prompt: true) == nil)
}

@MainActor
@Test func resumeWritesOnlyMissingSetsAndConfirmsChosenDate() async throws {
  var plan = StudentAddedTestPlan.unsettledDemo()
  plan.actualCompletionDateEnabled = true
  let student = StudentDemoSeed.studentID
  let day = plan.days[0]
  let logs = InMemoryStudentTrainingLogRepository()
  let repository = InMemoryStudentPlanRepository(store: TestStudentPlanStore(seed: [student: plan]))
  let model = TodayWorkoutViewModel(plans: repository, logs: logs)
  await model.load(dayID: day.id, studentID: student)
  #expect(await model.saveAllDayRow(rowIndex: 0))
  let before = try await logs.fetchAllLogs(
    studentID: student, in: Date.distantPast...Date.distantFuture)
  let existing = try #require(before.planned.first)
  let date = try #require(
    WorkoutDatePolicy.deviceCalendar.date(from: DateComponents(year: 2026, month: 11, day: 24)))
  #expect(await model.completeResumedDay(id: day.id, actualDate: date))
  let after = try await logs.fetchAllLogs(
    studentID: student, in: Date.distantPast...Date.distantFuture)
  #expect(after.planned.contains(existing))
  #expect(!after.planned.filter { $0.id != existing.id }.isEmpty)
  #expect(
    after.planned.filter { $0.id != existing.id }.allSatisfy { $0.loggedDate == "2026-11-24" })
  #expect(
    try await repository.fetchDay(studentID: student, dayID: day.id)?.actualCompletionDate
      == "2026-11-24")
  #expect(model.completionPhase == nil)
}

@Test func weekLongResumeIncludesBothCalendarDates() throws {
  let calendar = WorkoutDatePolicy.deviceCalendar
  let first = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 24)))
  let today = try #require(calendar.date(from: DateComponents(year: 2026, month: 12, day: 1)))
  let prompt = WorkoutResumePrompt(
    id: UUID(), planID: UUID(), code: "W1D1",
    lastOpened: first, today: today, recorded: 0, total: 9)
  #expect(prompt.days.count == 8)
  #expect(prompt.days.first == first)
  #expect(prompt.days.last == today)
  let tomorrow = try #require(calendar.date(byAdding: .day, value: 1, to: today))
  #expect(prompt.asOf(tomorrow).days == prompt.days + [tomorrow])
}

@MainActor
@Test func resumeCompletionRetryRetainsOriginalIntentAcrossRestart() throws {
  let student = UUID()
  let day = UUID()
  let storage = MemorySetSyncStorage()
  let gate = try WorkoutCompletionGate(studentID: student, storage: storage)
  try gate.request(dayID: day, actualCompletionDate: "2026-11-24")
  let restored = try WorkoutCompletionGate(studentID: student, storage: storage)
  #expect(restored.actualCompletionDate(dayID: day) == "2026-11-24")
  #expect(throws: PlanDayCompletionError.unavailable) {
    try restored.request(dayID: day, actualCompletionDate: "2026-11-26")
  }
  #expect(restored.pendingDays == [day])
}

@MainActor
@Test func resumeCapabilityDefaultsOffAndEarlierCompletionLeavesTodaysCursorAvailable() async throws
{
  let student = StudentDemoSeed.studentID
  var plan = StudentAddedTestPlan.unsettledDemo()
  plan.actualCompletionDateEnabled = false
  let day = plan.days[0]
  let model = TodayWorkoutViewModel(
    plans: InMemoryStudentPlanRepository(
      store: TestStudentPlanStore(seed: [student: plan])),
    logs: InMemoryStudentTrainingLogRepository())
  await model.load(dayID: day.id, studentID: student)
  #expect(!(await model.completeResumedDay(id: day.id, actualDate: day.date)))
  let today = Date(timeIntervalSince1970: 1_795_694_400)
  let completed = day.replacingCompletion(
    completedAt: today, source: "manual", actualDate: "2026-11-24")
  #expect(TrainingDayPresentation.completedToday(in: [completed], now: today) == nil)
}

@MainActor
@Test func partialResumeWritesStayPinnedAndCannotCompleteOnRestart() async throws {
  let student = UUID()
  let day = UUID()
  let storage = MemorySetSyncStorage()
  let gate = try WorkoutCompletionGate(studentID: student, storage: storage)
  try gate.prepareResumeWrites(dayID: day, date: "2026-11-24")
  let restored = try WorkoutCompletionGate(studentID: student, storage: storage)
  #expect(restored.pendingDays.isEmpty)
  #expect(throws: PlanDayCompletionError.unavailable) {
    try restored.prepareResumeWrites(dayID: day, date: "2026-11-25")
  }
  try restored.request(dayID: day, actualCompletionDate: "2026-11-24")
  await #expect(throws: APIError.httpStatus(400, Data())) {
    try await restored.completeIfReady(dayID: day, setsSynced: true, videosDelivered: true) {
      throw APIError.httpStatus(400, Data())
    }
  }
  #expect(restored.pendingDays.isEmpty)
  #expect(restored.actualCompletionDate(dayID: day) == "2026-11-24")
  try restored.request(dayID: day, actualCompletionDate: "2026-11-24")
  #expect(restored.pendingDays == [day])
}

@MainActor
@Test func rejectedResumeWithoutNewSetsUnlocksDateButTimeoutKeepsIt() async throws {
  let day = UUID()
  let gate = try WorkoutCompletionGate(studentID: UUID(), storage: MemorySetSyncStorage())
  try gate.request(dayID: day, actualCompletionDate: "2026-11-24")
  await #expect(throws: URLError(.timedOut)) {
    try await gate.completeIfReady(dayID: day, setsSynced: true, videosDelivered: true) {
      throw URLError(.timedOut)
    }
  }
  #expect(gate.actualCompletionDate(dayID: day) == "2026-11-24")
  await #expect(throws: APIError.httpStatus(400, Data())) {
    try await gate.completeIfReady(dayID: day, setsSynced: true, videosDelivered: true) {
      throw APIError.httpStatus(400, Data())
    }
  }
  try gate.request(dayID: day, actualCompletionDate: "2026-11-25")
  #expect(gate.actualCompletionDate(dayID: day) == "2026-11-25")
}

@MainActor
@Test func failedSecondGroupCannotSplitResumeAcrossDates() async throws {
  var plan = StudentAddedTestPlan.unsettledDemo()
  plan.actualCompletionDateEnabled = true
  let student = StudentDemoSeed.studentID
  let day = plan.days[0]
  let logs = FailOnceTrainingLogRepository(failingAttempt: 2)
  let model = TodayWorkoutViewModel(
    plans: InMemoryStudentPlanRepository(store: TestStudentPlanStore(seed: [student: plan])),
    logs: logs)
  await model.load(dayID: day.id, studentID: student)
  let date = try #require(
    quickLogUTCCalendar.date(from: DateComponents(year: 2026, month: 11, day: 24)))
  #expect(!(await model.completeResumedDay(id: day.id, actualDate: date)))
  #expect(await logs.storedLogs().count == 1)
  let attempts = await logs.attemptedSlots().count
  #expect(
    !(await model.completeResumedDay(id: day.id, actualDate: date.addingTimeInterval(86_400))))
  #expect(await logs.attemptedSlots().count == attempts)
  #expect(await model.completeResumedDay(id: day.id, actualDate: date))
  #expect(await logs.storedLogs().allSatisfy { $0.loggedDate == "2026-11-24" })
}

@MainActor
@Test func invalidFirstGroupDoesNotLockResumeDate() async throws {
  var plan = StudentAddedTestPlan.unsettledDemo()
  plan.actualCompletionDateEnabled = true
  let student = StudentDemoSeed.studentID
  let logs = InMemoryStudentTrainingLogRepository()
  let model = TodayWorkoutViewModel(
    plans: InMemoryStudentPlanRepository(store: TestStudentPlanStore(seed: [student: plan])),
    logs: logs)
  let dayID = plan.days[0].id
  await model.load(dayID: dayID, studentID: student)
  model.updateWeight(rowIndex: 0, weight: -1)
  let date = try #require(
    quickLogUTCCalendar.date(from: DateComponents(year: 2026, month: 11, day: 24)))
  #expect(!(await model.completeResumedDay(id: dayID, actualDate: date)))
  #expect(model.lockedResumeDate(dayID: dayID) == nil)
  model.updateWeight(rowIndex: 0, weight: 1)
  #expect(await model.completeResumedDay(id: dayID, actualDate: date.addingTimeInterval(86_400)))
  #expect(
    try await logs.fetchLogs(studentID: student, in: Date.distantPast...Date.distantFuture)
      .allSatisfy { $0.loggedDate == "2026-11-25" })
}
