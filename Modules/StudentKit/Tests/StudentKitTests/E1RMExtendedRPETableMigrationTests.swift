import CoreModels
import Foundation
import Testing

@testable import StudentKit

@Test(arguments: [(nil, nil), (5.5, nil), (8.0, 5.5)] as [(Double?, Double?)])
func extendedTableMigrationPreservesPointsOutsideTable(rpe: Double?, coachRPE: Double?) async throws
{
  let fixture = ExtendedTableFixture()
  defer { try? FileManager.default.removeItem(at: fixture.directory) }
  let repository = LocalE1RMRepository(directory: fixture.directory)
  let point = E1RMHistoryPoint(
    id: UUID(), studentId: fixture.studentID, exerciseId: fixture.exerciseID,
    setLogId: UUID(), computedAt: fixture.date, e1RMKg: 70, sourceWeightKg: 70,
    sourceReps: 1, sourceRPE: rpe, sourceCoachRPE: coachRPE, origin: .imported)
  try await repository.recordPoint(point)

  try await E1RMExtendedRPETableMigration(e1rm: repository, marker: InMemoryE1RMMigrationStore())
    .runIfNeeded(studentID: fixture.studentID)

  let reloaded = LocalE1RMRepository(directory: fixture.directory)
  let history = try await reloaded.fetchHistory(
    studentId: fixture.studentID, exerciseId: fixture.exerciseID)
  #expect(history == [point])
}

@Test(arguments: [(6.0, 100 / 0.762), (10.0, 100 / 0.863)])
func extendedTableMigrationRecalculatesInclusiveRPEBoundaries(rpe: Double, expected: Double)
  async throws
{
  let fixture = ExtendedTableFixture()
  defer { try? FileManager.default.removeItem(at: fixture.directory) }
  let repository = LocalE1RMRepository(directory: fixture.directory)
  try await repository.recordPoint(fixture.point(rpe: rpe))

  try await E1RMExtendedRPETableMigration(e1rm: repository, marker: InMemoryE1RMMigrationStore())
    .runIfNeeded(studentID: fixture.studentID)

  let reloaded = LocalE1RMRepository(directory: fixture.directory)
  let point = try #require(
    try await reloaded.fetchHistory(studentId: fixture.studentID, exerciseId: fixture.exerciseID)
      .first)
  #expect(abs(point.e1RMKg - expected) < 1e-10)
}

@Test func extendedTableMigrationOnlyRecalculatesE1RM() async throws {
  let fixture = ExtendedTableFixture()
  defer { try? FileManager.default.removeItem(at: fixture.directory) }
  let repository = LocalE1RMRepository(directory: fixture.directory)
  let points = [
    fixture.point(),
    fixture.point(origin: .imported, confidence: .low, coachRPE: 9),
    fixture.point(rpe: nil),
    fixture.point(rpe: 10.5),
  ]
  for point in points { try await repository.recordPoint(point) }
  let baseline = E1RMWeightBaseline(
    studentId: fixture.studentID, family: .bench, maxWeightKg: 100,
    setLogId: points[0].setLogId, achievedAt: fixture.date)
  try await repository.recordWeightBaseline(baseline)
  let event = PRBreakthroughEvent(
    id: UUID(), studentId: fixture.studentID, exerciseId: fixture.exerciseID,
    pointId: points[0].id, breakthroughE1RMKg: 128.205, previousMaxE1RMKg: 120,
    occurredAt: fixture.date, acknowledgedAt: fixture.date)
  try await repository.recordPR(event)
  let marker = InMemoryE1RMMigrationStore()
  let migration = E1RMExtendedRPETableMigration(e1rm: repository, marker: marker)
  let before = try fixture.storedFields()

  try await migration.runIfNeeded(studentID: fixture.studentID)

  let migrated = try await repository.fetchHistory(
    studentId: fixture.studentID, exerciseId: fixture.exerciseID)
  let byID = Dictionary(uniqueKeysWithValues: migrated.map { ($0.id, $0) })
  for (point, expected) in zip(points, [100 / 0.811, 100 / 0.837, 128.205, 128.205]) {
    let actual = try #require(byID[point.id])
    #expect(abs(actual.e1RMKg - expected) < 1e-10)
  }
  #expect(try fixture.storedFields() == before)
  #expect(await marker.isCompleted(studentID: fixture.studentID))
}

