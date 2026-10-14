import CoreModels
import Foundation
import RepositoryContracts

/// A complete, fresh server ledger can repair a prior source mutation even after process death.
/// Cached and partial Demo/test ledgers are display data and must never imply deletion.
enum StudentAddedLedgerRepair {
  struct SourceSnapshot: Sendable {
    let records: StudentWorkoutLogs
    let revision: UInt64
  }

  static func reconcile(
    source: SourceSnapshot, studentID: UUID, days: [StudentPlanDay], catalog: [Exercise],
    profile: OnboardingProfile? = nil, repository: any E1RMRepository
  ) async throws {
    let records = source.records
    let expectedRevision = source.revision
    guard records.isAuthoritative, records.isCompleteLedger else { return }
    var ids = Set(catalog.map(\.id))
    for family in LiftFamily.allCases {
      ids.formUnion(
        try await repository.fetchHistory(studentId: studentID, family: family).map(\.exerciseId))
    }
    let snapshot = try await repository.historySnapshot(
      studentId: studentID, exerciseIds: Array(ids))
    guard snapshot.revision == expectedRevision else {
      throw StudentAddedDerivedHistory.RepairError.concurrentModification
    }
    let oldPoints = snapshot.history.values.flatMap { $0 }
    let sources = sourceValues(records)
    let kept = oldPoints.filter {
      $0.origin == .imported || sources[$0.setLogId]?.matches($0) == true
    }
    let removedIDs = Set(oldPoints.filter { !kept.contains($0) }.map(\.setLogId))
    let storedEvents = try await repository.prEvents(studentId: studentID, since: .distantPast)
    let events = storedEvents.filter { event in
      guard let id = event.setLogId else { return true }
      return sources[id]?.valid == true && !removedIDs.contains(id)
    }
    let candidates = StudentAddedDerivedHistory.baselines(
      records, days: days, catalog: catalog, profile: profile)
    let baselines = Dictionary(grouping: candidates, by: \.family).values.compactMap {
      $0.max { $0.maxWeightKg < $1.maxWeightKg }
    }
    // Replay privately, then publish once. No stale replay writes can interleave with live saves.
    let replay = InMemoryE1RMRepository(
      seedPoints: kept, seedWeightBaselines: baselines, seedPRs: events)
    await StudentAddedHistory.recordPlanned(
      records.planned, days: days, catalog: catalog, e1rm: replay, profile: profile)
    await StudentAddedHistory.record(
      records.added, catalog: catalog, e1rm: replay, profile: profile)
    let rebuilt = try await replay.historySnapshot(studentId: studentID, exerciseIds: Array(ids))
    guard
      try await repository.replaceHistory(
        studentId: studentID, with: rebuilt.history.values.flatMap { $0 },
        weightBaselines: replay.fetchWeightBaselines(studentId: studentID),
        prEvents: replay.prEvents(studentId: studentID, since: .distantPast),
        ifUnchangedSince: expectedRevision)
    else { throw StudentAddedDerivedHistory.RepairError.concurrentModification }
  }

  private static func sourceValues(_ records: StudentWorkoutLogs) -> [UUID: Source] {
    let planned = records.planned.map { log in
      (
        log.id,
        Source(
          weight: log.weightKg, reps: log.reps, rpe: log.rpe, coachRPE: log.coachRPE,
          valid: log.completed && !log.failed && !log.assumed)
      )
    }
    let added = records.added.map { log in
      (
        log.id,
        Source(
          weight: log.weightKg, reps: log.reps, rpe: log.rpe, coachRPE: log.coachRPE,
          valid: log.completed && !log.failed && !log.assumed)
      )
    }
    return Dictionary(planned + added, uniquingKeysWith: { _, last in last })
  }

  private struct Source {
    let weight: Decimal
    let reps: Int
    let rpe: Decimal?
    let coachRPE: Decimal?
    let valid: Bool

    func matches(_ point: E1RMHistoryPoint) -> Bool {
      valid && point.sourceWeightKg == NSDecimalNumber(decimal: weight).doubleValue
        && point.sourceReps == reps
        && point.sourceRPE == rpe.map { NSDecimalNumber(decimal: $0).doubleValue }
        && point.sourceCoachRPE == coachRPE.map { NSDecimalNumber(decimal: $0).doubleValue }
    }
  }
}
