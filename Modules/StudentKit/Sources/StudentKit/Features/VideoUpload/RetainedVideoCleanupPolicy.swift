import CoreModels
import Foundation

struct RetainedVideoFile: Equatable, Sendable {
  let attachmentID: UUID
  let status: VideoAttachment.Status
  let trainingDate: Date
  let recordedAt: Date
  let sizeBytes: Int64
}

enum RetainedVideoCleanupPolicy {
  static let defaultByteLimit: Int64 = 500 * 1_024 * 1_024

  static func attachmentIDsToRemove(
    from files: [RetainedVideoFile],
    now: Date,
    calendar: Calendar,
    byteLimit: Int64 = defaultByteLimit
  ) -> Set<UUID> {
    let uploadedFiles = files.filter { $0.status == .uploaded }
    var removals = Set(
      uploadedFiles
        .filter { !calendar.isDate($0.trainingDate, inSameDayAs: now) }
        .map(\.attachmentID)
    )

    let retainedToday = uploadedFiles.filter { !removals.contains($0.attachmentID) }
    var retainedBytes = retainedToday.reduce(into: Int64.zero) { total, file in
      total += max(0, file.sizeBytes)
    }
    let limit = max(0, byteLimit)

    for file in retainedToday.sorted(by: oldestFirst) where retainedBytes > limit {
      removals.insert(file.attachmentID)
      retainedBytes -= max(0, file.sizeBytes)
    }
    return removals
  }

  private static func oldestFirst(_ lhs: RetainedVideoFile, _ rhs: RetainedVideoFile) -> Bool {
    if lhs.recordedAt != rhs.recordedAt {
      return lhs.recordedAt < rhs.recordedAt
    }
    return lhs.attachmentID.uuidString < rhs.attachmentID.uuidString
  }
}
