import CoreModels
import Foundation
import RepositoryContracts

// swiftlint:disable type_body_length
/// File-backed e1RM store (spec 028 + 026 persistence ladder: in-memory →
/// JSON file under Documents/e1rm/). Backend stays uninvolved in V0.1; the
/// history survives relaunches but not device changes.
public actor LocalE1RMRepository: E1RMRepository {
  private struct StorageState: Codable {
    var points: [E1RMHistoryPoint]
    var weightBaselines: [E1RMWeightBaseline]
    var prEvents: [PRBreakthroughEvent]

    init(
      points: [E1RMHistoryPoint] = [],
      weightBaselines: [E1RMWeightBaseline] = [],
      prEvents: [PRBreakthroughEvent] = []
    ) {
      self.points = points
      self.weightBaselines = weightBaselines
      self.prEvents = prEvents
    }

    init(from decoder: any Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      points = try container.decodeIfPresent([E1RMHistoryPoint].self, forKey: .points) ?? []
      weightBaselines =
        try container.decodeIfPresent(
          [E1RMWeightBaseline].self,
          forKey: .weightBaselines
        ) ?? []
      prEvents =
        try container.decodeIfPresent([PRBreakthroughEvent].self, forKey: .prEvents) ?? []
    }
  }

  private let directory: URL
  private var cachedState: StorageState?
  private var revisionByStudentID: [UUID: UInt64] = [:]

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
    var state = try loadState()
    state.points.append(point)
    try save(state)
    incrementRevision(for: point.studentId)
  }

  @discardableResult
  public func upsertPoint(_ point: E1RMHistoryPoint) async throws -> E1RMHistoryPoint {
    var state = try loadState()
    if let index = state.points.firstIndex(where: {
      $0.studentId == point.studentId && $0.setLogId == point.setLogId
    }) {
      let replacement = point.replacing(id: state.points[index].id)
      state.points[index] = replacement
      try save(state)
      incrementRevision(for: point.studentId)
      return replacement
    }

    state.points.append(point)
    try save(state)
    incrementRevision(for: point.studentId)
    return point
  }

  public func updatePointConfidence(
    studentId: UUID,
    pointIDs: Set<UUID>,
    confidence: E1RMConfidence
  ) async throws {
    guard !pointIDs.isEmpty else { return }
    var state = try loadState()
    var didChange = false
    for index in state.points.indices
    where state.points[index].studentId == studentId
      && pointIDs.contains(state.points[index].id)
    {
      guard
        state.points[index].origin == .imported,
        state.points[index].confidence != confidence
      else { continue }
      state.points[index] = state.points[index].replacing(confidence: confidence)
      didChange = true
    }
    if didChange {
      try save(state)
      incrementRevision(for: studentId)
    }
  }

  public func replaceHistory(
    studentId: UUID,
    with replacement: [E1RMHistoryPoint],
    weightBaselines replacementBaselines: [E1RMWeightBaseline],
    prEvents replacementPREvents: [PRBreakthroughEvent]
  ) async throws {
    var state = try loadState()
    Self.replaceHistoryState(
      &state,
      studentId: studentId,
      with: replacement,
      weightBaselines: replacementBaselines,
      prEvents: replacementPREvents
    )
    try save(state)
    incrementRevision(for: studentId)
  }

  public func historySnapshot(
    studentId: UUID,
    exerciseIds: [UUID]
  ) async throws -> E1RMHistorySnapshot {
    let exerciseIDSet = Set(exerciseIds)
    let points = try loadState().points.filter {
      $0.studentId == studentId && exerciseIDSet.contains($0.exerciseId)
    }
    return E1RMHistorySnapshot(
      history: Dictionary(grouping: points, by: \.exerciseId),
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
    var state = try loadState()
    Self.replaceHistoryState(
      &state,
      studentId: studentId,
      with: replacement,
      weightBaselines: replacementBaselines,
      prEvents: replacementPREvents
    )
    try save(state)
    incrementRevision(for: studentId)
    return true
  }

  public func fetchHistory(studentId: UUID, exerciseId: UUID) async throws -> [E1RMHistoryPoint] {
    try loadState().points
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

  public func fetchHistory(
    studentId: UUID,
    family: LiftFamily
  ) async throws -> [E1RMHistoryPoint] {
    try loadState().points
      .filter { $0.studentId == studentId && $0.family == family }
      .sorted { $0.computedAt < $1.computedAt }
  }

  public func maxBefore(
    studentId: UUID,
    exerciseId: UUID,
    before: Date,
    excludingSetLogId: UUID?
  ) async throws -> Double? {
    try loadState().points
      .filter {
        $0.studentId == studentId && $0.exerciseId == exerciseId
          && $0.computedAt < before && $0.confidence == .normal
          && !($0.setLogId == excludingSetLogId && $0.origin == .imported)
      }
      .map(\.e1RMKg).max()
  }

  @discardableResult
  public func recordWeightBaseline(
    _ candidate: E1RMWeightBaseline
  ) async throws -> E1RMWeightBaseline? {
    var state = try loadState()
    let previous = state.weightBaselines.first {
      $0.studentId == candidate.studentId && $0.family == candidate.family
    }
    guard candidate.maxWeightKg > (previous?.maxWeightKg ?? -.infinity) else {
      return previous
    }
    state.weightBaselines.removeAll {
      $0.studentId == candidate.studentId && $0.family == candidate.family
    }
    state.weightBaselines.append(
      E1RMWeightBaseline(
        studentId: candidate.studentId,
        family: candidate.family,
        maxWeightKg: candidate.maxWeightKg,
        setLogId: candidate.setLogId,
        achievedAt: candidate.achievedAt,
        previousMaxWeightKg: previous?.maxWeightKg ?? candidate.previousMaxWeightKg
      )
    )
    try save(state)
    incrementRevision(for: candidate.studentId)
    return previous
  }

  public func fetchWeightBaseline(
    studentId: UUID,
    family: LiftFamily
  ) async throws -> E1RMWeightBaseline? {
    try loadState().weightBaselines.first {
      $0.studentId == studentId && $0.family == family
    }
  }

  public func fetchWeightBaselines(studentId: UUID) async throws -> [E1RMWeightBaseline] {
    try loadState().weightBaselines
      .filter { $0.studentId == studentId }
      .sorted { $0.family.rawValue < $1.family.rawValue }
  }

  public func recordPR(_ event: PRBreakthroughEvent) async throws {
    var state = try loadState()
    state.prEvents.append(event)
    try save(state)
    incrementRevision(for: event.studentId)
  }

  @discardableResult
  public func recordPRIfAbsent(
    _ event: PRBreakthroughEvent,
    forSetLogId setLogId: UUID
  ) async throws -> Bool {
    guard event.setLogId == setLogId else { return false }
    var state = try loadState()
    guard
      !state.prEvents.contains(where: {
        $0.studentId == event.studentId && $0.setLogId == setLogId
      })
    else { return false }
    state.prEvents.append(event)
    try save(state)
    incrementRevision(for: event.studentId)
    return true
  }

  public func fetchPRs(
    studentId: UUID,
    family: LiftFamily
  ) async throws -> [PRBreakthroughEvent] {
    try loadState().prEvents
      .filter { $0.studentId == studentId && $0.family == family }
      .sorted { $0.occurredAt < $1.occurredAt }
  }

  public func prEvents(studentId: UUID, since: Date) async throws -> [PRBreakthroughEvent] {
    // The release line added this reader against the old split-file store; #286
    // collapsed persistence into one atomic state.json, so it reads state now.
    try loadState().prEvents
      .filter { $0.studentId == studentId && $0.occurredAt >= since }
      .sorted { $0.occurredAt < $1.occurredAt }
  }

  public func unacknowledgedPRs(studentId: UUID) async throws -> [PRBreakthroughEvent] {
    try loadState().prEvents
      .filter { $0.studentId == studentId && $0.acknowledgedAt == nil }
      .sorted { $0.occurredAt < $1.occurredAt }
  }

  public func acknowledgePR(eventId: UUID) async throws {
    var state = try loadState()
    guard let index = state.prEvents.firstIndex(where: { $0.id == eventId }) else { return }
    let studentID = state.prEvents[index].studentId
    state.prEvents[index] = state.prEvents[index].acknowledged(at: Date())
    try save(state)
    incrementRevision(for: studentID)
  }

  // MARK: - File IO

  private var stateURL: URL { directory.appendingPathComponent("state.json") }
  private var pointsURL: URL { directory.appendingPathComponent("points.json") }
  private var prsURL: URL { directory.appendingPathComponent("prs.json") }

  /// A single state file makes migration replacement atomic across points,
  /// weight baselines, and PR events. When upgrading from the former two-file
  /// layout, the first mutation writes the consolidated state without
  /// modifying either legacy file.
  private func loadState() throws -> StorageState {
    if let cachedState { return cachedState }
    if FileManager.default.fileExists(atPath: stateURL.path) {
      let loaded = try decoder.decode(StorageState.self, from: Data(contentsOf: stateURL))
      cachedState = loaded
      return loaded
    }
    let loaded = StorageState(
      points: try loadLegacy([E1RMHistoryPoint].self, from: pointsURL),
      prEvents: try loadLegacy([PRBreakthroughEvent].self, from: prsURL)
    )
    cachedState = loaded
    return loaded
  }

  private func loadLegacy<Value: Decodable>(
    _ type: Value.Type,
    from url: URL
  ) throws -> Value where Value: ExpressibleByArrayLiteral {
    guard FileManager.default.fileExists(atPath: url.path) else {
      return []
    }
    return try decoder.decode(type, from: Data(contentsOf: url))
  }

  private func save(_ state: StorageState) throws {
    try ensureDirectory()
    try encoder.encode(state).write(to: stateURL, options: .atomic)
    cachedState = state
  }

  private static func maximumBaselines(
    _ baselines: [E1RMWeightBaseline]
  ) -> [E1RMWeightBaseline] {
    Dictionary(
      baselines.map { ($0.family, $0) },
      uniquingKeysWith: { existing, candidate in
        existing.maxWeightKg >= candidate.maxWeightKg ? existing : candidate
      }
    ).values.sorted { $0.family.rawValue < $1.family.rawValue }
  }

  private static func replaceHistoryState(
    _ state: inout StorageState,
    studentId: UUID,
    with replacement: [E1RMHistoryPoint],
    weightBaselines replacementBaselines: [E1RMWeightBaseline],
    prEvents replacementPREvents: [PRBreakthroughEvent]
  ) {
    state.points =
      state.points.filter { $0.studentId != studentId }
      + replacement.filter { $0.studentId == studentId }
    state.weightBaselines =
      state.weightBaselines.filter { $0.studentId != studentId }
      + maximumBaselines(
        replacementBaselines.filter { $0.studentId == studentId }
      )
    state.prEvents =
      state.prEvents.filter { $0.studentId != studentId }
      + replacementPREvents.filter { $0.studentId == studentId }
  }

  private func incrementRevision(for studentID: UUID) {
    revisionByStudentID[studentID, default: 0] &+= 1
  }

  private func ensureDirectory() throws {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  }
}
// swiftlint:enable type_body_length
