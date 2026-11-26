import Foundation
import Networking
import Observation
import RepositoryContracts

/// Shared completion gate for 102 sets and 101 video delivery. Only an intent
/// authorized after set synchronization may reach the completion endpoint.
@Observable @MainActor final class WorkoutCompletionGate {
  private struct Intent: Codable {
    let dayID: UUID
    var actualCompletionDate: String?
    var preparingSets: Bool?
    var dateUsedForSets: Bool?
    var requestedAt: Date?
    var completionID: UUID?
    var completedAt: Date?
    var source: String?
    var confirmedActualDate: String?
    var videoWait: VideoWait?
  }

  struct VideoWait: Codable, Equatable {
    let trainingDate: Date
    let startedAt: Date
    var timeoutNotified = false
  }

  func requestedAt(dayID: UUID) -> Date {
    intents.first { $0.dayID == dayID }?.requestedAt ?? Date()
  }

  func videoWait(dayID: UUID) -> VideoWait? {
    intents.first { $0.dayID == dayID }?.videoWait
  }

  func waitForVideos(dayID: UUID, trainingDate: Date, startedAt: Date) throws {
    guard active, let index = intents.firstIndex(where: { $0.dayID == dayID }) else { return }
    guard intents[index].videoWait == nil else { return }
    var next = intents
    next[index].videoWait = VideoWait(trainingDate: trainingDate, startedAt: startedAt)
    try save(next)
    intents = next
  }

  let studentID: UUID
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
    let pending = intents.filter { $0.completedAt == nil || $0.videoWait != nil }
    if pending.count != intents.count {
      try save(pending)
      intents = pending
    }
  }

  var pendingDays: [UUID] {
    intents.filter { $0.completedAt == nil && $0.preparingSets != true }.map(\.dayID)
  }

  func actualCompletionDate(dayID: UUID) -> String? {
    intents.first { $0.dayID == dayID }?.actualCompletionDate
  }

  /// Reserve before the first group mutation. A crash here must resume filling
  /// the same day before background workers may send the completion.
  func prepareResumeWrites(dayID: UUID, date: String) throws {
    guard active else { throw CancellationError() }
    var next = intents
    if let index = next.firstIndex(where: { $0.dayID == dayID }) {
      guard next[index].actualCompletionDate == date else {
        throw PlanDayCompletionError.unavailable
      }
      guard next[index].dateUsedForSets != true else { return }
      next[index].dateUsedForSets = true
      next[index].preparingSets = true
    } else {
      next.append(
        Intent(
          dayID: dayID, actualCompletionDate: date, preparingSets: true,
          dateUsedForSets: true, requestedAt: Date()))
    }
    try save(next)
    intents = next
  }

  func request(dayID: UUID, actualCompletionDate: String? = nil) throws {
    guard active else { throw CancellationError() }
    if let previous = intents.first(where: { $0.dayID == dayID }) {
      guard previous.actualCompletionDate == actualCompletionDate else {
        throw PlanDayCompletionError.unavailable
      }
      if previous.preparingSets == true,
        let index = intents.firstIndex(where: { $0.dayID == dayID })
      {
        var next = intents
        next[index].preparingSets = false
        try save(next)
        intents = next
      }
      return
    }
    let next =
      intents + [
        Intent(dayID: dayID, actualCompletionDate: actualCompletionDate, requestedAt: Date())
      ]
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
      intents.contains(where: {
        $0.dayID == dayID && $0.completedAt == nil && $0.preparingSets != true
      })
    else { return nil }
    inFlight.insert(dayID)
    let sendingGeneration = generation
    defer { inFlight.remove(dayID) }
    let result: PlanDayCompletion
    do {
      result = try await complete()
    } catch {
      if active, generation == sendingGeneration, Self.definitelyRejected(error) {
        try resetRejectedResume(dayID: dayID)
      }
      throw error
    }
    guard active, generation == sendingGeneration, !Task.isCancelled else { return nil }
    var next = intents
    if let index = next.firstIndex(where: { $0.dayID == dayID }), next[index].videoWait != nil {
      next[index].completionID = result.id
      next[index].completedAt = result.completedAt
      next[index].source = result.source
      next[index].confirmedActualDate = result.actualCompletionDate
    } else {
      next.removeAll { $0.dayID == dayID }
    }
    try save(next)
    intents = next
    return result
  }

  var notificationDays: [UUID] {
    intents.filter { $0.completedAt != nil && $0.videoWait != nil }.map(\.dayID)
  }

  func completedResult(dayID: UUID) -> PlanDayCompletion? {
    guard let intent = intents.first(where: { $0.dayID == dayID }),
      let date = intent.completedAt
    else { return nil }
    return PlanDayCompletion(
      id: intent.completionID ?? dayID, dayID: dayID, studentID: studentID,
      source: intent.source ?? "manual", completedAt: date,
      actualCompletionDate: intent.confirmedActualDate)
  }

  func markTimeoutScheduled(dayID: UUID) throws {
    guard active, let index = intents.firstIndex(where: { $0.dayID == dayID }),
      intents[index].videoWait?.timeoutNotified == false
    else { return }
    var next = intents
    next[index].videoWait?.timeoutNotified = true
    try save(next)
    intents = next
  }

  func resetCancelledTimeout(dayID: UUID) throws {
    guard active, let index = intents.firstIndex(where: { $0.dayID == dayID }),
      intents[index].videoWait?.timeoutNotified == true
    else { return }
    var next = intents
    next[index].videoWait?.timeoutNotified = false
    try save(next)
    intents = next
  }

  static func definitelyRejected(_ error: any Error) -> Bool {
    if case APIError.httpStatus(400, _) = error { return true }
    if case APIClientError.httpStatus(400, _) = error { return true }
    return error is PlanDayCompletionError
  }

  private func resetRejectedResume(dayID: UUID) throws {
    guard let index = intents.firstIndex(where: { $0.dayID == dayID }),
      intents[index].actualCompletionDate != nil
    else { return }
    if intents[index].dateUsedForSets == true {
      var next = intents
      next[index].preparingSets = true
      next[index].videoWait = nil
      try save(next)
      intents = next
    } else {
      try forget(dayID: dayID)
    }
  }

  private func save(_ next: [Intent]) throws {
    try storage.write(JSONEncoder().encode(next), account: studentID, name: "completion")
  }
}
