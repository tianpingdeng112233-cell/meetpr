import CoreModels
import Foundation
import Observation

@Observable @MainActor public final class SetSyncQueue {
  let completionGate: WorkoutCompletionGate
  var videoCompletion: VideoCompletionCoordinator?
  let studentID: UUID
  private(set) var records: [PendingSetRecord]
  private(set) var revision = 0
  var onAcknowledged: (@MainActor (PendingSetRecord, SetSyncReceipt) async -> Void)?
  private var observers: [UUID: @MainActor () -> Void] = [:]
  private var active = true
  private var generation = 0
  private var automatic = false
  private var draining = false
  private var priorityDay: UUID?
  private var worker: Task<Void, Never>?
  private var retryTimer: Task<Void, Never>?
  private var networkTask: Task<Void, Never>?
  private var retryAttempt = 0
  private let sleep: @MainActor (Duration) async throws -> Void
  private let now: @MainActor () -> Date
  private let storage: any SetSyncStorage
  private let send: @MainActor (PendingSetRecord) async throws -> SetSyncReceipt

  init(
    studentID: UUID, storage: any SetSyncStorage,
    now: @escaping @MainActor () -> Date = { Date() },
    sleep: @escaping @MainActor (Duration) async throws -> Void = {
      try await Task.sleep(for: $0)
    },
    send: @escaping @MainActor (PendingSetRecord) async throws -> SetSyncReceipt
  ) throws {
    completionGate = try WorkoutCompletionGate(studentID: studentID, storage: storage)
    self.studentID = studentID
    self.storage = storage
    self.send = send
    self.sleep = sleep
    self.now = now
    records =
      try storage.read(account: studentID, name: "sets")
      .map { try JSONDecoder().decode([PendingSetRecord].self, from: $0) } ?? []
    try pruneReceipts()
  }

  var pendingCount: Int { records.filter(\.isPending).count }

  var pendingSetCount: Int {
    var slots: [PendingSetRecord] = []
    for record in records where record.isPending && !slots.contains(where: { sameSlot($0, record) })
    {
      slots.append(record)
    }
    return slots.count
  }

  func pendingCount(dayID: UUID) -> Int {
    records.filter { $0.dayID == dayID && $0.isPending }.count
  }

  func hasRejected(dayID: UUID) -> Bool {
    records.contains { $0.dayID == dayID && $0.isPending && $0.rejected }
  }

  func enqueue(
    dayID: UUID, trainingDate: Date, draft: TodayWorkoutSetRowDraft,
    recordedAt: Date = Date(), deleting: Bool = false, loggedDate: String? = nil
  ) throws {
    var record = PendingSetRecord(
      id: UUID(), studentID: studentID, dayID: dayID, trainingDate: trainingDate,
      draft: draft, recordedAt: recordedAt,
      loggedDate: loggedDate
        ?? TodayWorkoutViewModel.gymDate(
          recordedAt, calendar: WorkoutDatePolicy.deviceCalendar),
      deleting: deleting)
    if let previous = records.last(where: { $0.draftOnly != true && sameSlot($0, record) }) {
      record.loggedDate = previous.loggedDate
      record.fallbackSetIndex = previous.fallbackSetIndex
      record.draft.loggedSetID = previous.draft.loggedSetID ?? record.draft.loggedSetID
    } else if draft.isStudentAdded,
      let previous = records.first(where: {
        $0.draftOnly != true && $0.dayID == dayID
          && $0.draft.exerciseID == draft.exerciseID && $0.draft.isStudentAdded
      })
    {
      record.loggedDate = previous.loggedDate
    }
    var next = records.filter { !($0.draftOnly == true && sameSlot($0, record)) }
    // Removing an unrecorded row is entirely local; no zero-valued write or
    // server deletion is needed. Recorded rows retain their ordered operations.
    if !deleting || draft.hasSavedRecord || next.contains(where: { sameSlot($0, record) }) {
      next.append(record)
    }
    try save(next)
    records = next
    changed()
    wake()
  }

  func storeDraft(dayID: UUID, trainingDate: Date, draft: TodayWorkoutSetRowDraft) throws {
    guard active, !draft.hasSavedRecord else { return }
    let record = PendingSetRecord(
      id: UUID(), studentID: studentID, dayID: dayID, trainingDate: trainingDate,
      draft: draft, recordedAt: now(), loggedDate: "", draftOnly: true)
    let next = records.filter { !($0.draftOnly == true && sameSlot($0, record)) } + [record]
    try save(next)
    records = next
    changed()
  }

