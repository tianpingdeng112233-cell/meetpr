import CoreModels
import Foundation
import Networking
import RepositoryContracts
import Testing

@testable import StudentKit

@Test func studentPlanRepositoryFetchesProjectionAndSlicesDay() async throws {
  let studentID = StudentDemoSeed.studentID
  let plan = StudentDemoSeed.makePlanView()
  let store = TestStudentPlanStore(seed: [studentID: plan])
  let repository = InMemoryStudentPlanRepository(store: store)

  let fetchedPlan = try await repository.fetchCurrentPlan(studentID: studentID)
  #expect(fetchedPlan == plan)

  let firstDay = try await repository.fetchDay(
    studentID: studentID,
    date: plan.days[0].date.addingTimeInterval(3_600)
  )
  #expect(firstDay == plan.days[0])

  let days = try await repository.fetchCycleDays(studentID: studentID)
  #expect(days == plan.days.sorted { $0.date < $1.date })
}

@Test func studentPlanRepositoryReturnsEmptyForMissingProjection() async throws {
  let repository = InMemoryStudentPlanRepository(store: TestStudentPlanStore())

  let studentID = UUID()
  #expect(try await repository.fetchCurrentPlan(studentID: studentID) == nil)
  #expect(try await repository.fetchDay(studentID: studentID, date: Date()) == nil)
  #expect(try await repository.fetchCycleDays(studentID: studentID).isEmpty)
}

@Test func inMemoryStudentPlanRepositoryStacksAcrossDaysAndUndoesLatestBatch() async throws {
  let studentID = StudentDemoSeed.studentID
  let plan = StudentDemoSeed.makePlanView()
  // 必须和 StudentDemoSeed.demoCycleStart 用同一个口径:种子把**设备本地的今天**映射成
  // UTC 午夜锚点,而不是直接取 UTC 日。直接 utcCalendar.startOfDay(Date()) 会在
  // 本地日 ≠ UTC 日的那段时间里差一天,把「今天」落到种子的休息日上,shiftPlan 于是抛 .onlyToday。
  // 在 UTC+1 是每天凌晨那一小时,在东八区是每天 00:00–08:00——上海的 CI 会天天红。
  let today =
    PlanCalendarDayIdentity.planDate(
      matching: Date(),
      selectedCalendar: .current
    ) ?? StudentDemoSeed.utcCalendar.startOfDay(for: Date())
  let clock = ShiftTestClock(today.addingTimeInterval(12 * 3_600))
  let repository = InMemoryStudentPlanRepository(
    store: TestStudentPlanStore(seed: [studentID: plan]),
    now: { clock.now }
  )

  let first = try await repository.shiftPlan(id: plan.cycleID, studentID: studentID)
  let afterFirst = try #require(
    try await repository.fetchCurrentPlan(studentID: studentID)
  )
  #expect(first.totalShiftDays == 1)
  #expect(afterFirst.totalShiftDays == 1)
  let originalDaysThroughToday = plan.days.filter { $0.date <= today }.count
  let shiftedDaysThroughToday = afterFirst.days.filter { $0.date <= today }.count
  #expect(shiftedDaysThroughToday == originalDaysThroughToday - 1)

  clock.advance(days: 1)
  let second = try await repository.shiftPlan(id: plan.cycleID, studentID: studentID)
  let afterSecond = try #require(
    try await repository.fetchCurrentPlan(studentID: studentID)
  )
  #expect(second.totalShiftDays == 2)
  #expect(afterSecond.totalShiftDays == 2)

  try await repository.cancelPlanShift(id: plan.cycleID, studentID: studentID)
  let restoredLatest = try #require(
    try await repository.fetchCurrentPlan(studentID: studentID)
  )
  #expect(restoredLatest == afterFirst)

  do {
    try await repository.cancelPlanShift(id: plan.cycleID, studentID: studentID)
    Issue.record("Expected the previous day's batch to be outside the undo window")
  } catch let error as PlanShiftError {
    #expect(error == .undoWindowPassed)
  }
}

