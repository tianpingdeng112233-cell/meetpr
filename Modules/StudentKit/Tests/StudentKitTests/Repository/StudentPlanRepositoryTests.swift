import CoreModels
import Foundation
import Networking
import RepositoryContracts
import Testing

@testable import StudentKit

@Test func studentPlanRepositoryFetchesProjectionAndSlicesDayByIdentity() async throws {
  let studentID = StudentDemoSeed.studentID
  let plan = StudentDemoSeed.makePlanView()
  let repository = InMemoryStudentPlanRepository(
    store: TestStudentPlanStore(seed: [studentID: plan])
  )

  #expect(try await repository.fetchCurrentPlan(studentID: studentID) == plan)
  #expect(
    try await repository.fetchDay(studentID: studentID, dayID: plan.days[0].id)
      == plan.days[0]
  )
  #expect(
    try await repository.fetchCycleDays(studentID: studentID)
      == StudentPlanSequence.orderedDays(in: plan)
  )
}

@Test func manualCompletionAdvancesCursorAndUndoRestoresIt() async throws {
  let studentID = UUID()
  let now = Date(timeIntervalSince1970: 2_000_000_000)
  let plan = sequencePlan()
  let repository = InMemoryStudentPlanRepository(
    store: TestStudentPlanStore(seed: [studentID: plan]),
    now: { now }
  )
  let firstID = try #require(StudentPlanSequence.cursorDay(in: plan)?.id)

  let completion = try await repository.completeDay(id: firstID, studentID: studentID)
  let advanced = try #require(try await repository.fetchCurrentPlan(studentID: studentID))
  #expect(completion.source == "manual")
  #expect(StudentPlanSequence.cursorDay(in: advanced)?.id == plan.days[1].id)

  try await repository.undoDayCompletion(id: firstID, studentID: studentID)
  let restored = try #require(try await repository.fetchCurrentPlan(studentID: studentID))
  #expect(StudentPlanSequence.cursorDay(in: restored)?.id == firstID)
}

@Test func zeroSetDayCanBeCompletedManually() async throws {
  let studentID = UUID()
  let plan = replacingDays(
    in: sequencePlan(),
    with: [
      StudentPlanDay(
        id: UUID(), weekNumber: 1, dayOfWeek: 1, sortOrder: 0,
        date: Date(timeIntervalSince1970: 1_900_000_000), exercises: [])
    ]
  )
  let repository = InMemoryStudentPlanRepository(
    store: TestStudentPlanStore(seed: [studentID: plan])
  )

  let completion = try await repository.completeDay(id: plan.days[0].id, studentID: studentID)
  let completed = try #require(try await repository.fetchCurrentPlan(studentID: studentID))

  #expect(completion.source == "manual")
  #expect(completed.days[0].completionSource == "manual")
  #expect(StudentPlanSequence.cursorDay(in: completed) == nil)
}

@Test func undoRejectsCompletionThatIsNotLatest() async throws {
  let studentID = UUID()
  let now = Date(timeIntervalSince1970: 2_000_000_000)
  let base = sequencePlan()
  let plan = replacingDays(
    in: base,
    with: [
      base.days[0].replacingCompletion(
        completedAt: now.addingTimeInterval(-120), source: "manual"),
      base.days[1].replacingCompletion(
        completedAt: now.addingTimeInterval(-60), source: "manual"),
    ]
  )
  let repository = InMemoryStudentPlanRepository(
    store: TestStudentPlanStore(seed: [studentID: plan]),
    now: { now }
  )

  await #expect(throws: PlanDayCompletionError.notLatestCompletion) {
    try await repository.undoDayCompletion(id: plan.days[0].id, studentID: studentID)
  }
}

