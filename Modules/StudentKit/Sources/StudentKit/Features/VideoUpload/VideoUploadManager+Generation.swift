import CoreModels
import Foundation

extension VideoUploadManager {
  @discardableResult
  func advanceUploadGeneration(recordID: UUID) -> Int {
    nextUploadGeneration += 1
    let generation = nextUploadGeneration
    uploadGenerations[recordID] = generation
    return generation
  }

  func requireCurrentUploadGeneration(_ generation: Int, recordID: UUID) throws {
    guard uploadGenerations[recordID] == generation else {
      throw CancellationError()
    }
  }

  /// Suspension audit for the remove/wake/retry/failure boundary:
  /// - exactly one remove owns `removingRecordIDs` from before its first await
  ///   through teardown, then retains a newer monotonic generation tombstone
  ///   after deletion so suspended historical snapshots cannot reseed the key;
  /// - wake code calls this after fetch/cancel/pending/save/initiate/complete/
  ///   schedule awaits and immediately before every local or remote side effect;
  /// - explicit retry, wake-entry fetches, and dormant fetchAll records validate
  ///   their persisted generation against memory before restore or side effects;
  /// - explicit retry calls it after fetch/cancel/abort/save awaits before it
  ///   publishes or starts a replacement writer;
  /// - automatic timer/network retries carry their scheduled generation across
  ///   fetches, while failure/terminal paths check after fetch/cancel/abort/save/
  ///   chunk-cleanup awaits before writing, scheduling, publishing, or notifying.
  func requireLiveWakeContext(recordID: UUID, generation: Int) throws {
    guard !removingRecordIDs.contains(recordID) else {
      throw CancellationError()
    }
    try requireCurrentUploadGeneration(generation, recordID: recordID)
  }

  func requireLiveWakeContextIfPresent(recordID: UUID, generation: Int?) throws {
    guard !removingRecordIDs.contains(recordID) else {
      throw CancellationError()
    }
    guard let generation else { return }
    try requireCurrentUploadGeneration(generation, recordID: recordID)
  }

  /// Validates that a fetched snapshot still represents the current in-memory
  /// attempt. Persisted generation is allowed to seed only a truly cold key;
  /// an existing key (including a deletion tombstone) must match exactly.
  func requireLiveSnapshotGeneration(from record: VideoAttachment) throws -> Int {
    if let currentGeneration = uploadGenerations[record.id] {
      guard record.uploadGeneration == currentGeneration else {
        throw CancellationError()
      }
      try requireLiveWakeContext(recordID: record.id, generation: currentGeneration)
      return currentGeneration
    }
    guard !removingRecordIDs.contains(record.id) else {
      throw CancellationError()
    }
    return restoreUploadGeneration(from: record)
      ?? advanceUploadGeneration(recordID: record.id)
  }

  func restoreUploadGeneration(from record: VideoAttachment) -> Int? {
    // The in-memory generation is the single authority once present: a new
    // attempt advances it before its persistence lands (a first upload's
    // record may still hold nil), and seeding from the still-stale database
    // would roll the record back (cancelling the new writer). It also wins
    // over any persisted value for the same reason. Seed cold starts only.
    if let current = uploadGenerations[record.id] {
      return current
    }
    guard let generation = record.uploadGeneration, generation > 0 else { return nil }
    nextUploadGeneration = max(nextUploadGeneration, generation)
    uploadGenerations[record.id] = generation
    return generation
  }

  func persistUploadGeneration(
    _ generation: Int,
    recordID: UUID
  ) async throws -> VideoAttachment {
    guard var record = try await repository.fetch(id: recordID) else {
      throw CancellationError()
    }
    try requireCurrentUploadGeneration(generation, recordID: recordID)
    record.uploadGeneration = generation
    try await repository.save(record)
    try requireCurrentUploadGeneration(generation, recordID: recordID)
    return record
  }

  @discardableResult
  func persistNewUploadGeneration(recordID: UUID) async -> Int {
    let generation = advanceUploadGeneration(recordID: recordID)
    guard var record = try? await repository.fetch(id: recordID) else { return generation }
    record.uploadGeneration = generation
    try? await repository.save(record)
    return generation
  }

  func reclaimUploadGeneration(_ generation: Int, recordID: UUID) async {
    guard uploadGenerations[recordID] == generation else { return }
    guard var record = try? await repository.fetch(id: recordID) else {
      uploadGenerations[recordID] = nil
      return
    }
    guard record.uploadGeneration == generation, record.status == .uploaded else { return }
    record.uploadGeneration = nil
    try? await repository.save(record)
    guard uploadGenerations[recordID] == generation else { return }
    uploadGenerations[recordID] = nil
  }

  func matchesPersistedUploadGeneration(
    _ generation: Int?,
    record: VideoAttachment
  ) -> Bool {
    guard let generation, generation > 0 else { return false }
    if let currentGeneration = uploadGenerations[record.id] {
      return currentGeneration == generation
    }
    guard record.uploadGeneration == generation else { return false }
    nextUploadGeneration = max(nextUploadGeneration, generation)
    uploadGenerations[record.id] = generation
    return true
  }
}
