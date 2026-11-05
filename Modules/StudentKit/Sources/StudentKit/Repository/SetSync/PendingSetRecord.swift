import CoreModels
import Foundation

struct PendingSetRecord: Codable, Sendable, Identifiable {
  let id: UUID
  let studentID: UUID
  let dayID: UUID
  let trainingDate: Date
  var draft: TodayWorkoutSetRowDraft
  let recordedAt: Date
  var loggedDate: String
  var deleting = false
  var rejected = false
  var synced = false
  var confirmed = false
  var fallbackSetIndex: Int?
  // Optional for compatibility with queue files written before draft persistence.
  var draftOnly: Bool?

  var isPending: Bool { !synced && draftOnly != true }

  var plannedLog: StudentSetLog {
    TodayWorkoutViewModel.makeLog(
      from: draft, studentID: studentID, completed: draft.completed,
      failed: draft.failed, loggedAt: recordedAt, loggedDate: loggedDate)
  }
}

enum SetSyncReceipt: Sendable {
  case planned(StudentSetLog)
  case added(StudentAddedSetLog)
  case deleted
}

/// Last local operation wins, including cancellation and deletion. Matching a
/// stable slot also works when a refreshed snapshot has new editor identities.
func overlayPendingSets(
  _ drafts: [TodayWorkoutSetRowDraft], dayID: UUID, records: [PendingSetRecord]
) -> [TodayWorkoutSetRowDraft] {
  var result = drafts
  for record in records where record.dayID == dayID && !record.confirmed {
    if record.fallbackSetIndex != nil, let loggedID = record.draft.loggedSetID,
      result.contains(where: { $0.isStudentAdded && $0.loggedSetID == loggedID })
    {
      // A cached plan can still contain the deleted slot after its added log
      // arrives. Replace that slot with the server row before applying the receipt.
      result.removeAll {
        !$0.isStudentAdded
          && ($0.id == record.draft.id
            || ($0.planExerciseID == record.draft.planExerciseID
              && $0.prescribed.setIndex == record.draft.prescribed.setIndex))
      }
    }
    let index = result.firstIndex {
      ($0.loggedSetID != nil && $0.loggedSetID == record.draft.loggedSetID)
        || $0.id == record.draft.id
        || ($0.planExerciseID == record.draft.planExerciseID
          && $0.prescribed.setIndex == record.draft.prescribed.setIndex
          && $0.isStudentAdded == record.draft.isStudentAdded)
    }
    if record.deleting {
      if let index { result.remove(at: index) }
    } else if let index, record.draftOnly == true {
      result[index] = record.draft
    } else if let index {
      // Prescriptions belong to the server; only local execution fields overlay them.
      result[index].actualWeight = record.draft.actualWeight
      result[index].actualReps = record.draft.actualReps
      result[index].actualRPE = record.draft.actualRPE
      result[index].actualRIR = record.draft.actualRIR
      result[index].completed = record.draft.completed
      result[index].failed = record.draft.failed
      result[index].assumed = record.draft.assumed
      result[index].recordedAt = record.draft.recordedAt
      result[index].loggedSetID = record.draft.loggedSetID ?? result[index].loggedSetID
      if let slot = record.fallbackSetIndex { result[index].useAddedSlot(slot, dayID: dayID) }
    } else {
      var draft = record.draft
      if let index = record.fallbackSetIndex {
        draft.useAddedSlot(index, dayID: dayID)
      }
      result.append(draft)
    }
  }
  return result
}

enum SetSyncFailure: Error {
  case rejected
  case convertToAdded(Int)
}

extension TodayWorkoutSetRowDraft {
  mutating func useAddedSlot(_ index: Int, dayID: UUID) {
    studentAddedDayID = dayID
    let old = prescribed
    prescribed = PrescribedSet(
      id: old.id, setIndex: index, weightKg: old.weightKg, intensity: old.intensity,
      percentageAnchor: old.percentageAnchor, loadMode: old.loadMode, reps: old.reps,
      repsMax: old.repsMax, restSeconds: old.restSeconds, coachNote: old.coachNote)
  }
}
