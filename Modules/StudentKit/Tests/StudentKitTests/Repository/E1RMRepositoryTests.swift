import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import StudentKit

private func point(
  studentId: UUID,
  exerciseId: UUID,
  daysAgo: Double,
  e1RM: Double,
  anchor: Date = Date(timeIntervalSince1970: 1_768_262_400),
  confidence: E1RMConfidence = .normal
) -> E1RMHistoryPoint {
  E1RMHistoryPoint(
    id: UUID(),
    studentId: studentId,
    exerciseId: exerciseId,
    setLogId: UUID(),
    computedAt: anchor.addingTimeInterval(-daysAgo * 86_400),
    e1RMKg: e1RM,
    sourceWeightKg: 100,
    sourceReps: 5,
    sourceRPE: 8,
    confidence: confidence
  )
}

/// Both implementations must satisfy the same contract; Local gets a temp dir.
private func makeRepos() -> [(String, any E1RMRepository)] {
  let tempDir = FileManager.default.temporaryDirectory
    .appendingPathComponent("e1rm-tests-\(UUID().uuidString)", isDirectory: true)
  return [
    ("InMemory", InMemoryE1RMRepository()),
    ("Local", LocalE1RMRepository(directory: tempDir)),
  ]
}

@Test func recordAndFetchHistorySortedByDate() async throws {
  for (label, repo) in makeRepos() {
    let student = UUID()
    let squat = UUID()
    let older = point(studentId: student, exerciseId: squat, daysAgo: 10, e1RM: 120)
    let newer = point(studentId: student, exerciseId: squat, daysAgo: 2, e1RM: 125)
    try await repo.recordPoint(newer)
    try await repo.recordPoint(older)

    let history = try await repo.fetchHistory(studentId: student, exerciseId: squat)
    #expect(history.map(\.id) == [older.id, newer.id], "\(label): ascending by computedAt")

    let other = try await repo.fetchHistory(studentId: student, exerciseId: UUID())
    #expect(other.isEmpty, "\(label): unrelated exercise stays empty")
  }
}

@Test func batchFetchGroupsByExercise() async throws {
  for (label, repo) in makeRepos() {
    let student = UUID()
    let squat = UUID()
    let bench = UUID()
    try await repo.recordPoint(point(studentId: student, exerciseId: squat, daysAgo: 3, e1RM: 130))
    try await repo.recordPoint(point(studentId: student, exerciseId: bench, daysAgo: 1, e1RM: 90))

    let grouped = try await repo.fetchHistory(studentId: student, exerciseIds: [squat, bench])
    #expect(grouped[squat]?.count == 1, "\(label)")
    #expect(grouped[bench]?.count == 1, "\(label)")
  }
}

@Test func maxBeforeIsStrictlyEarlier() async throws {
  for (label, repo) in makeRepos() {
    let student = UUID()
    let squat = UUID()
    let anchor = Date(timeIntervalSince1970: 1_768_262_400)

    // Empty history → nil baseline.
    let empty = try await repo.maxBefore(studentId: student, exerciseId: squat, before: anchor)
    #expect(empty == nil, "\(label)")

    try await repo.recordPoint(
      point(studentId: student, exerciseId: squat, daysAgo: 10, e1RM: 120, anchor: anchor))
    try await repo.recordPoint(
      point(studentId: student, exerciseId: squat, daysAgo: 5, e1RM: 132, anchor: anchor))
    let atAnchor = point(
      studentId: student, exerciseId: squat, daysAgo: 0, e1RM: 140, anchor: anchor)
    try await repo.recordPoint(atAnchor)

    // Strictly before: the point at the anchor itself is excluded.
    let max = try await repo.maxBefore(
      studentId: student, exerciseId: squat, before: atAnchor.computedAt)
    #expect(max == 132, "\(label)")
  }
}

@Test func maxBeforeExcludesQuarantinedPointsWithoutDeletingThem() async throws {
  for (label, repo) in makeRepos() {
    let student = UUID()
    let squat = UUID()
    let anchor = Date(timeIntervalSince1970: 1_768_262_400)
    let trusted = point(
      studentId: student,
      exerciseId: squat,
      daysAgo: 2,
      e1RM: 200,
      anchor: anchor
    )
    let quarantined = point(
      studentId: student,
      exerciseId: squat,
      daysAgo: 1,
      e1RM: 350,
      anchor: anchor,
      confidence: .low
    )
    try await repo.recordPoint(trusted)
    try await repo.recordPoint(quarantined)

    let max = try await repo.maxBefore(
      studentId: student,
      exerciseId: squat,
      before: anchor
    )
    let history = try await repo.fetchHistory(studentId: student, exerciseId: squat)

    #expect(max == 200, "\(label): quarantined point is not a baseline")
    #expect(history.map(\.id).contains(quarantined.id), "\(label): quarantined data remains stored")
  }
}

@Test func prFlowRecordUnacknowledgedAcknowledge() async throws {
  for (label, repo) in makeRepos() {
    let student = UUID()
    let event = PRBreakthroughEvent(
      id: UUID(),
      studentId: student,
      exerciseId: UUID(),
      pointId: UUID(),
      breakthroughE1RMKg: 140,
      previousMaxE1RMKg: 132,
      occurredAt: Date(timeIntervalSince1970: 1_768_262_400),
      acknowledgedAt: nil
    )
    try await repo.recordPR(event)

    let pending = try await repo.unacknowledgedPRs(studentId: student)
    #expect(pending.map(\.id) == [event.id], "\(label)")

    try await repo.acknowledgePR(eventId: event.id)
    let afterAck = try await repo.unacknowledgedPRs(studentId: student)
    #expect(afterAck.isEmpty, "\(label)")
  }
}

@Test func localRepositoryPersistsAcrossInstances() async throws {
  let tempDir = FileManager.default.temporaryDirectory
    .appendingPathComponent("e1rm-persist-\(UUID().uuidString)", isDirectory: true)
  let student = UUID()
  let squat = UUID()

  let first = LocalE1RMRepository(directory: tempDir)
  try await first.recordPoint(point(studentId: student, exerciseId: squat, daysAgo: 1, e1RM: 128))

  let second = LocalE1RMRepository(directory: tempDir)
  let history = try await second.fetchHistory(studentId: student, exerciseId: squat)
  #expect(history.count == 1)
  #expect(history.first?.e1RMKg == 128)
}

@Test func localRepositoryThrowsOnCorruptFileInsteadOfErasing() async throws {
  let tempDir = FileManager.default.temporaryDirectory
    .appendingPathComponent("e1rm-corrupt-\(UUID().uuidString)", isDirectory: true)
  try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
  try Data("not json".utf8).write(to: tempDir.appendingPathComponent("points.json"))

  let repo = LocalE1RMRepository(directory: tempDir)
  await #expect(throws: (any Error).self) {
    _ = try await repo.fetchHistory(studentId: UUID(), exerciseId: UUID())
  }
}
