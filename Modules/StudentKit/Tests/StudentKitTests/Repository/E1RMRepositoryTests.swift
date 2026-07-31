// swiftlint:disable file_length
import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import StudentKit

private func point(
  id: UUID = UUID(),
  studentId: UUID,
  exerciseId: UUID,
  setLogId: UUID = UUID(),
  daysAgo: Double,
  e1RM: Double,
  anchor: Date = Date(timeIntervalSince1970: 1_768_262_400),
  confidence: E1RMConfidence = .normal,
  origin: E1RMPointOrigin = .logged,
  family: LiftFamily? = nil
) -> E1RMHistoryPoint {
  E1RMHistoryPoint(
    id: id,
    studentId: studentId,
    exerciseId: exerciseId,
    family: family,
    setLogId: setLogId,
    computedAt: anchor.addingTimeInterval(-daysAgo * 86_400),
    e1RMKg: e1RM,
    sourceWeightKg: 100,
    sourceReps: 5,
    sourceRPE: 8,
    confidence: confidence,
    origin: origin
  )
}

@Test func familyFetchCrossesExerciseBucketsAndExcludesLegacyNilFamily() async throws {
  for (label, repo) in makeRepos() {
    let student = UUID()
    let genericSquat = UUID()
    let lowBarSquat = UUID()
    let bench = UUID()
    try await repo.recordPoint(
      point(
        studentId: student,
        exerciseId: genericSquat,
        daysAgo: 3,
        e1RM: 130,
        family: .squat
      )
    )
    try await repo.recordPoint(
      point(
        studentId: student,
        exerciseId: lowBarSquat,
        daysAgo: 1,
        e1RM: 140,
        family: .squat
      )
    )
    try await repo.recordPoint(
      point(
        studentId: student,
        exerciseId: bench,
        daysAgo: 2,
        e1RM: 100,
        family: .bench
      )
    )
    try await repo.recordPoint(
      point(studentId: student, exerciseId: UUID(), daysAgo: 0, e1RM: 150)
    )

    let squatHistory = try await repo.fetchHistory(studentId: student, family: .squat)

    #expect(squatHistory.map(\.e1RMKg) == [130, 140], "\(label)")
  }
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

@Test func staleHistoryReplacementIsRejectedForBothRepositories() async throws {
  for (label, repo) in makeRepos() {
    let studentID = UUID()
    let exerciseID = UUID()
    let original = point(
      studentId: studentID,
      exerciseId: exerciseID,
      daysAgo: 2,
      e1RM: 120
    )
    try await repo.recordPoint(original)
    let snapshot = try await repo.historySnapshot(
      studentId: studentID,
      exerciseIds: [exerciseID]
    )
    let concurrent = point(
      studentId: studentID,
      exerciseId: exerciseID,
      daysAgo: 1,
      e1RM: 125
    )
    try await repo.recordPoint(concurrent)

    let didReplace = try await repo.replaceHistory(
      studentId: studentID,
      with: [original],
      weightBaselines: [],
      prEvents: [],
      ifUnchangedSince: snapshot.revision
    )
    let history = try await repo.fetchHistory(studentId: studentID, exerciseId: exerciseID)

    #expect(!didReplace, "\(label): stale revision must reject replacement")
    #expect(
      history.map(\.id) == [original.id, concurrent.id], "\(label): concurrent point survives")
  }
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
      family: .squat,
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
    let familyHistory = try await repo.fetchPRs(studentId: student, family: .squat)
    #expect(afterAck.isEmpty, "\(label)")
    #expect(familyHistory.map(\.id) == [event.id], "\(label): acknowledged PR remains a baseline")
  }
}