@Test func undoRejectsCompletionOutsideCurrentGymDay() async throws {
  let studentID = UUID()
  let now = Date(timeIntervalSince1970: 2_000_000_000)
  let base = sequencePlan()
  let plan = replacingDays(
    in: base,
    with: [
      base.days[0].replacingCompletion(
        completedAt: now.addingTimeInterval(-86_400), source: "manual"),
      base.days[1],
    ]
  )
  let repository = InMemoryStudentPlanRepository(
    store: TestStudentPlanStore(seed: [studentID: plan]),
    now: { now }
  )

  await #expect(throws: PlanDayCompletionError.undoWindowPassed) {
    try await repository.undoDayCompletion(id: plan.days[0].id, studentID: studentID)
  }
}

@Test func automaticCompletionRequiresEveryPrescribedSlot() async throws {
  let studentID = UUID()
  let plan = sequencePlan()
  let day = plan.days[0]
  let exercise = try #require(day.exercises.first)
  let logs = InMemoryStudentTrainingLogRepository()
  let repository = InMemoryStudentPlanRepository(
    store: TestStudentPlanStore(seed: [studentID: plan]),
    logs: logs,
    now: { Date(timeIntervalSince1970: 2_000_000_000) }
  )

  let partial = StudentSetLog(
    id: UUID(), studentID: studentID, planExerciseID: exercise.id,
    exerciseID: exercise.exercise.id, setIndex: 0, loggedAt: Date(),
    weightKg: 100, reps: 5, rpe: 8, completed: true
  )
  _ = try await logs.recordSet(partial)
  #expect(try await repository.fetchCurrentPlan(studentID: studentID)?.days[0].completedAt == nil)

  var final = partial
  final = StudentSetLog(
    id: UUID(), studentID: studentID, planExerciseID: exercise.id,
    exerciseID: exercise.exercise.id, setIndex: 1, loggedAt: Date(),
    weightKg: 100, reps: 5, rpe: 8, completed: true
  )
  _ = try await logs.recordSet(final)
  let completed = try await repository.fetchCurrentPlan(studentID: studentID)?.days[0]
  #expect(completed?.completionSource == "auto")
}

@Test func failedPrescribedSetParticipatesInAutomaticCompletion() async throws {
  let studentID = UUID()
  let plan = sequencePlan()
  let exercise = try #require(plan.days[0].exercises.first)
  let logs = InMemoryStudentTrainingLogRepository()
  let repository = InMemoryStudentPlanRepository(
    store: TestStudentPlanStore(seed: [studentID: plan]),
    logs: logs,
    now: { Date(timeIntervalSince1970: 2_000_000_000) }
  )

  for (index, failed) in [(0, false), (1, true)] {
    _ = try await logs.recordSet(
      StudentSetLog(
        id: UUID(), studentID: studentID, planExerciseID: exercise.id,
        exerciseID: exercise.exercise.id, setIndex: index, loggedAt: Date(),
        weightKg: 100, reps: 5, rpe: 8, completed: !failed, failed: failed
      )
    )
  }

  let completed = try await repository.fetchCurrentPlan(studentID: studentID)?.days[0]
  #expect(completed?.completionSource == "auto")
}

@Test func undoWindowUsesShanghaiFourAMBoundary() async throws {
  let studentID = UUID()
  let completedAt = try shanghaiDate(2026, 8, 7, hour: 20)
  let beforeCutoffTime = try shanghaiDate(2026, 8, 8, hour: 3, minute: 59)
  let cutoffTime = try shanghaiDate(2026, 8, 8, hour: 4)
  let base = sequencePlan()
  let completedPlan = replacingDays(
    in: base,
    with: [
      base.days[0].replacingCompletion(completedAt: completedAt, source: "manual"),
      base.days[1],
    ]
  )
  let beforeCutoff = InMemoryStudentPlanRepository(
    store: TestStudentPlanStore(seed: [studentID: completedPlan]),
    now: { beforeCutoffTime }
  )
  let atCutoff = InMemoryStudentPlanRepository(
    store: TestStudentPlanStore(seed: [studentID: completedPlan]),
    now: { cutoffTime }
  )

  try await beforeCutoff.undoDayCompletion(id: completedPlan.days[0].id, studentID: studentID)
  await #expect(throws: PlanDayCompletionError.undoWindowPassed) {
    try await atCutoff.undoDayCompletion(id: completedPlan.days[0].id, studentID: studentID)
  }
}