  func overlay(dayID: UUID, drafts: [TodayWorkoutSetRowDraft]) -> [TodayWorkoutSetRowDraft] {
    var next = records
    for index in next.indices where next[index].dayID == dayID && next[index].synced {
      let local = next[index].draft
      let server = drafts.first { $0.loggedSetID != nil && $0.loggedSetID == local.loggedSetID }
      if next[index].deleting && server == nil
        || server.map({
          $0.recordedAt.map { $0 >= (local.recordedAt ?? next[index].recordedAt) } == true
            && $0.completed == local.completed && $0.failed == local.failed
            && $0.actualWeight == local.actualWeight && $0.actualReps == local.actualReps
            && $0.actualRPE == local.actualRPE && $0.actualRIR == local.actualRIR
        }) == true
      {
        next[index].confirmed = true
      }
    }
    next.removeAll { $0.synced && ($0.confirmed || $0.loggedDate < receiptCutoff) }
    if (try? save(next)) != nil { records = next }
    return overlayPendingSets(drafts, dayID: dayID, records: records)
  }

  func start(network: (any UploadNetworkMonitoring)? = nil) {
    completionGate.start()
    active = true
    automatic = true
    if let network, networkTask == nil {
      networkTask = Task { [weak self] in
        for await available in network.updates {
          guard !Task.isCancelled else { return }
          if available { self?.networkRestored() }
        }
      }
    }
    wake()
  }

  func stop() {
    completionGate.stop()
    generation += 1
    active = false
    automatic = false
    retryTimer?.cancel()
    worker?.cancel()
    networkTask?.cancel()
    networkTask = nil
  }

  func networkRestored() {
    try? pruneReceipts()
    retryAttempt = 0
    retryTimer?.cancel()
    wake()
  }

  /// The selected day jumps ahead of backoff and other days. Rejected records
  /// are retried only on this explicit user action, never on network recovery.
  func retryNow(dayID: UUID? = nil) {
    try? pruneReceipts()
    priorityDay = dayID
    var next = records
    for index in next.indices where dayID == nil || next[index].dayID == dayID {
      next[index].rejected = false
    }
    do {
      try save(next)
      records = next
      changed()
    } catch { return }
    retryAttempt = 0
    retryTimer?.cancel()
    wake()
  }

  func drain() async {
    guard active, !draining else { return }
    draining = true
    let sendingGeneration = generation
    defer { draining = false }
    while active, !Task.isCancelled, let record = nextRecord() {
      do {
        let receipt = try await send(record)
        guard active, generation == sendingGeneration, !Task.isCancelled else { return }
        try acknowledge(record, receipt: receipt)
        retryAttempt = 0
        await onAcknowledged?(record, receipt)
      } catch SetSyncFailure.convertToAdded(let setIndex) {
        guard active, generation == sendingGeneration, !Task.isCancelled else { return }
        do { try convertToAdded(record, startingAt: setIndex) } catch { return }
      } catch SetSyncFailure.rejected {
        guard active, generation == sendingGeneration, !Task.isCancelled else { return }
        do { try reject(record) } catch { return }
      } catch {
        retryAttempt += 1
        return
      }
    }
  }

  private func nextRecord() -> PendingSetRecord? {
    let pending = records.filter(\.isPending)
    let eligible = pending.filter { record in
      !record.rejected
        && !pending.contains {
          $0.rejected && sameSlot($0, record)
        }
    }
    return eligible.first(where: { $0.dayID == priorityDay }) ?? eligible.first
  }

  private func sameSlot(_ first: PendingSetRecord, _ second: PendingSetRecord) -> Bool {
    first.dayID == second.dayID
      && (first.draft.id == second.draft.id
        || (first.draft.loggedSetID != nil && first.draft.loggedSetID == second.draft.loggedSetID)
        || (first.draft.planExerciseID == second.draft.planExerciseID
          && first.draft.prescribed.setIndex == second.draft.prescribed.setIndex))
  }

