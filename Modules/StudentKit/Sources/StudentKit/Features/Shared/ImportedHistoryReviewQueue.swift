import Foundation

enum ImportedHistoryReviewQueue {
  static func appendingUnique(
    _ incoming: [PendingImportedHistoryReview],
    current: PendingImportedHistoryReview?,
    waiting: [PendingImportedHistoryReview]
  ) -> [PendingImportedHistoryReview] {
    var knownIDs = Set(waiting.map(\.id))
    if let current {
      knownIDs.insert(current.id)
    }

    var result = waiting
    for review in incoming where knownIDs.insert(review.id).inserted {
      result.append(review)
    }
    return result
  }

  static func takingNext(
    from waiting: [PendingImportedHistoryReview]
  ) -> (current: PendingImportedHistoryReview?, waiting: [PendingImportedHistoryReview]) {
    guard let current = waiting.first else { return (nil, []) }
    return (current, Array(waiting.dropFirst()))
  }
}
