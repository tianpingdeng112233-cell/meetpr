import CoreModels
import Foundation

extension VideoAttachmentViewModel {
  /// Shared camera/library handoff. Persist ownership before asking the set
  /// repository for an ID; a failed save or load-generation change keeps it.
  func attach(
    sourceURL: URL, draftID: UUID, studentID: UUID, trainingDate: Date,
    slot: VideoAttachment.SetSlot? = nil,
    resolveSetLogID: @MainActor () async -> UUID?
  ) async {
    clearProcessingFailure()
    do {
      let record = try await manager.retainForSet(
        sourceURL: sourceURL, draftID: draftID, studentID: studentID,
        trainingDate: trainingDate, slot: slot)
      apply(.updated(record, progress: 0))
      guard let setLogID = await resolveSetLogID() else {
        reportVideoProcessingFailure()
        return
      }
      if await bind(record: record, setLogID: setLogID) {
        // Both the durable source/record and canonical association now exist.
        // Failed resolution keeps this caller-owned fallback untouched.
        try? FileManager.default.removeItem(at: sourceURL)
      }
    } catch {
      reportVideoProcessingFailure()
    }
  }

  func pendingRowState(
    draftID: UUID, trainingDate: Date, slot: VideoAttachment.SetSlot? = nil
  ) -> RowState? {
    rowStates.values.filter {
      $0.attachment.awaitsSet(draftID: draftID, trainingDate: trainingDate, slot: slot)
    }.max { $0.attachment.recordedAt < $1.attachment.recordedAt }
  }

  /// Called when workout state changes (save success or returning to a day).
  /// Only already-resolved IDs are consumed here; failed saves never loop.
  func resumePendingAttachments(workout: TodayWorkoutViewModel, studentID: UUID) async {
    let records = await manager.attachments(studentID: studentID)
    for record in records {
      guard let draftID = record.pendingDraftID,
        let setLogID = workout.videoSetLogID(
          draftID: draftID, trainingDate: record.trainingDate, slot: record.pendingSetSlot)
      else { continue }
      await bind(record: record, setLogID: setLogID)
    }
  }

  func retryPending(
    setLogID: UUID, resolveSetLogID: @MainActor () async -> UUID?
  ) async {
    guard let record = rowStates[setLogID]?.attachment else { return }
    if await manager.needsReplacement(attachmentID: record.id) {
      missingAttachment = record
      return
    }
    guard record.pendingDraftID != nil,
      let canonicalID = await resolveSetLogID()
    else {
      reportVideoProcessingFailure()
      return
    }
    await bind(record: record, setLogID: canonicalID)
  }

  @discardableResult
  private func bind(record: VideoAttachment, setLogID: UUID) async -> Bool {
    do {
      if let bound = try await manager.bindPending(recordID: record.id, setLogID: setLogID) {
        clearProcessingFailure()
        apply(.removed(setLogID: record.setLogID, attachmentID: record.id))
        if rowStates[bound.setLogID]?.attachment.id != bound.id {
          apply(.updated(bound, progress: 0))
        }
        return true
      }
    } catch {
      reportVideoProcessingFailure()
    }
    return false
  }
}
