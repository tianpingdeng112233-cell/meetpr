import CoreModels
import Foundation

struct VideoDeliverySnapshot: Sendable {
  let records: [VideoAttachment]
  let preparingCount: Int
  let outstandingCount: Int
  var delivered: Bool { preparingCount == 0 && records.allSatisfy { $0.status == .uploaded } }
}

struct VideoSelectionScope: Hashable {
  let studentID: UUID
  let trainingDate: Date?
  let setLogID: UUID?
  let draftID: UUID?
}

extension VideoUploadManager {
  func installCompletionRecovery(_ recovery: @escaping @Sendable (VideoUploadManager) async -> Void)
  {
    completionRecovery = recovery
  }

  func registerCompletionAccount(_ studentID: UUID) {
    recoveringStudentIDs.insert(studentID)
  }

  func beginSelection(
    studentID: UUID, trainingDate: Date?, setLogID: UUID? = nil, draftID: UUID? = nil
  ) -> UUID {
    let token = UUID()
    preparingSelections[token] = VideoSelectionScope(
      studentID: studentID, trainingDate: trainingDate, setLogID: setLogID, draftID: draftID)
    selectionRevision += 1
    return token
  }

  func finishSelection(_ token: UUID) {
    preparingSelections[token] = nil
    selectionRevision += 1
    Task { await completionRecovery?(self) }
  }

  /// A failed read never looks delivered. Selection is registered before source
  /// probing/retention awaits, so an old uploaded replacement cannot release the gate.
  func deliverySnapshot(studentID: UUID, trainingDate: Date) async throws -> VideoDeliverySnapshot {
    while true {
      let revision = selectionRevision
      let records = try await repository.fetchAll(studentID: studentID)
      guard revision == selectionRevision else { continue }
      let dayRecords = records.filter { $0.trainingDate == trainingDate }
      let preparing = Set(
        preparingSelections.values.filter {
          $0.studentID == studentID && ($0.trainingDate == nil || $0.trainingDate == trainingDate)
        })
      let outstanding = dayRecords.filter { $0.status != .uploaded }
      let notYetRecorded = preparing.filter { selection in
        !outstanding.contains { record in
          selection.setLogID == record.setLogID
            || (selection.draftID != nil && selection.draftID == record.pendingDraftID)
        }
      }.count
      return VideoDeliverySnapshot(
        records: dayRecords, preparingCount: preparing.count,
        outstandingCount: outstanding.count + notYetRecorded)
    }
  }
}