@Test func livePRRecordingIsIdempotentBySetLogIdentity() async throws {
  for (label, repo) in makeRepos() {
    let studentID = UUID()
    let setLogID = UUID()
    let first = PRBreakthroughEvent(
      id: UUID(),
      studentId: studentID,
      exerciseId: UUID(),
      family: .bench,
      setLogId: setLogID,
      pointId: UUID(),
      breakthroughE1RMKg: 120,
      previousMaxE1RMKg: 115,
      breakthroughWeightKg: 105,
      previousMaxWeightKg: 100,
      occurredAt: Date(timeIntervalSince1970: 1_768_262_400),
      acknowledgedAt: nil
    )
    let duplicate = PRBreakthroughEvent(
      id: UUID(),
      studentId: studentID,
      exerciseId: first.exerciseId,
      family: .bench,
      setLogId: setLogID,
      pointId: first.pointId,
      breakthroughE1RMKg: first.breakthroughE1RMKg,
      previousMaxE1RMKg: first.previousMaxE1RMKg,
      breakthroughWeightKg: first.breakthroughWeightKg,
      previousMaxWeightKg: first.previousMaxWeightKg,
      occurredAt: first.occurredAt,
      acknowledgedAt: nil
    )

    #expect(
      try await repo.recordPRIfAbsent(first, forSetLogId: setLogID),
      "\(label): first derivation inserts"
    )
    #expect(
      !(try await repo.recordPRIfAbsent(duplicate, forSetLogId: setLogID)),
      "\(label): duplicate derivation is ignored"
    )
    let events = try await repo.prEvents(
      studentId: studentID,
      since: Date(timeIntervalSince1970: 0)
    )
    #expect(events.map(\.id) == [first.id], "\(label)")
  }
}

@Test func weightBaselineUpdateIsPersistentAndStrictlyMonotonic() async throws {
  for (label, repo) in makeRepos() {
    let student = UUID()
    let anchor = Date(timeIntervalSince1970: 1_768_262_400)
    let first = E1RMWeightBaseline(
      studentId: student,
      family: .deadlift,
      maxWeightKg: 220,
      setLogId: UUID(),
      achievedAt: anchor
    )
    let lower = E1RMWeightBaseline(
      studentId: student,
      family: .deadlift,
      maxWeightKg: 215,
      setLogId: UUID(),
      achievedAt: anchor.addingTimeInterval(86_400)
    )
    let higher = E1RMWeightBaseline(
      studentId: student,
      family: .deadlift,
      maxWeightKg: 222.5,
      setLogId: UUID(),
      achievedAt: anchor.addingTimeInterval(2 * 86_400)
    )

    #expect(try await repo.recordWeightBaseline(first) == nil, "\(label)")
    #expect(try await repo.recordWeightBaseline(lower) == first, "\(label)")
    #expect(try await repo.recordWeightBaseline(higher) == first, "\(label)")
    // Advancing writes store the dethroned value alongside the new record.
    let storedHigher = E1RMWeightBaseline(
      studentId: higher.studentId,
      family: higher.family,
      maxWeightKg: higher.maxWeightKg,
      setLogId: higher.setLogId,
      achievedAt: higher.achievedAt,
      previousMaxWeightKg: first.maxWeightKg
    )
    #expect(
      try await repo.fetchWeightBaseline(studentId: student, family: .deadlift) == storedHigher,
      "\(label)"
    )
    #expect(
      try await repo.fetchWeightBaselines(studentId: student) == [storedHigher], "\(label)"
    )
  }
}

@Test func localRepositoryPersistsAcrossInstances() async throws {
  let tempDir = FileManager.default.temporaryDirectory
    .appendingPathComponent("e1rm-persist-\(UUID().uuidString)", isDirectory: true)
  let student = UUID()
  let squat = UUID()

  let first = LocalE1RMRepository(directory: tempDir)
  try await first.recordPoint(point(studentId: student, exerciseId: squat, daysAgo: 1, e1RM: 128))
  let baseline = E1RMWeightBaseline(
    studentId: student,
    family: .squat,
    maxWeightKg: 115,
    setLogId: UUID(),
    achievedAt: Date(timeIntervalSince1970: 1_768_262_400)
  )
  try await first.recordWeightBaseline(baseline)

  let second = LocalE1RMRepository(directory: tempDir)
  let history = try await second.fetchHistory(studentId: student, exerciseId: squat)
  #expect(history.count == 1)
  #expect(history.first?.e1RMKg == 128)
  #expect(
    try await second.fetchWeightBaseline(studentId: student, family: .squat) == baseline
  )
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