@Test func extendedTableMigrationFeedsPercentageAndRPEPrescriptions() async throws {
  let fixture = ExtendedTableFixture()
  defer { try? FileManager.default.removeItem(at: fixture.directory) }
  let repository = LocalE1RMRepository(directory: fixture.directory)
  try await repository.recordPoint(fixture.point())
  try await E1RMExtendedRPETableMigration(e1rm: repository, marker: InMemoryE1RMMigrationStore())
    .runIfNeeded(studentID: fixture.studentID)
  let point = try #require(
    try await repository.fetchHistory(studentId: fixture.studentID, exerciseId: fixture.exerciseID)
      .first)
  let percentage = PctAnchorResolver.resolve(
    .init(
      percentage: 80, anchor: .e1RM, exerciseFamily: .bench, registeredOneRMKg: 150,
      currentE1RMKg: point.e1RMKg, exerciseID: fixture.exerciseID,
      planExerciseSortOrder: 0, sameDaySets: []))
  #expect(percentage.resolvedKg == 97.5)
  let roundTrip = try #require(
    E1RMCalculator.suggestedWeight(e1RM: point.e1RMKg, reps: 5, rpe: 8))
  #expect(SetWeightSuggestionRounding.roundedDownToPlateStep(roundTrip) == 100)
  let twoReps = try #require(
    E1RMCalculator.suggestedWeight(e1RM: 123.3, reps: 2, rpe: 9))
  #expect(SetWeightSuggestionRounding.roundedDownToPlateStep(twoReps) == 112.5)
}

@Test func extendedTableMigrationSkipsCompletedStudentAfterRelaunch() async throws {
  let fixture = ExtendedTableFixture()
  defer { try? FileManager.default.removeItem(at: fixture.directory) }
  let repository = LocalE1RMRepository(directory: fixture.directory)
  try await repository.recordPoint(fixture.point())
  let marker = InMemoryE1RMMigrationStore()
  try await E1RMExtendedRPETableMigration(e1rm: repository, marker: marker)
    .runIfNeeded(studentID: fixture.studentID)
  let url = fixture.directory.appending(path: "state.json")
  let before = try Data(contentsOf: url)
  try FileManager.default.setAttributes([.modificationDate: fixture.date], ofItemAtPath: url.path)

  try await E1RMExtendedRPETableMigration(
    e1rm: LocalE1RMRepository(directory: fixture.directory), marker: marker
  ).runIfNeeded(studentID: fixture.studentID)

  #expect(try Data(contentsOf: url) == before)
  let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
  #expect(attributes[.modificationDate] as? Date == fixture.date)
}

@Test func extendedTableMigrationCancellationLeavesHistoryRetryable() async throws {
  let fixture = ExtendedTableFixture()
  defer { try? FileManager.default.removeItem(at: fixture.directory) }
  let repository = LocalE1RMRepository(directory: fixture.directory)
  try await repository.recordPoint(fixture.point())
  let marker = InMemoryE1RMMigrationStore()
  let migration = E1RMExtendedRPETableMigration(e1rm: repository, marker: marker)
  let before = try Data(contentsOf: fixture.directory.appending(path: "state.json"))
  let cancelled = Task {
    withUnsafeCurrentTask { $0?.cancel() }
    try await migration.runIfNeeded(studentID: fixture.studentID)
  }
  await #expect(throws: CancellationError.self) { try await cancelled.value }
  #expect(!(await marker.isCompleted(studentID: fixture.studentID)))
  #expect(try Data(contentsOf: fixture.directory.appending(path: "state.json")) == before)
  try await migration.runIfNeeded(studentID: fixture.studentID)
  #expect(await marker.isCompleted(studentID: fixture.studentID))
}

@Test func extendedTableMigrationCanReplayAfterSaveWithoutCompletionMarker() async throws {
  let fixture = ExtendedTableFixture()
  defer { try? FileManager.default.removeItem(at: fixture.directory) }
  let repository = LocalE1RMRepository(directory: fixture.directory)
  try await repository.recordPoint(fixture.point(origin: .imported, coachRPE: 9))
  // Model process loss after atomic replacement but before persisting completion.
  try await E1RMExtendedRPETableMigration(e1rm: repository, marker: UnpersistedMigrationMarker())
    .runIfNeeded(studentID: fixture.studentID)
  let once = try Data(contentsOf: fixture.directory.appending(path: "state.json"))
  let restarted = LocalE1RMRepository(directory: fixture.directory)
  let marker = InMemoryE1RMMigrationStore()

  try await E1RMExtendedRPETableMigration(e1rm: restarted, marker: marker)
    .runIfNeeded(studentID: fixture.studentID)

  #expect(try Data(contentsOf: fixture.directory.appending(path: "state.json")) == once)
  #expect(await marker.isCompleted(studentID: fixture.studentID))
}