@Test func undoThenRefillingSetCanAutomaticallyCompleteAgain() async throws {
  let studentID = UUID()
  let now = Date(timeIntervalSince1970: 2_000_000_000)
  let base = sequencePlan()
  let plan = replacingDays(in: base, with: [base.days[0]])
  let exercise = try #require(plan.days[0].exercises.first)
  let logs = InMemoryStudentTrainingLogRepository()
  let repository = InMemoryStudentPlanRepository(
    store: TestStudentPlanStore(seed: [studentID: plan]),
    logs: logs,
    now: { now }
  )

  var recorded: [StudentSetLog] = []
  for index in 0...1 {
    let log = StudentSetLog(
      id: UUID(), studentID: studentID, planExerciseID: exercise.id,
      exerciseID: exercise.exercise.id, setIndex: index,
      loggedAt: now.addingTimeInterval(TimeInterval(index)),
      weightKg: 100, reps: 5, rpe: 8, completed: true
    )
    recorded.append(try await logs.recordSet(log))
  }
  #expect(try await repository.fetchCurrentPlan(studentID: studentID)?.days[0].completedAt != nil)

  try await repository.undoDayCompletion(id: plan.days[0].id, studentID: studentID)
  #expect(try await repository.fetchCurrentPlan(studentID: studentID)?.days[0].completedAt == nil)

  let refill = recorded[1]
  _ = try await logs.recordSet(
    StudentSetLog(
      id: refill.id, studentID: refill.studentID,
      planExerciseID: refill.planExerciseID, exerciseID: refill.exerciseID,
      setIndex: refill.setIndex, loggedAt: refill.loggedAt.addingTimeInterval(1),
      weightKg: refill.weightKg, reps: refill.reps, rpe: refill.rpe,
      completed: true
    )
  )
  #expect(
    try await repository.fetchCurrentPlan(studentID: studentID)?.days[0].completionSource
      == "auto"
  )
}

@Test func currentPlanSelectionPrefersPublishedThenCreatedThenIdentity() throws {
  let studentID = UUID()
  let createdAt = Date(timeIntervalSince1970: 1_800_000_000)
  let older = planDTO(
    id: try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000001")),
    studentID: studentID,
    publishedAt: createdAt,
    createdAt: createdAt.addingTimeInterval(100)
  )
  let newer = planDTO(
    id: try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000002")),
    studentID: studentID,
    publishedAt: createdAt.addingTimeInterval(1),
    createdAt: createdAt
  )

  #expect([newer, older].max(by: BackendStudentPlanRepository.planPrecedes)?.id == newer.id)

  let publishedAt = try #require(newer.publishedAt)
  let laterCreated = planDTO(
    id: try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000003")),
    studentID: studentID,
    publishedAt: publishedAt,
    createdAt: newer.createdAt.addingTimeInterval(1)
  )
  #expect(
    [newer, laterCreated].max(by: BackendStudentPlanRepository.planPrecedes)?.id
      == laterCreated.id
  )

  let higherIdentity = planDTO(
    id: try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000004")),
    studentID: studentID,
    publishedAt: try #require(laterCreated.publishedAt),
    createdAt: laterCreated.createdAt
  )
  #expect(
    [laterCreated, higherIdentity].max(by: BackendStudentPlanRepository.planPrecedes)?.id
      == higherIdentity.id
  )
}

@Test(arguments: [
  ("NOT_LATEST_COMPLETION", PlanDayCompletionError.notLatestCompletion),
  ("UNDO_WINDOW_PASSED", PlanDayCompletionError.undoWindowPassed),
  ("PLAN_NOT_ACTIVE", PlanDayCompletionError.planNotActive),
  ("NOT_PLAN_STUDENT", PlanDayCompletionError.notPlanStudent),
])
func completionMachineCodesMapToDomain(
  machineCode: String,
  expected: PlanDayCompletionError
) {
  #expect(PlanDayCompletionError(machineCode: machineCode) == expected)
}

