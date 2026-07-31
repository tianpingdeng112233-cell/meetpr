import CoreModels
import Foundation
import RepositoryContracts

@testable import StudentKit

actor ReconciliationSpyE1RMRepository: E1RMRepository {
  private let backing: InMemoryE1RMRepository
  private var beforeNextConditionalReplace: (@Sendable () async -> Void)?
  private var pausesNextWeightBaseline = false
  private var weightBaselineGateWaiters: [CheckedContinuation<Void, Never>] = []
  private var weightBaselineReachedWaiters: [CheckedContinuation<Void, Never>] = []
  private var pausedWeightBaseline: E1RMWeightBaseline?
  private(set) var conditionalReplaceCallCount = 0
  private(set) var successfulConditionalReplaceCount = 0
  private(set) var mutationCallCount = 0

  init(backing: InMemoryE1RMRepository = InMemoryE1RMRepository()) {
    self.backing = backing
  }

  func runBeforeNextConditionalReplace(
    _ operation: @escaping @Sendable () async -> Void
  ) {
    beforeNextConditionalReplace = operation
  }

  func pauseNextWeightBaseline() {
    pausesNextWeightBaseline = true
  }

  func waitUntilWeightBaselinePaused() async -> E1RMWeightBaseline? {
    if let pausedWeightBaseline { return pausedWeightBaseline }
    await withCheckedContinuation { continuation in
      weightBaselineReachedWaiters.append(continuation)
    }
    return pausedWeightBaseline
  }

  func resumeWeightBaseline() {
    pausesNextWeightBaseline = false
    for waiter in weightBaselineGateWaiters { waiter.resume() }
    weightBaselineGateWaiters = []
  }

  func recordPoint(_ point: E1RMHistoryPoint) async throws {
    mutationCallCount += 1
    try await backing.recordPoint(point)
  }

  func upsertPoint(_ point: E1RMHistoryPoint) async throws -> E1RMHistoryPoint {
    mutationCallCount += 1
    return try await backing.upsertPoint(point)
  }

  func updatePointConfidence(
    studentId: UUID,
    pointIDs: Set<UUID>,
    confidence: E1RMConfidence
  ) async throws {
    mutationCallCount += 1
    try await backing.updatePointConfidence(
      studentId: studentId,
      pointIDs: pointIDs,
      confidence: confidence
    )
  }

  func replaceHistory(
    studentId: UUID,
    with points: [E1RMHistoryPoint],
    weightBaselines: [E1RMWeightBaseline],
    prEvents: [PRBreakthroughEvent]
  ) async throws {
    mutationCallCount += 1
    try await backing.replaceHistory(
      studentId: studentId,
      with: points,
      weightBaselines: weightBaselines,
      prEvents: prEvents
    )
  }

  func historySnapshot(
    studentId: UUID,
    exerciseIds: [UUID]
  ) async throws -> E1RMHistorySnapshot {
    try await backing.historySnapshot(studentId: studentId, exerciseIds: exerciseIds)
  }

  func replaceHistory(
    studentId: UUID,
    with points: [E1RMHistoryPoint],
    weightBaselines: [E1RMWeightBaseline],
    prEvents: [PRBreakthroughEvent],
    ifUnchangedSince revision: UInt64
  ) async throws -> Bool {
    conditionalReplaceCallCount += 1
    let operation = beforeNextConditionalReplace
    beforeNextConditionalReplace = nil
    await operation?()
    let didReplace = try await backing.replaceHistory(
      studentId: studentId,
      with: points,
      weightBaselines: weightBaselines,
      prEvents: prEvents,
      ifUnchangedSince: revision
    )
    if didReplace {
      successfulConditionalReplaceCount += 1
      mutationCallCount += 1
    }
    return didReplace
  }

  func fetchHistory(
    studentId: UUID,
    exerciseId: UUID
  ) async throws -> [E1RMHistoryPoint] {
    try await backing.fetchHistory(studentId: studentId, exerciseId: exerciseId)
  }

  func fetchHistory(
    studentId: UUID,
    exerciseIds: [UUID]
  ) async throws -> [UUID: [E1RMHistoryPoint]] {
    try await backing.fetchHistory(studentId: studentId, exerciseIds: exerciseIds)
  }

  func fetchHistory(
    studentId: UUID,
    family: LiftFamily
  ) async throws -> [E1RMHistoryPoint] {
    try await backing.fetchHistory(studentId: studentId, family: family)
  }

  func maxBefore(
    studentId: UUID,
    exerciseId: UUID,
    before: Date,
    excludingSetLogId: UUID?
  ) async throws -> Double? {
    try await backing.maxBefore(
      studentId: studentId,
      exerciseId: exerciseId,
      before: before,
      excludingSetLogId: excludingSetLogId
    )
  }

  func recordWeightBaseline(
    _ candidate: E1RMWeightBaseline
  ) async throws -> E1RMWeightBaseline? {
    mutationCallCount += 1
    if pausesNextWeightBaseline {
      pausedWeightBaseline = candidate
      for waiter in weightBaselineReachedWaiters { waiter.resume() }
      weightBaselineReachedWaiters = []
      await withCheckedContinuation { continuation in
        weightBaselineGateWaiters.append(continuation)
      }
    }
    return try await backing.recordWeightBaseline(candidate)
  }

  func fetchWeightBaseline(
    studentId: UUID,
    family: LiftFamily
  ) async throws -> E1RMWeightBaseline? {
    try await backing.fetchWeightBaseline(studentId: studentId, family: family)
  }

  func fetchWeightBaselines(studentId: UUID) async throws -> [E1RMWeightBaseline] {
    try await backing.fetchWeightBaselines(studentId: studentId)
  }

  func recordPR(_ event: PRBreakthroughEvent) async throws {
    mutationCallCount += 1
    try await backing.recordPR(event)
  }

  func recordPRIfAbsent(
    _ event: PRBreakthroughEvent,
    forSetLogId setLogId: UUID
  ) async throws -> Bool {
    mutationCallCount += 1
    return try await backing.recordPRIfAbsent(event, forSetLogId: setLogId)
  }

  func fetchPRs(
    studentId: UUID,
    family: LiftFamily
  ) async throws -> [PRBreakthroughEvent] {
    try await backing.fetchPRs(studentId: studentId, family: family)
  }

  func unacknowledgedPRs(studentId: UUID) async throws -> [PRBreakthroughEvent] {
    try await backing.unacknowledgedPRs(studentId: studentId)
  }

  func acknowledgePR(eventId: UUID) async throws {
    mutationCallCount += 1
    try await backing.acknowledgePR(eventId: eventId)
  }

  func prEvents(studentId: UUID, since: Date) async throws -> [PRBreakthroughEvent] {
    try await backing.prEvents(studentId: studentId, since: since)
  }
}