@Test func extendedTableMigrationPreservesConcurrentRecordsAndOtherStudents() async throws {
  let fixture = ExtendedTableFixture()
  defer { try? FileManager.default.removeItem(at: fixture.directory) }
  let repository = LocalE1RMRepository(directory: fixture.directory)
  let oldPoint = fixture.point()
  let other = ExtendedTableFixture().point()
  try await repository.recordPoint(oldPoint)
  try await repository.recordPoint(other)
  let migration = E1RMExtendedRPETableMigration(
    e1rm: repository, marker: InMemoryE1RMMigrationStore())
  let newPoints = (0..<30).map { _ in
    E1RMHistoryPoint(
      id: UUID(), studentId: fixture.studentID, exerciseId: fixture.exerciseID,
      setLogId: UUID(), computedAt: fixture.date.addingTimeInterval(1),
      e1RMKg: 100, sourceWeightKg: 100, sourceReps: 1, sourceRPE: 10)
  }

  try await withThrowingTaskGroup(of: Void.self) { group in
    group.addTask { try await migration.runIfNeeded(studentID: fixture.studentID) }
    for point in newPoints { group.addTask { try await repository.recordPoint(point) } }
    try await group.waitForAll()
  }

  let reloaded = LocalE1RMRepository(directory: fixture.directory)
  let history = try await reloaded.fetchHistory(
    studentId: fixture.studentID, exerciseId: fixture.exerciseID)
  #expect(Set(history.map(\.id)) == Set([oldPoint.id] + newPoints.map(\.id)))
  #expect(Set(history.filter { $0.id != oldPoint.id }) == Set(newPoints))
  #expect(
    try await reloaded.fetchHistory(studentId: other.studentId, exerciseId: other.exerciseId)
      == [other])
}

@Test(arguments: ["state.json", "points.json", "prs.json"])
func extendedTableMigrationDoesNotOverwriteUnreadableStorage(fileName: String) async throws {
  let fixture = ExtendedTableFixture()
  defer { try? FileManager.default.removeItem(at: fixture.directory) }
  try FileManager.default.createDirectory(at: fixture.directory, withIntermediateDirectories: true)
  let url = fixture.directory.appending(path: fileName)
  let corrupt = Data("unreadable history".utf8)
  try corrupt.write(to: url)
  let marker = InMemoryE1RMMigrationStore()
  let migration = E1RMExtendedRPETableMigration(
    e1rm: LocalE1RMRepository(directory: fixture.directory), marker: marker)

  await #expect(throws: (any Error).self) {
    try await migration.runIfNeeded(studentID: fixture.studentID)
  }
  #expect(try Data(contentsOf: url) == corrupt)
  #expect(!(await marker.isCompleted(studentID: fixture.studentID)))
  if fileName != "state.json" {
    #expect(
      !FileManager.default.fileExists(atPath: fixture.directory.appending(path: "state.json").path))
  }
}

@Test func extendedTableMigrationFailedSaveLeavesOldStateAndCanRetry() async throws {
  let fixture = ExtendedTableFixture()
  defer { try? FileManager.default.removeItem(at: fixture.directory) }
  let repository = LocalE1RMRepository(directory: fixture.directory)
  let point = fixture.point()
  try await repository.recordPoint(point)
  let url = fixture.directory.appending(path: "state.json")
  let original = try Data(contentsOf: url)
  try FileManager.default.removeItem(at: url)
  try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
  let marker = InMemoryE1RMMigrationStore()
  let migration = E1RMExtendedRPETableMigration(e1rm: repository, marker: marker)

  await #expect(throws: (any Error).self) {
    try await migration.runIfNeeded(studentID: fixture.studentID)
  }
  #expect(!(await marker.isCompleted(studentID: fixture.studentID)))
  #expect(
    try await repository.fetchHistory(studentId: fixture.studentID, exerciseId: fixture.exerciseID)
      == [point])
  try FileManager.default.removeItem(at: url)
  try original.write(to: url)
  try await migration.runIfNeeded(studentID: fixture.studentID)
  #expect(await marker.isCompleted(studentID: fixture.studentID))
}

