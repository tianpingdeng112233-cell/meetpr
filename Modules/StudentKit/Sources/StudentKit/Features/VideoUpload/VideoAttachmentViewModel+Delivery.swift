import CoreModels
import Foundation

extension VideoAttachmentViewModel {
  func retryFailures(studentID: UUID, workout: TodayWorkoutViewModel, trainingDate: Date? = nil)
    async
  {
    let records = await manager.attachments(studentID: studentID)
    for record in records where VideoDeliveryPresentation.hasFailure(record) {
      if let trainingDate, record.trainingDate != trainingDate { continue }
      if await manager.needsReplacement(attachmentID: record.id) {
        if missingAttachment == nil { missingAttachment = record }
        continue
      }
      if let draftID = record.pendingDraftID {
        let draft = workout.currentDrafts?.first {
          $0.id == draftID
            || (record.pendingSetSlot != nil && $0.pendingVideoSlot == record.pendingSetSlot)
        }
        guard let draft else { continue }
        if let queue = workout.setSyncQueue,
          let pending = queue.records.first(where: {
            $0.isPending && $0.draft.id == draft.id && $0.trainingDate == record.trainingDate
          })
        {
          // The sender binds the retained video after its canonical set receipt arrives.
          clearProcessingFailure()
          queue.retryNow(dayID: pending.dayID)
          continue
        }
        await retryPending(setLogID: record.setLogID) {
          await workout.resolveVideoSetLogID(draftID: draft.id, trainingDate: record.trainingDate)
        }
      } else {
        await retry(setLogID: record.setLogID)
      }
    }
  }

  func restoreMissingVideo(_ record: VideoAttachment, sourceURL: URL) async -> Bool {
    do {
      try await manager.replaceMissingSource(attachmentID: record.id, sourceURL: sourceURL)
      missingAttachment = nil
      clearProcessingFailure()
      return true
    } catch {
      reportVideoProcessingFailure()
      return false
    }
  }
}
