import CoreModels
import Foundation

/// Delivery failures are visible from the first failure, independently of the
/// retry scheduler's pending/uploading states. A successful delivery clears them.
struct VideoDeliveryPresentation: Equatable, Sendable {
  let failedDraftIDs: Set<UUID>
  var failureCount: Int { failedDraftIDs.count }

  init(drafts: [TodayWorkoutSetRowDraft], trainingDate: Date, attachments: [VideoAttachment]) {
    failedDraftIDs = Set(
      drafts.compactMap { draft in
        guard
          let attachment = Self.attachment(for: draft, trainingDate: trainingDate, in: attachments),
          Self.hasFailure(attachment)
        else { return nil }
        return draft.id
      })
  }

  static func attachment(
    for draft: TodayWorkoutSetRowDraft, trainingDate: Date, in attachments: [VideoAttachment]
  ) -> VideoAttachment? {
    let pending = attachments.filter {
      $0.awaitsSet(draftID: draft.id, trainingDate: trainingDate, slot: draft.pendingVideoSlot)
    }.max { $0.recordedAt < $1.recordedAt }
    return pending
      ?? attachments.filter {
        $0.pendingDraftID == nil && $0.setLogID == draft.loggedSetID
      }.max { $0.recordedAt < $1.recordedAt }
  }

  static func hasFailure(_ attachment: VideoAttachment) -> Bool {
    attachment.pendingDraftID != nil
      || (attachment.status != .uploaded
        && (attachment.status == .failed || attachment.firstUploadFailureAt != nil))
  }
}