private actor UnpersistedMigrationMarker: E1RMMigrationStoring {
  func isCompleted(studentID: UUID) -> Bool { false }
  func markCompleted(studentID: UUID) {}
}

@Test func extendedTableStartupPreservesReadOnlyFallbackWhenStorageIsUnreadable() async throws {
  let fixture = ExtendedTableFixture()
  defer { try? FileManager.default.removeItem(at: fixture.directory) }
  try FileManager.default.createDirectory(at: fixture.directory, withIntermediateDirectories: true)
  let url = fixture.directory.appending(path: "state.json")
  let corrupt = Data("unreadable history".utf8)
  try corrupt.write(to: url)
  let oldMarker = InMemoryE1RMMigrationStore()
  await oldMarker.markCompleted(studentID: fixture.studentID)
  let startup = E1RMCompetitionLiftMigration(
    logs: InMemoryStudentTrainingLogRepository(),
    onboarding: InMemoryOnboardingRepository(studentId: fixture.studentID),
    plans: InMemoryStudentPlanRepository(store: TestStudentPlanStore()),
    catalogReader: nil, e1rm: LocalE1RMRepository(directory: fixture.directory), marker: oldMarker)

  let result = try await startup.runIfNeeded(studentID: fixture.studentID)

  #expect(!result.didRun)
  #expect(try Data(contentsOf: url) == corrupt)
}

@Test func extendedTableMigrationUsesIndependentVersionedStudentMarkers() async throws {
  let fixture = ExtendedTableFixture()
  let other = ExtendedTableFixture().point()
  let key = "e1rm-migration.e1rm-extended-rpe-table-v1.\(fixture.studentID.uuidString.lowercased())"
  let otherKey =
    "e1rm-migration.e1rm-extended-rpe-table-v1.\(other.studentId.uuidString.lowercased())"
  let oldKey =
    "e1rm-migration.coach-rpe-low-rpe-replay-v2.\(fixture.studentID.uuidString.lowercased())"
  defer {
    try? FileManager.default.removeItem(at: fixture.directory)
    for markerKey in [key, otherKey, oldKey] {
      UserDefaults.standard.removeObject(forKey: markerKey)
    }
  }
  UserDefaults.standard.set(true, forKey: oldKey)
  let repository = LocalE1RMRepository(directory: fixture.directory)
  try await repository.recordPoint(fixture.point())
  try await repository.recordPoint(other)

  try await E1RMExtendedRPETableMigration(e1rm: repository).runIfNeeded(
    studentID: fixture.studentID)

  #expect(UserDefaults.standard.bool(forKey: key))
  #expect(UserDefaults.standard.bool(forKey: oldKey))
  #expect(!UserDefaults.standard.bool(forKey: otherKey))
  try await E1RMExtendedRPETableMigration(
    e1rm: LocalE1RMRepository(directory: fixture.directory)
  ).runIfNeeded(studentID: other.studentId)
  #expect(UserDefaults.standard.bool(forKey: otherKey))
}

private struct ExtendedTableFixture {
  let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
  let studentID = UUID()
  let exerciseID = UUID()
  let date = Date(timeIntervalSince1970: 1_780_000_000)

  func point(
    origin: E1RMPointOrigin = .logged,
    confidence: E1RMConfidence = .normal,
    rpe: Double? = 8,
    coachRPE: Double? = nil
  ) -> E1RMHistoryPoint {
    E1RMHistoryPoint(
      id: UUID(), studentId: studentID, exerciseId: exerciseID, family: nil,
      setLogId: UUID(), computedAt: date, e1RMKg: 128.205, sourceWeightKg: 100,
      sourceReps: 5, sourceRPE: rpe, sourceCoachRPE: coachRPE,
      confidence: confidence, origin: origin)
  }

  /// Compare canonical bytes for every stored field except the recalculated value.
  func storedFields() throws -> Data {
    let data = try Data(contentsOf: directory.appending(path: "state.json"))
    var json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    var points = try #require(json["points"] as? [[String: Any]])
    for index in points.indices { points[index].removeValue(forKey: "e1RMKg") }
    json["points"] = points
    return try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])
  }
}
