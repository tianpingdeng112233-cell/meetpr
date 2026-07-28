import CoreModels
import Foundation
import RepositoryContracts

public actor InMemoryE1RMRepository: E1RMRepository {
  private struct HistoryKey: Hashable {
    let studentId: UUID
    let exerciseId: UUID
  }

  private var points: [HistoryKey: [E1RMHistoryPoint]]
  private var storedPREvents: [PRBreakthroughEvent]

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
    self.storedPREvents = seedPRs
  }

  public func recordPoint(_ point: E1RMHistoryPoint) async throws {
    points[HistoryKey(studentId: point.studentId, exerciseId: point.exerciseId), default: []]
      .append(point)
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
      return replacement
    }

    points[destinationKey, default: []].append(point)
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
  }

  public func replaceHistory(studentId: UUID, with replacement: [E1RMHistoryPoint]) async throws {
    points = points.filter { $0.key.studentId != studentId }
    for point in replacement where point.studentId == studentId {
      points[HistoryKey(studentId: point.studentId, exerciseId: point.exerciseId), default: []]
        .append(point)
    }
    storedPREvents.removeAll { $0.studentId == studentId }
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
    return
      history
      .filter {
        $0.computedAt < before && $0.confidence == .normal
          && !($0.setLogId == excludingSetLogId && $0.origin == .imported)
      }
      .map(\.e1RMKg)
      .max()
  }

  public func recordPR(_ event: PRBreakthroughEvent) async throws {
    storedPREvents.append(event)
  }

  public func prEvents(studentId: UUID, since: Date) async throws -> [PRBreakthroughEvent] {
    storedPREvents
      .filter { $0.studentId == studentId && $0.occurredAt >= since }
      .sorted { $0.occurredAt < $1.occurredAt }
  }

  public func unacknowledgedPRs(studentId: UUID) async throws -> [PRBreakthroughEvent] {
    storedPREvents
      .filter { $0.studentId == studentId && $0.acknowledgedAt == nil }
      .sorted { $0.occurredAt < $1.occurredAt }
  }

  public func acknowledgePR(eventId: UUID) async throws {
    guard let index = storedPREvents.firstIndex(where: { $0.id == eventId }) else { return }
    storedPREvents[index] = storedPREvents[index].acknowledged(at: Date())
  }
}
