import CoreModels
import Foundation
import RepositoryContracts

public actor InMemoryE1RMRepository: E1RMRepository {
  private struct HistoryKey: Hashable {
    let studentId: UUID
    let exerciseId: UUID
  }

  private var points: [HistoryKey: [E1RMHistoryPoint]]
  private var prEvents: [PRBreakthroughEvent]

  public init(
    seedPoints: [E1RMHistoryPoint] = [],
    seedPRs: [PRBreakthroughEvent] = []
  ) {
    var grouped: [HistoryKey: [E1RMHistoryPoint]] = [:]
    for point in seedPoints {
      grouped[HistoryKey(studentId: point.studentId, exerciseId: point.exerciseId), default: []]
        .append(point)
    }
    self.points = grouped
    self.prEvents = seedPRs
  }

  public func recordPoint(_ point: E1RMHistoryPoint) async throws {
    points[HistoryKey(studentId: point.studentId, exerciseId: point.exerciseId), default: []]
      .append(point)
  }

  @discardableResult
  public func upsertPoint(_ point: E1RMHistoryPoint) async throws -> E1RMHistoryPoint {
    let matchingKey = points.keys.first {
      $0.studentId == point.studentId
        && points[$0]?.contains(where: { $0.setLogId == point.setLogId }) == true
    }
    if let matchingKey,
      let index = points[matchingKey]?.firstIndex(where: { $0.setLogId == point.setLogId })
    {
      let existing = points[matchingKey]?[index]
      let replacement = point.replacing(id: existing?.id ?? point.id)
      points[matchingKey]?.remove(at: index)
      points[
        HistoryKey(studentId: replacement.studentId, exerciseId: replacement.exerciseId),
        default: []
      ]
      .append(replacement)
      return replacement
    }
    points[HistoryKey(studentId: point.studentId, exerciseId: point.exerciseId), default: []]
      .append(point)
    return point
  }

  public func updatePointConfidence(
    studentId: UUID,
    pointIDs: Set<UUID>,
    confidence: E1RMConfidence
  ) async throws {
    guard !pointIDs.isEmpty else { return }
    for key in Array(points.keys) {
      guard key.studentId == studentId else { continue }
      points[key] = points[key]?.map { point in
        pointIDs.contains(point.id) && point.origin == .imported
          ? point.replacing(confidence: confidence) : point
      }
    }
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

  public func maxBefore(
    studentId: UUID,
    exerciseId: UUID,
    before: Date,
    excludingSetLogId: UUID?
  ) async throws -> Double? {
    let history = points[HistoryKey(studentId: studentId, exerciseId: exerciseId)] ?? []
    // Spec 050 §5: the PR baseline is the prior *trusted* best — a quarantined
    // (.low) spike must not become the bar the next real PR has to clear.
    // Spec 053 §3: an *imported* point being replaced must not gate its own
    // real-log replacement; a prior logged point under the same set-log
    // identity still gates, so re-checking a set cannot farm duplicate PRs.
    return
      history
      .filter {
        $0.computedAt < before && $0.confidence == .normal
          && !($0.setLogId == excludingSetLogId && $0.origin == .imported)
      }
      .map(\.e1RMKg).max()
  }

  public func recordPR(_ event: PRBreakthroughEvent) async throws {
    prEvents.append(event)
  }

  public func unacknowledgedPRs(studentId: UUID) async throws -> [PRBreakthroughEvent] {
    prEvents
      .filter { $0.studentId == studentId && $0.acknowledgedAt == nil }
      .sorted { $0.occurredAt < $1.occurredAt }
  }

  public func acknowledgePR(eventId: UUID) async throws {
    guard let index = prEvents.firstIndex(where: { $0.id == eventId }) else { return }
    prEvents[index] = prEvents[index].acknowledged(at: Date())
  }
}
