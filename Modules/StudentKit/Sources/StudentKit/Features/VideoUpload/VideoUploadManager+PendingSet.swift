import CoreModels
import Foundation

extension VideoUploadManager {
  /// Retain before any set-save await. A missing canonical ID is a retryable
  /// local failure, never permission to dispose of the student's recording.
  func retainForSet(
    sourceURL: URL, draftID: UUID, studentID: UUID, trainingDate: Date,
    slot: VideoAttachment.SetSlot? = nil
  ) async throws -> VideoAttachment {
    let selection = beginSelection(
      studentID: studentID, trainingDate: trainingDate, draftID: draftID)
    defer { finishSelection(selection) }
    return try await serializePendingSetMutation {
      try await self.performRetainForSet(
        sourceURL: sourceURL, draftID: draftID, studentID: studentID, trainingDate: trainingDate,
        slot: slot)
    }
  }

  private func performRetainForSet(
    sourceURL: URL, draftID: UUID, studentID: UUID, trainingDate: Date,
    slot: VideoAttachment.SetSlot? = nil
  ) async throws -> VideoAttachment {
    let id = UUID()
    retainingSourceRecordIDs.insert(id)
    defer { retainingSourceRecordIDs.remove(id) }
    try FileManager.default.createDirectory(at: filesDirectory, withIntermediateDirectories: true)
    let retained = sourceFileURL(recordID: id, pathExtension: sourceURL.pathExtension)
    // Keep the caller's copy too: even a disk/metadata write failure must not
    // turn an unsuccessful handoff into loss of the only recording.
    try FileManager.default.copyItem(at: sourceURL, to: retained)
    let previous = try await repository.fetchAll(studentID: studentID)
      .filter { $0.awaitsSet(draftID: draftID, trainingDate: trainingDate, slot: slot) }
      .map(\.recordedAt).max()
    // Existing JSON dates have second precision. Preserve replacement order
    // even when two selections arrive within that same second.
    let recordedAt = max(now(), previous?.addingTimeInterval(1) ?? .distantPast)
    let record = VideoAttachment(
      id: id, setLogID: id, studentID: studentID, status: .failed,
      contentType: "video/mp4", durationSeconds: 0, sizeBytes: 0,
      localFileName: "\(id.uuidString).mp4", recordedAt: recordedAt,
      trainingDate: trainingDate, pendingDraftID: draftID, pendingSetSlot: slot)
    try await repository.save(record)
    broadcast(.updated(record, progress: 0))
    return record
  }

  /// Reuses the persisted record and retained source, including after restart.
  /// Neither a failed bind nor an unresolved target deletes local media.
  func bindPending(recordID: UUID, setLogID: UUID) async throws -> VideoAttachment? {
    try await serializePendingSetMutation {
      try await self.performBindPending(recordID: recordID, setLogID: setLogID)
    }
  }

  private func performBindPending(recordID: UUID, setLogID: UUID) async throws -> VideoAttachment? {
    let generation = uploadGenerations[recordID]
    try requirePendingBindingContext(recordID: recordID, generation: generation)
    guard var record = try await repository.fetch(id: recordID) else { return nil }
    try requirePendingBindingContext(recordID: recordID, generation: generation)
    guard let draftID = record.pendingDraftID else {
      return record.setLogID == setLogID ? record : nil
    }
    guard let source = retainedSourceURL(recordID: recordID) else {
      throw VideoUploadError.localFileMissing
    }
    let duration = try await diagnosedDuration(of: source)
    try requirePendingBindingContext(recordID: recordID, generation: generation)
    guard duration <= configuration.maxDurationSeconds + Self.durationGraceSeconds else {
      VideoProcessingDiagnostics().report(.duration, code: .tooLong)
      throw VideoUploadError.durationExceedsLimit(
        seconds: duration, maxSeconds: configuration.maxDurationSeconds)
    }
    let peers = try await repository.fetchAll(studentID: record.studentID)
    try requirePendingBindingContext(recordID: recordID, generation: generation)
    // A newer selection for this slot owns attachment; keep the older source
    // until that selection is safely bound to a real server ID.
    guard
      !peers.contains(where: {
        $0.awaitsSet(
          draftID: draftID, trainingDate: record.trainingDate, slot: record.pendingSetSlot)
          && $0.recordedAt > record.recordedAt
      })
    else { return nil }
    let slot = record.pendingSetSlot
    let oldKey = record.setLogID
    record.setLogID = setLogID
    record.pendingDraftID = nil
    record.pendingSetSlot = nil
    record.durationSeconds = duration
    record.status = .pending
    try await repository.save(record)
    try requirePendingBindingContext(recordID: recordID, generation: generation)
    broadcast(.removed(setLogID: oldKey, attachmentID: recordID))
    broadcast(.updated(record, progress: 0))
    for previous in peers
    where previous.id != recordID
      && (previous.setLogID == setLogID
        || previous.awaitsSet(draftID: draftID, trainingDate: record.trainingDate, slot: slot))
    {
      try requirePendingBindingContext(recordID: recordID, generation: generation)
      await remove(attachmentID: previous.id, waitsForPendingBinding: false)
    }
    try requirePendingBindingContext(recordID: recordID, generation: generation)
    await prepareUploadHandling()
    try requirePendingBindingContext(recordID: recordID, generation: generation)
    startUploadTask(recordID: recordID, sourceURL: source)
    return record
  }

  private func requirePendingBindingContext(recordID: UUID, generation: Int?) throws {
    guard uploadGenerations[recordID] == generation else { throw CancellationError() }
    try requireLiveWakeContextIfPresent(recordID: recordID, generation: generation)
  }

  // Repository calls suspend the actor. Serialize selection/binding so an
  // older camera callback cannot delete a newer retained take during an await.
  private func serializePendingSetMutation<Value: Sendable>(
    _ operation: @escaping @Sendable () async throws -> Value
  ) async throws -> Value {
    let previous = pendingSetMutation
    let task = Task {
      await previous?.value
      return try await operation()
    }
    pendingSetMutation = Task { _ = try? await task.value }
    return try await task.value
  }

}
