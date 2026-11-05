import CoreModels
import Foundation

/// Counts the current day's delivery records, including videos still waiting for a set ID.
struct VideoCompletionPresentation: Equatable, Sendable {
  let total: Int
  let done: Int
  let failed: Int
  let uploading: Int
  let waiting: Bool
  let showsSummary: Bool

  var progress: Double { total == 0 ? 1 : Double(done) / Double(total) }

  init(attachments: [VideoAttachment], trainingDate: Date, allSetsDone: Bool, waiting: Bool) {
    let records = attachments.filter { $0.trainingDate == trainingDate }
    total = records.count
    done = records.filter { $0.status == .uploaded }.count
    failed =
      records.filter { $0.status != .uploaded && VideoDeliveryPresentation.hasFailure($0) }.count
    uploading = total - done - failed
    self.waiting = waiting
    showsSummary = allSetsDone && !waiting && done < total
  }
}
