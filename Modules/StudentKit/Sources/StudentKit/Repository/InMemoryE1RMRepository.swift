import CoreModels
import Foundation
import RepositoryContracts

// swiftlint:disable type_body_length
public actor InMemoryE1RMRepository: E1RMRepository {
  private struct HistoryKey: Hashable {
    let studentId: UUID
    let exerciseId: UUID
  }

  private struct WeightBaselineKey: Hashable {
    let studentId: UUID
    let family: LiftFamily
  }

  private var points: [HistoryKey: [E1RMHistoryPoint]]
  private var weightBaselines: [WeightBaselineKey: E1RMWeightBaseline]
  private var storedPREvents: [PRBreakthroughEvent]
  private var revisionByStudentID: [UUID: UInt64] = [:]

  public init(
    seedPoints: [E1RMHistoryPoint] = [],
    seedWeightBaselines: [E1RMWeightBaseline] = [],
    seedPRs: [PRBreakthroughEvent] = []
  ) {
    var grouped: [HistoryKey: [E1RMHistoryPoint]] = [:]
    for point in seedPoints {
      grouped[HistoryKey(studentId: point.studentId, exerciseId: point.exerciseId), default: []]
        .append(point)
    }
    self.points = grouped
    self.weightBaselines = Dictionary(
      seedWeightBaselines.map {
        (WeightBaselineKey(studentId: $0.studentId, family: $0.family), $0)
      },
      uniquingKeysWith: { existing, candidate in
        existing.maxWeightKg >= candidate.maxWeightKg ? existing : candidate
      }
    )
    self.storedPREvents = seedPRs
  }

  public func recordPoint(_ point: E1RMHistoryPoint) async throws {
    points[HistoryKey(studentId: point.studentId, exerciseId: point.exerciseId), default: []]
      .append(point)
    incrementRevision(for: point.studentId)
  }

  @discardableResult
  public func upsertPoint(_ point: E1RMHistoryPoint) async throws -> E1RMHistoryPoint {
    let destinationKey = HistoryKey(studentId: point.studentId, exerciseId: point.exerciseId)
    for key in Array(points.keys) where key.studentId == point.studentId {
      guard let index = points[key]?.firstIndex(where: { $0.setLogId == point.setLogId }),
        let existing = points[key]?[index]
      else { continue }

      let replacement = point.replacing(id: existing.id)
      if key == destinationKey {
        points[key]?[index] = replacement
      } else {
        points[key]?.remove(at: index)
        points[destinationKey, default: []].append(replacement)
      }
      incrementRevision(for: point.studentId)
      return replacement
    }

    points[destinationKey, default: []].append(point)
    incrementRevision(for: point.studentId)
    return point
  }

  public func updatePointConfidence(
    studentId: UUID,
    pointIDs: Set<UUID>,
    confidence: E1RMConfidence
  ) async throws {
    guard !pointIDs.isEmpty else { return }
    for key in Array(points.keys) where key.studentId == studentId {
      points[key] = points[key]?.map { point in
        guard pointIDs.contains(point.id), point.origin == .imported else { return point }
        return point.replacing(confidence: confidence)
      }
    }
    incrementRevision(for: studentId)
  }

  public func replaceHistory(
    studentId: UUID,
    with replacement: [E1RMHistoryPoint],
    weightBaselines replacementBaselines: [E1RMWeightBaseline],
    prEvents replacementPREvents: [PRBreakthroughEvent]
  ) async throws {
    replaceHistoryState(
      studentId: studentId,
      with: replacement,
      weightBaselines: replacementBaselines,
      prEvents: replacementPREvents
    )
    incrementRevision(for: studentId)
  }

  public func historySnapshot(
    studentId: UUID,
    exerciseIds: [UUID]
  ) async throws -> E1RMHistorySnapshot {
    var history: [UUID: [E1RMHistoryPoint]] = [:]
    for exerciseId in exerciseIds {
      history[exerciseId] =
        points[
          HistoryKey(studentId: studentId, exerciseId: exerciseId)
        ] ?? []
    }
    return E1RMHistorySnapshot(
      history: history,
      revision: revisionByStudentID[studentId, default: 0]
    )
  }

  public func replaceHistory(
    studentId: UUID,
    with replacement: [E1RMHistoryPoint],
    weightBaselines replacementBaselines: [E1RMWeightBaseline],
    prEvents replacementPREvents: [PRBreakthroughEvent],
    ifUnchangedSince revision: UInt64
  ) async throws -> Bool {
    guard revisionByStudentID[studentId, default: 0] == revision else { return false }
    replaceHistoryState(
      studentId: studentId,
      with: replacement,
      weightBaselines: replacementBaselines,
      prEvents: replacementPREvents
    )
    incrementRevision(for: studentId)
    return true
  }

  private func replaceHistoryState(
    studentId: UUID,
    with replacement: [E1RMHistoryPoint],
    weightBaselines replacementBaselines: [E1RMWeightBaseline],
    prEvents replacementPREvents: [PRBreakthroughEvent]
  ) {
    points = points.filter { $0.key.studentId != studentId }
    for point in replacement where point.studentId == studentId {
      points[HistoryKey(studentId: point.studentId, exerciseId: point.exerciseId), default: []]
        .append(point)
    }
    weightBaselines = weightBaselines.filter { $0.key.studentId != studentId }
    for baseline in replacementBaselines where baseline.studentId == studentId {
      let key = WeightBaselineKey(studentId: baseline.studentId, family: baseline.family)
      if baseline.maxWeightKg > (weightBaselines[key]?.maxWeightKg ?? -.infinity) {
        weightBaselines[key] = baseline
      }
    }
    storedPREvents =
      storedPREvents.filter { $0.studentId != studentId }
      + replacementPREvents.filter { $0.studentId == studentId }
  }

  public func fetchHistory(studentId: UUID, exerciseId: UUID) async throws -> [E1RMHistoryPoint] {
    (points[HistoryKey(studentId: studentId, exerciseId: exerciseId)] ?? [])
      .sorted { $0.computedAt < $1.computedAt }
  }

  public func fetchHistory(
    studentId: UUID,
    exerciseIds: [UUID]
  ) async throws -> [UUID: [E1RMHistoryPoint]] {
    var result: [UUID: [E1RMHistoryPoint]] = [:]
    for exerciseId in exerciseIds {
      result[exerciseId] = try await fetchHistory(studentId: studentId, exerciseId: exerciseId)
    }
    return result
  }

  public func fetchHistory(
    studentId: UUID,
    family: LiftFamily
  ) async throws -> [E1RMHistoryPoint] {
    points
      .filter { $0.key.studentId == studentId }
      .values
      .flatMap { $0 }
      .filter { $0.family == family }
      .sorted { $0.computedAt < $1.computedAt }
  }

  public func maxBefore(
    studentId: UUID,
    exerciseId: UUID,
    before: Date,
    excludingSetLogId: UUID?
  ) async throws -> Double? {
    let history = points[HistoryKey(studentId: studentId, exerciseId: exerciseId)] ?? []
    return
      history
      .filter {
        $0.computedAt < before && $0.confidence == .normal
          && !($0.setLogId == excludingSetLogId && $0.origin == .imported)
      }
      .map(\.e1RMKg)
      .max()
  }

  @discardableResult
  public func recordWeightBaseline(
    _ candidate: E1RMWeightBaseline
  ) async throws -> E1RMWeightBaseline? {
    let key = WeightBaselineKey(studentId: candidate.studentId, family: candidate.family)
    let previous = weightBaselines[key]
    if candidate.maxWeightKg > (previous?.maxWeightKg ?? -.infinity) {
      weightBaselines[key] = E1RMWeightBaseline(
        studentId: candidate.studentId,
        family: candidate.family,
        maxWeightKg: candidate.maxWeightKg,
        setLogId: candidate.setLogId,
        achievedAt: candidate.achievedAt,
        previousMaxWeightKg: previous?.maxWeightKg ?? candidate.previousMaxWeightKg
      )
      incrementRevision(for: candidate.studentId)
    }
    return previous
  }

  public func fetchWeightBaseline(
    studentId: UUID,
    family: LiftFamily
  ) async throws -> E1RMWeightBaseline? {
    weightBaselines[WeightBaselineKey(studentId: studentId, family: family)]
  }

  public func fetchWeightBaselines(studentId: UUID) async throws -> [E1RMWeightBaseline] {
    weightBaselines
      .filter { $0.key.studentId == studentId }
      .values
      .sorted { $0.family.rawValue < $1.family.rawValue }
  }

  public func recordPR(_ event: PRBreakthroughEvent) async throws {
    storedPREvents.append(event)
    incrementRevision(for: event.studentId)
  }

  @discardableResult
  public func recordPRIfAbsent(
    _ event: PRBreakthroughEvent,
    forSetLogId setLogId: UUID
  ) async throws -> Bool {
    guard event.setLogId == setLogId else { return false }
    guard
      !storedPREvents.contains(where: {
        $0.studentId == event.studentId && $0.setLogId == setLogId
      })
    else { return false }
    storedPREvents.append(event)
    incrementRevision(for: event.studentId)
    return true
  }

  public func prEvents(studentId: UUID, since: Date) async throws -> [PRBreakthroughEvent] {
    storedPREvents
      .filter { $0.studentId == studentId && $0.occurredAt >= since }
      .sorted { $0.occurredAt < $1.occurredAt }
  }

  public func fetchPRs(
    studentId: UUID,
    family: LiftFamily
  ) async throws -> [PRBreakthroughEvent] {
    storedPREvents
      .filter { $0.studentId == studentId && $0.family == family }
      .sorted { $0.occurredAt < $1.occurredAt }
  }

  public func unacknowledgedPRs(studentId: UUID) async throws -> [PRBreakthroughEvent] {
    storedPREvents
      .filter { $0.studentId == studentId && $0.acknowledgedAt == nil }
      .sorted { $0.occurredAt < $1.occurredAt }
  }

  public func acknowledgePR(eventId: UUID) async throws {
    guard let index = storedPREvents.firstIndex(where: { $0.id == eventId }) else { return }
    let studentID = storedPREvents[index].studentId
    storedPREvents[index] = storedPREvents[index].acknowledged(at: Date())
    incrementRevision(for: studentID)
  }

  private func incrementRevision(for studentID: UUID) {
    revisionByStudentID[studentID, default: 0] &+= 1
  }
}
// swiftlint:enable type_body_length
