import CoreModels
import Foundation

extension VideoUploadManager {
  func finishBackgroundSessionEvents(
    identifier: String,
    completionToken: BackgroundUploadEventToken
  ) async {
    backgroundEventDrainTasks[identifier]?.cancel()
    backgroundEventDrainTasks[identifier] = nil
    backgroundEventDrainTokens[identifier] = nil
    pendingBackgroundFinishTokens[identifier, default: []].insert(completionToken)
    await drainRestoredBackgroundRecordsSingleFlight(identifier: identifier)
  }

  func scheduleManualBackgroundEventDrain(identifier: String) {
    backgroundEventDrainTasks[identifier]?.cancel()
    let token = UUID()
    backgroundEventDrainTokens[identifier] = token
    backgroundEventDrainTasks[identifier] = Task { [weak self] in
      do {
        try await Task.sleep(for: .milliseconds(100))
        await self?.drainManualBackgroundEvents(identifier: identifier, token: token)
      } catch {}
    }
  }

  private func drainManualBackgroundEvents(identifier: String, token: UUID) async {
    guard backgroundEventDrainTokens[identifier] == token else { return }
    backgroundEventDrainTasks[identifier] = nil
    backgroundEventDrainTokens[identifier] = nil
    guard
      !BackgroundUploadCompletionRegistry.shared.hasPendingHandler(identifier: identifier)
    else { return }
    await drainRestoredBackgroundRecordsSingleFlight(identifier: identifier)
  }

  private func drainRestoredBackgroundRecordsSingleFlight(identifier: String) async {
    guard drainingBackgroundSessionIdentifiers.insert(identifier).inserted else { return }
    defer { drainingBackgroundSessionIdentifiers.remove(identifier) }

    repeat {
      let records = restoredBackgroundRecords.removeValue(forKey: identifier) ?? [:]
      let recordIDs = Set(records.keys)
      drainingBackgroundRecordIDs.formUnion(recordIDs)
      await processRestoredBackgroundRecords(records)
      await sweepDormantBackgroundRecords(
        excluding: drainingBackgroundRecordIDs.union(manualHarvestingRecordIDs)
      )
      drainingBackgroundRecordIDs.subtract(recordIDs)
    } while !(restoredBackgroundRecords[identifier]?.isEmpty ?? true)

    let finishTokens = pendingBackgroundFinishTokens.removeValue(forKey: identifier) ?? []
    for token in finishTokens {
      BackgroundUploadCompletionRegistry.shared.acknowledgeEvent(token)
    }
    BackgroundUploadCompletionRegistry.shared.discardDeliveredSessionIfNoHandler(
      identifier: identifier
    )
  }

  private func processRestoredBackgroundRecords(
    _ records: [UUID: RestoredBackgroundRecord]
  ) async {
    for (recordID, restoredRecord) in records {
      if manualHarvestingRecordIDs.contains(recordID) {
        // Manual recovery owns cancellation and replacement for this record.
        // Its generation was already advanced, so queued old-session events
        // are acknowledged below without starting another wake writer.
      } else if let failure = restoredRecord.failure,
        let generation = restoredRecord.generation
      {
        await handleUploadFailure(
          recordID: recordID,
          error: failure,
          generation: generation
        )
      } else {
        await continueDuringBackgroundWake(recordID: recordID)
      }

      for token in restoredRecord.tokens {
        BackgroundUploadCompletionRegistry.shared.acknowledgeEvent(token)
      }
    }
  }

  private func sweepDormantBackgroundRecords(excluding excludedRecordIDs: Set<UUID>) async {
    for studentID in recoveringStudentIDs {
      let dormantRecords = (try? await repository.fetchAll(studentID: studentID)) ?? []
      // Records with a live pipeline task are not dormant: waking them here
      // would run a second writer under the same generation (duplicate part
      // writes/PUTs, spurious localFileMissing before the export lands).
      for record in dormantRecords
      where record.status != .uploaded
        && record.status != .failed
        && !excludedRecordIDs.contains(record.id)
        && activeUploads[record.id] == nil
        && scheduledRetries[record.id] == nil
        && !removingRecordIDs.contains(record.id)
        && !manualHarvestingRecordIDs.contains(record.id)
      {
        await continueDuringBackgroundWake(record)
      }
    }
  }
}
