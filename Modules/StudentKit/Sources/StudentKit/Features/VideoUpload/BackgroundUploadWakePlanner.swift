import Foundation

struct BackgroundUploadWakePlanner: Sendable {
  enum Decision: Equatable, Sendable {
    case prepareRemoteSession
    case complete
    case scheduleParts([Int])
    case waitForScheduledParts
  }

  func decision(
    partCount: Int,
    targetPartNumbers: Set<Int>,
    completedPartNumbers: Set<Int>,
    pendingPartNumbers: Set<Int>,
    maxConcurrentParts: Int
  ) -> Decision {
    guard partCount > 0,
      targetPartNumbers == Set(1...partCount)
    else {
      return .prepareRemoteSession
    }

    let allPartNumbers = Set(1...partCount)
    let missingPartNumbers = allPartNumbers.subtracting(completedPartNumbers)
    guard !missingPartNumbers.isEmpty else { return .complete }

    let scheduledMissingParts = pendingPartNumbers.intersection(missingPartNumbers)
    let availableSlots = max(0, maxConcurrentParts - scheduledMissingParts.count)
    let nextParts =
      missingPartNumbers
      .subtracting(pendingPartNumbers)
      .sorted()
      .prefix(availableSlots)
    guard !nextParts.isEmpty else { return .waitForScheduledParts }
    return .scheduleParts(Array(nextParts))
  }
}