@Test func inMemoryStudentPlanRepositoryRejectsUndoWithoutABatch() async throws {
  let studentID = StudentDemoSeed.studentID
  let plan = StudentDemoSeed.makePlanView()
  let repository = InMemoryStudentPlanRepository(
    store: TestStudentPlanStore(seed: [studentID: plan])
  )

  do {
    try await repository.cancelPlanShift(id: plan.cycleID, studentID: studentID)
    Issue.record("Expected NO_ACTIVE_SHIFT")
  } catch let error as PlanShiftError {
    #expect(error == .noActiveShift)
  }
}

@Test(arguments: [
  ("PLAN_NOT_ACTIVE", PlanShiftError.planNotActive),
  ("SHIFT_ONLY_TODAY", PlanShiftError.onlyToday),
  ("ALREADY_STARTED", PlanShiftError.alreadyStarted),
  ("NOT_PLAN_STUDENT", PlanShiftError.notPlanStudent),
  ("NO_ACTIVE_SHIFT", PlanShiftError.noActiveShift),
  ("UNDO_WINDOW_PASSED", PlanShiftError.undoWindowPassed),
])
func backendStudentPlanRepositoryMapsShiftMachineCodes(
  machineCode: String,
  expected: PlanShiftError
) async throws {
  let api = APIClient(environment: ["MEETPR_API_BASE_URL": "https://api.test"]) { _ in
    APIResponse(
      data: Data("{\"error\":\"\(machineCode)\"}".utf8),
      statusCode: 409
    )
  }
  let repository = BackendStudentPlanRepository(
    api: api,
    session: ShiftTestSession()
  )

  do {
    _ = try await repository.shiftPlan(id: UUID(), studentID: UUID())
    Issue.record("Expected \(machineCode) to throw")
  } catch let error as PlanShiftError {
    #expect(error == expected)
  } catch {
    Issue.record("Unexpected error: \(error)")
  }
}

@Test func backendExerciseCatalogUsesDiskCopyWhenServerReturnsNotModified() async throws {
  let directory = FileManager.default.temporaryDirectory
    .appending(path: "ExerciseCatalog304Tests-\(UUID().uuidString)", directoryHint: .isDirectory)
  defer { try? FileManager.default.removeItem(at: directory) }

  let exercise = try #require(
    StudentDemoSeed.makePlanView().days.first?.exercises.first?.exercise
  )
  let cache = ExerciseCatalogCache(directory: directory)
  try await cache.save(exercises: [exercise], etag: #""catalog-v1""#)
  let capture = CatalogRequestCapture()
  let api = APIClient(environment: ["MEETPR_API_BASE_URL": "https://api.test"]) { request in
    await capture.record(request)
    return APIResponse(data: Data(), statusCode: 304)
  }
  let repository = BackendStudentPlanRepository(
    api: api,
    session: ShiftTestSession(),
    catalogCache: cache
  )

  let exercises = try await repository.fetchExerciseCatalog()
  let request = try #require(await capture.request)

  #expect(exercises == [exercise])
  #expect(request.value(forHTTPHeaderField: "If-None-Match") == #""catalog-v1""#)
}

private final class ShiftTestClock: @unchecked Sendable {
  private let lock = NSLock()
  private var value: Date

  init(_ value: Date) {
    self.value = value
  }

  var now: Date {
    lock.withLock { value }
  }

  func advance(days: Int) {
    lock.withLock {
      value = value.addingTimeInterval(Double(days) * 86_400)
    }
  }
}

private struct ShiftTestSession: SessionStateReader {
  func accessToken() async throws -> String {
    "token"
  }

  func currentUser() async throws -> User {
    throw SessionStateReaderError.missingCurrentUser
  }
}

private actor CatalogRequestCapture {
  private(set) var request: URLRequest?

  func record(_ request: URLRequest) {
    self.request = request
  }
}
