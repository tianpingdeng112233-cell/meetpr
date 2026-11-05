import Foundation
import RepositoryContracts

/// Shared completion gate for 102 sets and 101 video delivery. Only an intent
/// authorized after set synchronization may reach the completion endpoint.
@MainActor final class WorkoutCompletionGate {
  private struct Intent: Codable {
    let dayID: UUID
    var completionID: UUID?
    var completedAt: Date?
    var source: String?
  }

  private let studentID: UUID
  private let storage: any SetSyncStorage
  private var intents: [Intent]
  private var inFlight: Set<UUID> = []
  private var active = true
  private var generation = 0

  func start() { active = true }
  func stop() {
    active = false
    generation += 1
  }

  init(studentID: UUID, storage: any SetSyncStorage) throws {
    self.studentID = studentID
    self.storage = storage
    intents =
      try storage.read(account: studentID, name: "completion")
      .map { try JSONDecoder().decode([Intent].self, from: $0) } ?? []
    let pending = intents.filter { $0.completedAt == nil }
    if pending.count != intents.count {
      try save(pending)
      intents = pending
    }
  }

  var pendingDays: [UUID] { intents.filter { $0.completedAt == nil }.map(\.dayID) }

  func request(dayID: UUID) throws {
    guard active else { throw CancellationError() }
    guard !intents.contains(where: { $0.dayID == dayID }) else { return }
    let next = intents + [Intent(dayID: dayID)]
    try save(next)
    intents = next
  }

  func forget(dayID: UUID) throws {
    guard active else { throw CancellationError() }
    let next = intents.filter { $0.dayID != dayID }
    try save(next)
    intents = next
  }

  func completeIfReady(
    dayID: UUID, setsSynced: Bool, videosDelivered: Bool,
    complete: @MainActor () async throws -> PlanDayCompletion
  ) async throws -> PlanDayCompletion? {
    guard active, setsSynced, videosDelivered, !inFlight.contains(dayID),
      intents.contains(where: { $0.dayID == dayID })
    else { return nil }
    inFlight.insert(dayID)
    let sendingGeneration = generation
    defer { inFlight.remove(dayID) }
    let result = try await complete()
    guard active, generation == sendingGeneration, !Task.isCancelled else { return nil }
    let next = intents.filter { $0.dayID != dayID }
    try save(next)
    intents = next
    return result
  }

  private func save(_ next: [Intent]) throws {
    try storage.write(JSONEncoder().encode(next), account: studentID, name: "completion")
  }
}
