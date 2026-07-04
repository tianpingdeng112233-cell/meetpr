import CoreModels
import Foundation
import Networking
import RepositoryContracts
import Testing

@testable import StudentKit

// Spec 045 slice 3: adhoc upsert semantics (InMemory mirror of backend spec
// 010) and the offline write queue (断网不丢).

private let student = UUID()
private let squat = UUID()

private func isoDate(_ value: String) -> Date {
  ISO8601DateFormatter().date(from: value) ?? Date(timeIntervalSince1970: 0)
}

private let julyRange = isoDate("2026-07-01T00:00:00Z")...isoDate("2026-07-31T00:00:00Z")

private func adhocLog(
  setIndex: Int = 0,
  weight: Decimal = 140,
  reps: Int = 5,
  loggedDate: String = "2026-07-04",
  exerciseID: UUID? = squat
) -> StudentSetLog {
  StudentSetLog(
    id: UUID(),
    studentID: student,
    planExerciseID: nil,
    exerciseID: exerciseID,
    loggedDate: loggedDate,
    adhoc: true,
    setIndex: setIndex,
    loggedAt: isoDate("2026-07-04T10:00:00Z"),
    weightKg: weight,
    reps: reps,
    completed: true
  )
}

@available(iOS 17.0, macOS 14.0, *)
@Test func inMemoryAdhocUpsertKeepsIdentityForSameKey() async throws {
  let repo = InMemoryStudentTrainingLogRepository()

  let first = try await repo.recordAdhocSet(adhocLog(weight: 140))
  let second = try await repo.recordAdhocSet(adhocLog(weight: 145, reps: 3))

  #expect(second.id == first.id)
  #expect(second.weightKg == 145)
  let all = try await repo.fetchLogs(studentID: student, in: julyRange, scope: .all)
  #expect(all.count == 1)
}

@available(iOS 17.0, macOS 14.0, *)
@Test func inMemoryPlanScopeHidesAdhocRows() async throws {
  let repo = InMemoryStudentTrainingLogRepository()
  try await repo.recordAdhocSet(adhocLog())

  let planRows = try await repo.fetchLogs(studentID: student, in: julyRange, scope: .plan)
  let allRows = try await repo.fetchLogs(studentID: student, in: julyRange, scope: .all)

  #expect(planRows.isEmpty)
  #expect(allRows.count == 1)
}

@available(iOS 17.0, macOS 14.0, *)
@Test func inMemoryAdhocRequiresExerciseIdentity() async throws {
  let repo = InMemoryStudentTrainingLogRepository()
  await #expect(throws: StudentTrainingLogRepositoryError.missingExerciseIdentity) {
    try await repo.recordAdhocSet(adhocLog(exerciseID: nil))
  }
}

/// Upstream double whose adhoc writes fail with a configurable error until
/// healed; records what reached it.
private actor FlakyUpstream: StudentTrainingLogRepository {
  var failure: Error?
  var received: [StudentSetLog] = []

  init(failure: Error? = nil) {
    self.failure = failure
  }

  func heal() { failure = nil }

  @discardableResult
  func recordSet(_ log: StudentSetLog) async throws -> StudentSetLog { log }

  @discardableResult
  func recordAdhocSet(_ log: StudentSetLog) async throws -> StudentSetLog {
    if let failure { throw failure }
    received.append(log)
    return log
  }

  func fetchLogs(studentID: UUID, in dateRange: ClosedRange<Date>) async throws -> [StudentSetLog] {
    []
  }

  func fetchLogs(
    studentID: UUID, in dateRange: ClosedRange<Date>, scope: TrainingLogScope
  ) async throws -> [StudentSetLog] {
    []
  }

  func fetchLogsForExercise(
    studentID: UUID, planExerciseID: UUID
  ) async throws -> [StudentSetLog] {
    []
  }
}

private func makeTempStore() -> PendingSetLogStore {
  PendingSetLogStore(
    directory: FileManager.default.temporaryDirectory
      .appendingPathComponent("pending-tests-\(UUID().uuidString)", isDirectory: true))
}

@available(iOS 17.0, macOS 14.0, *)
@Test func queueParksTransportFailuresAndFlushesInOrder() async throws {
  let upstream = FlakyUpstream(failure: URLError(.notConnectedToInternet))
  let store = makeTempStore()
  let queued = QueuedTrainingLogRepository(upstream: upstream, store: store)

  let echoed = try await queued.recordAdhocSet(adhocLog(setIndex: 0, weight: 140))
  _ = try await queued.recordAdhocSet(adhocLog(setIndex: 1, weight: 145))

  #expect(echoed.adhoc == true)
  #expect(await queued.pendingCount(studentID: student) == 2)
  #expect(await upstream.received.isEmpty)

  await upstream.heal()
  try await queued.flush(studentID: student)

  #expect(await queued.pendingCount(studentID: student) == 0)
  let received = await upstream.received
  #expect(received.count == 2)
  #expect(received.map(\.setIndex) == [0, 1])
}

@available(iOS 17.0, macOS 14.0, *)
@Test func queueDoesNotParkValidationFailures() async throws {
  let upstream = FlakyUpstream(failure: APIError.httpStatus(400, Data()))
  let store = makeTempStore()
  let queued = QueuedTrainingLogRepository(upstream: upstream, store: store)

  await #expect(throws: APIError.httpStatus(400, Data())) {
    try await queued.recordAdhocSet(adhocLog())
  }
  #expect(await queued.pendingCount(studentID: student) == 0)
}

@available(iOS 17.0, macOS 14.0, *)
@Test func queueSurvivesRelaunchViaDiskPersistence() async throws {
  let directory = FileManager.default.temporaryDirectory
    .appendingPathComponent("pending-tests-\(UUID().uuidString)", isDirectory: true)
  let upstream = FlakyUpstream(failure: URLError(.timedOut))
  let queued = QueuedTrainingLogRepository(
    upstream: upstream, store: PendingSetLogStore(directory: directory))
  _ = try await queued.recordAdhocSet(adhocLog())

  // "Relaunch": a fresh store + repository over the same directory.
  await upstream.heal()
  let relaunched = QueuedTrainingLogRepository(
    upstream: upstream, store: PendingSetLogStore(directory: directory))
  try await relaunched.flush(studentID: student)

  #expect(await relaunched.pendingCount(studentID: student) == 0)
  #expect(await upstream.received.count == 1)
}

@available(iOS 17.0, macOS 14.0, *)
@Test func queueReplacesSameKeyWhileParked() async throws {
  let upstream = FlakyUpstream(failure: URLError(.notConnectedToInternet))
  let store = makeTempStore()
  let queued = QueuedTrainingLogRepository(upstream: upstream, store: store)

  _ = try await queued.recordAdhocSet(adhocLog(setIndex: 0, weight: 140))
  _ = try await queued.recordAdhocSet(adhocLog(setIndex: 0, weight: 150))

  #expect(await queued.pendingCount(studentID: student) == 1)

  await upstream.heal()
  try await queued.flush(studentID: student)
  let received = await upstream.received
  #expect(received.count == 1)
  #expect(received.first?.weightKg == 150)
}
