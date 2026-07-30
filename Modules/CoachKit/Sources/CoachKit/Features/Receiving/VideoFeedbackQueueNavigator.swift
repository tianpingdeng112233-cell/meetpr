import Foundation
import RepositoryContracts

struct VideoFeedbackQueuePosition: Equatable, Sendable {
  let zeroBasedIndex: Int
  let total: Int

  var displayIndex: Int { zeroBasedIndex + 1 }
}

enum VideoFeedbackQueueNavigator {
  static func position(
    of itemID: UUID,
    in items: [PendingVideoItem]
  ) -> VideoFeedbackQueuePosition? {
    guard let index = items.firstIndex(where: { $0.id == itemID }) else { return nil }
    return VideoFeedbackQueuePosition(zeroBasedIndex: index, total: items.count)
  }

  static func nextItem(
    after itemID: UUID,
    in items: [PendingVideoItem]
  ) -> PendingVideoItem? {
    guard
      !items.isEmpty,
      let index = items.firstIndex(where: { $0.id == itemID })
    else {
      return nil
    }
    return items[(index + 1) % items.count]
  }

  /// Resolves where to land after a send succeeds, using **identity rather than
  /// an index**.
  ///
  /// A positional handoff breaks when a refresh lands mid-send: with `[A, B]`
  /// sending A, a refresh to `[X, A, B]` leaves `[X, B]` once A drops out, and
  /// A's former index `0` now points at X instead of B (review-loop 2026-07-30).
  ///
  /// So the caller captures the successor's id *before* sending, and this looks
  /// that id up in whatever the queue became. If the successor is gone too —
  /// another device answered it, say — the first remaining row is the honest
  /// landing spot, which is also what wrapping past the end already does.
  static func itemAfterSend(
    preferring successorID: UUID?,
    in items: [PendingVideoItem]
  ) -> PendingVideoItem? {
    guard !items.isEmpty else { return nil }
    if let successorID, let match = items.first(where: { $0.id == successorID }) {
      return match
    }
    return items.first
  }
}