  private func wake() {
    guard automatic, active, worker == nil else { return }
    retryTimer?.cancel()
    worker = Task { [weak self] in
      guard let self else { return }
      await self.drain()
      self.worker = nil
      guard self.active, self.nextRecord() != nil else { return }
      let seconds = min(30, 1 << min(self.retryAttempt, 5))
      self.retryTimer = Task { [weak self, sleep = self.sleep] in
        do { try await sleep(.seconds(seconds)) } catch { return }
        guard !Task.isCancelled else { return }
        self?.wake()
      }
    }
  }

}

extension SetSyncQueue {
  private func reject(_ record: PendingSetRecord) throws {
    var next = records
    if let index = next.firstIndex(where: { $0.id == record.id }) {
      next[index].rejected = true
    }
    try save(next)
    records = next
    changed()
  }

  private func acknowledge(_ record: PendingSetRecord, receipt: SetSyncReceipt) throws {
    var next = records
    guard let index = next.firstIndex(where: { $0.id == record.id }) else { return }
    next[index].synced = true
    let canonicalID: UUID?
    switch receipt {
    case .planned(let log):
      canonicalID = log.id
      next[index].draft.recordedAt = log.loggedAt
      next[index].draft.actualWeight = log.weightKg
      next[index].draft.actualReps = log.reps
      next[index].draft.actualRPE = log.rpe
      next[index].draft.actualRIR = log.actualRIR
    case .added(let log):
      canonicalID = log.id
      next[index].draft.recordedAt = log.loggedAt
      next[index].draft.actualWeight = log.weightKg
      next[index].draft.actualReps = log.reps
      next[index].draft.actualRPE = log.rpe
      next[index].draft.actualRIR = log.actualRIR
      next[index].draft.studentAddedDayID = record.dayID
    case .deleted: canonicalID = nil
    }
    if let canonicalID {
      for slot in next.indices where next[slot].draftOnly != true && sameSlot(next[slot], record) {
        next[slot].draft.loggedSetID = canonicalID
        if case .added = receipt { next[slot].draft.studentAddedDayID = record.dayID }
      }
    }
    // Keep the latest acknowledgement until a server snapshot confirms it.
    next = next.enumerated().filter { offset, entry in
      !entry.synced || !next.dropFirst(offset + 1).contains { sameSlot($0, entry) }
    }.map(\.element)
    try save(next)
    records = next
    changed()
  }

  private func convertToAdded(_ record: PendingSetRecord, startingAt setIndex: Int) throws {
    var next = records
    let reserved = records.filter {
      $0.draftOnly != true && $0.draft.exerciseID == record.draft.exerciseID
        && $0.loggedDate == record.loggedDate
        && ($0.draft.isStudentAdded || $0.fallbackSetIndex != nil)
    }.map { $0.fallbackSetIndex ?? $0.draft.prescribed.setIndex }
    let available = max(setIndex, (reserved.max() ?? -1) + 1)
    for index in next.indices where next[index].draftOnly != true && sameSlot(next[index], record) {
      next[index].fallbackSetIndex = available
    }
    try save(next)
    records = next
  }

  private var receiptCutoff: String {
    let calendar = WorkoutDatePolicy.deviceCalendar
    let date = calendar.date(byAdding: .day, value: -14, to: now()) ?? now()
    let parts = calendar.dateComponents([.year, .month, .day], from: date)
    let year = String(parts.year ?? 0)
    let month = String(parts.month ?? 0)
    let day = String(parts.day ?? 0)
    return year + "-" + (month.count == 1 ? "0" : "") + month
      + "-" + (day.count == 1 ? "0" : "") + day
  }

  private func pruneReceipts() throws {
    let cutoff = receiptCutoff
    let next = records.filter { !$0.synced || (!$0.confirmed && $0.loggedDate >= cutoff) }
    guard next.count != records.count else { return }
    try save(next)
    records = next
  }

  func observe(_ callback: @escaping @MainActor () -> Void) -> UUID {
    let id = UUID()
    observers[id] = callback
    return id
  }

  func removeObserver(_ id: UUID) { observers[id] = nil }

  private func changed() {
    revision += 1
    for callback in Array(observers.values) { callback() }
  }

  private func save(_ next: [PendingSetRecord]) throws {
    try storage.write(JSONEncoder().encode(next), account: studentID, name: "sets")
  }
}
