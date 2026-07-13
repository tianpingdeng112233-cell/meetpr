import CoreModels
import Foundation
import RepositoryContracts

/// File-backed e1RM store (spec 028 + 026 persistence ladder: in-memory →
/// JSON file under Documents/e1rm/). Backend stays uninvolved in V0.1; the
/// history survives relaunches but not device changes.
public actor LocalE1RMRepository: E1RMRepository {
  private let directory: URL
  private var cachedPoints: [E1RMHistoryPoint]?
  private var cachedPRs: [PRBreakthroughEvent]?

  private let encoder: JSONEncoder
  private let decoder: JSONDecoder

  public init(directory: URL? = nil) {
    let base =
      directory
      ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("e1rm", isDirectory: true)
    self.directory = base
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.sortedKeys]
    self.encoder = encoder
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    self.decoder = decoder
  }

  // MARK: - E1RMRepository

  public func recordPoint(_ point: E1RMHistoryPoint) async throws {
    var all = try loadPoints()
    all.append(point)
    try save(points: all)
  }

  public func replaceHistory(studentId: UUID, with replacement: [E1RMHistoryPoint]) async throws {
    let retainedPoints = try loadPoints().filter { $0.studentId != studentId }
    let retainedPRs = try loadPRs().filter { $0.studentId != studentId }
    try save(points: retainedPoints + replacement.filter { $0.studentId == studentId })
    try save(prs: retainedPRs)
  }

  public func fetchHistory(studentId: UUID, exerciseId: UUID) async throws -> [E1RMHistoryPoint] {
    try loadPoints()
      .filter { $0.studentId == studentId && $0.exerciseId == exerciseId }
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
    before: Date
  ) async throws -> Double? {
    try loadPoints()
      .filter {
        $0.studentId == studentId && $0.exerciseId == exerciseId
          && $0.computedAt < before && $0.confidence == .normal
      }
      .map(\.e1RMKg).max()
  }

  public func recordPR(_ event: PRBreakthroughEvent) async throws {
    var all = try loadPRs()
    all.append(event)
    try save(prs: all)
  }

  public func unacknowledgedPRs(studentId: UUID) async throws -> [PRBreakthroughEvent] {
    try loadPRs()
      .filter { $0.studentId == studentId && $0.acknowledgedAt == nil }
      .sorted { $0.occurredAt < $1.occurredAt }
  }

  public func acknowledgePR(eventId: UUID) async throws {
    var all = try loadPRs()
    guard let index = all.firstIndex(where: { $0.id == eventId }) else { return }
    all[index] = all[index].acknowledged(at: Date())
    try save(prs: all)
  }

  // MARK: - File IO

  private var pointsURL: URL { directory.appendingPathComponent("points.json") }
  private var prsURL: URL { directory.appendingPathComponent("prs.json") }

  // Missing file = genuinely empty history. Read/decode failures must throw:
  // mapping them to [] silently erases history and fakes first-PR detection,
  // and the next save would overwrite the real data (Codex review P1).
  private func loadPoints() throws -> [E1RMHistoryPoint] {
    if let cachedPoints { return cachedPoints }
    guard FileManager.default.fileExists(atPath: pointsURL.path) else {
      cachedPoints = []
      return []
    }
    let loaded = try decoder.decode([E1RMHistoryPoint].self, from: Data(contentsOf: pointsURL))
    cachedPoints = loaded
    return loaded
  }

  private func loadPRs() throws -> [PRBreakthroughEvent] {
    if let cachedPRs { return cachedPRs }
    guard FileManager.default.fileExists(atPath: prsURL.path) else {
      cachedPRs = []
      return []
    }
    let loaded = try decoder.decode([PRBreakthroughEvent].self, from: Data(contentsOf: prsURL))
    cachedPRs = loaded
    return loaded
  }

  private func save(points: [E1RMHistoryPoint]) throws {
    cachedPoints = points
    try ensureDirectory()
    try encoder.encode(points).write(to: pointsURL, options: .atomic)
  }

  private func save(prs: [PRBreakthroughEvent]) throws {
    cachedPRs = prs
    try ensureDirectory()
    try encoder.encode(prs).write(to: prsURL, options: .atomic)
  }

  private func ensureDirectory() throws {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  }
}