@Test func backendExerciseCatalogUsesDiskCopyWhenServerReturnsNotModified() async throws {
  let directory = FileManager.default.temporaryDirectory
    .appending(path: "ExerciseCatalog304Tests-\(UUID().uuidString)", directoryHint: .isDirectory)
  defer { try? FileManager.default.removeItem(at: directory) }
  let exercise = try #require(StudentDemoSeed.makePlanView().days.first?.exercises.first?.exercise)
  let cache = ExerciseCatalogCache(directory: directory)
  try await cache.save(exercises: [exercise], etag: #""catalog-v1""#)
  let api = APIClient(environment: ["MEETPR_API_BASE_URL": "https://api.test"]) { _ in
    APIResponse(data: Data(), statusCode: 304)
  }
  let repository = BackendStudentPlanRepository(
    api: api,
    session: CompletionTestSession(),
    catalogCache: cache
  )

  #expect(try await repository.fetchExerciseCatalog() == [exercise])
}

private func sequencePlan() -> StudentPlanView {
  let exercise = StudentPlanExercise(
    id: UUID(),
    exercise: StudentDemoSeed.makePlanView().days[0].exercises[0].exercise,
    sequenceIndex: 0,
    prescribedSets: [
      PrescribedSet(id: UUID(), setIndex: 0, weightKg: 100, reps: 5, rpe: 8),
      PrescribedSet(id: UUID(), setIndex: 1, weightKg: 100, reps: 5, rpe: 8),
    ]
  )
  let start = Date(timeIntervalSince1970: 1_900_000_000)
  let days = [
    StudentPlanDay(
      id: UUID(), weekNumber: 1, dayOfWeek: 1, sortOrder: 0, date: start, exercises: [exercise]),
    StudentPlanDay(
      id: UUID(), weekNumber: 1, dayOfWeek: 2, sortOrder: 0, date: start.addingTimeInterval(86_400),
      exercises: [exercise]),
  ]
  return StudentPlanView(
    cycleID: UUID(), weekIndex: 1, startDate: start, endDate: days[1].date, days: days)
}

private func shanghaiDate(
  _ year: Int,
  _ month: Int,
  _ day: Int,
  hour: Int,
  minute: Int = 0
) throws -> Date {
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = try #require(TimeZone(identifier: "Asia/Shanghai"))
  return try #require(
    calendar.date(
      from: DateComponents(
        timeZone: calendar.timeZone,
        year: year,
        month: month,
        day: day,
        hour: hour,
        minute: minute
      )
    )
  )
}

private func replacingDays(
  in plan: StudentPlanView,
  with days: [StudentPlanDay]
) -> StudentPlanView {
  StudentPlanView(
    cycleID: plan.cycleID,
    weekIndex: plan.weekIndex,
    startDate: plan.startDate,
    endDate: plan.endDate,
    planKind: plan.planKind,
    publishedAt: plan.publishedAt,
    totalShiftDays: plan.totalShiftDays,
    latestShiftCreatedAt: plan.latestShiftCreatedAt,
    days: days
  )
}

private func planDTO(
  id: UUID,
  studentID: UUID,
  publishedAt: Date,
  createdAt: Date
) -> PlanDTO {
  PlanDTO(
    id: id, coachID: UUID(), traineeID: studentID, name: "Cycle",
    startDate: createdAt, endDate: createdAt, planWeeks: 1, source: .coach,
    status: .published, publishedAt: publishedAt, createdAt: createdAt, updatedAt: createdAt
  )
}

private struct CompletionTestSession: SessionStateReader {
  func accessToken() async throws -> String { "token" }
  func currentUser() async throws -> User { throw SessionStateReaderError.missingCurrentUser }
}