@Test func upsertInsertsThenReplacesAcrossExerciseBucketsWithStablePointID() async throws {
  for (label, repo) in makeRepos() {
    let student = UUID()
    let squat = UUID()
    let bench = UUID()
    let setLogID = UUID()
    let imported = point(
      studentId: student,
      exerciseId: squat,
      setLogId: setLogID,
      daysAgo: 2,
      e1RM: 165,
      confidence: .low,
      origin: .imported
    )

    let inserted = try await repo.upsertPoint(imported)
    #expect(inserted == imported, "\(label): a missing identity inserts unchanged")

    let logged = E1RMHistoryPoint(
      id: UUID(),
      studentId: student,
      exerciseId: bench,
      setLogId: setLogID,
      computedAt: imported.computedAt.addingTimeInterval(86_400),
      e1RMKg: 172,
      sourceWeightKg: 145,
      sourceReps: 5,
      sourceRPE: 9,
      confidence: .normal,
      origin: .logged
    )
    let replaced = try await repo.upsertPoint(logged)
    let oldBucket = try await repo.fetchHistory(studentId: student, exerciseId: squat)
    let newBucket = try await repo.fetchHistory(studentId: student, exerciseId: bench)

    #expect(oldBucket.isEmpty, "\(label): replacement moves out of the old exercise bucket")
    #expect(newBucket.count == 1, "\(label): one set-log identity produces one point")
    #expect(replaced.id == inserted.id, "\(label): replacement preserves point identity")
    #expect(newBucket.first == replaced, "\(label): replacement persists the new payload")
    #expect(replaced.origin == .logged, "\(label): a real log replaces imported origin")
    #expect(replaced.confidence == .normal, "\(label): replacement takes new confidence")
  }
}

@Test func updatePointConfidenceChangesOnlyImportedPointsForStudent() async throws {
  for (label, repo) in makeRepos() {
    let student = UUID()
    let otherStudent = UUID()
    let squat = UUID()
    let imported = point(
      studentId: student,
      exerciseId: squat,
      daysAgo: 3,
      e1RM: 160,
      confidence: .low,
      origin: .imported
    )
    let logged = point(
      studentId: student,
      exerciseId: squat,
      daysAgo: 2,
      e1RM: 165,
      confidence: .low
    )
    let otherImported = point(
      studentId: otherStudent,
      exerciseId: squat,
      daysAgo: 1,
      e1RM: 170,
      confidence: .low,
      origin: .imported
    )
    try await repo.recordPoint(imported)
    try await repo.recordPoint(logged)
    try await repo.recordPoint(otherImported)

    try await repo.updatePointConfidence(
      studentId: student,
      pointIDs: [imported.id, logged.id, otherImported.id],
      confidence: .normal
    )

    let history = try await repo.fetchHistory(studentId: student, exerciseId: squat)
    let otherHistory = try await repo.fetchHistory(studentId: otherStudent, exerciseId: squat)
    #expect(history.first(where: { $0.id == imported.id })?.confidence == .normal, "\(label)")
    #expect(history.first(where: { $0.id == logged.id })?.confidence == .low, "\(label)")
    #expect(otherHistory.first?.confidence == .low, "\(label)")
  }
}

@Test func maxBeforeExclusionDropsOnlyImportedPointWithMatchingSetLog() async throws {
  for (label, repo) in makeRepos() {
    let student = UUID()
    let squat = UUID()
    let setLogID = UUID()
    let anchor = Date(timeIntervalSince1970: 1_768_262_400)
    try await repo.recordPoint(
      point(
        studentId: student,
        exerciseId: squat,
        setLogId: setLogID,
        daysAgo: 3,
        e1RM: 200,
        anchor: anchor,
        origin: .imported
      ))
    try await repo.recordPoint(
      point(
        studentId: student,
        exerciseId: squat,
        setLogId: setLogID,
        daysAgo: 2,
        e1RM: 195,
        anchor: anchor
      ))
    try await repo.recordPoint(
      point(studentId: student, exerciseId: squat, daysAgo: 1, e1RM: 190, anchor: anchor))

    let excludingImported = try await repo.maxBefore(
      studentId: student,
      exerciseId: squat,
      before: anchor,
      excludingSetLogId: setLogID
    )
    let explicitNil = try await repo.maxBefore(
      studentId: student,
      exerciseId: squat,
      before: anchor,
      excludingSetLogId: nil
    )
    let convenience = try await repo.maxBefore(
      studentId: student,
      exerciseId: squat,
      before: anchor
    )

    #expect(excludingImported == 195, "\(label): logged point with the same identity still gates")
    #expect(explicitNil == 200, "\(label): nil excludes nothing")
    #expect(convenience == explicitNil, "\(label): convenience overload forwards nil")
  }
}
