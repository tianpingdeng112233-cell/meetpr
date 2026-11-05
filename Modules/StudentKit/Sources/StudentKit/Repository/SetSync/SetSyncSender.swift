import CoreModels
import Foundation
import Networking
import RepositoryContracts

/// The wire adapter is shared by cold-start recovery and mounted workout views.
@MainActor struct SetSyncSender {
  let logs: any StudentTrainingLogRepository
  var plans: (any StudentPlanRepository)?
  var videos: VideoUploadManager?

  func send(_ record: PendingSetRecord) async throws -> SetSyncReceipt {
    do {
      let receipt = try await write(record)
      await bindPendingVideos(record, receipt: receipt)
      return receipt
    } catch let error as APIError {
      if case .httpStatus(let status, _) = error, (400..<500).contains(status),
        status != 408 && status != 429
      {
        throw SetSyncFailure.rejected
      }
      throw error
    } catch let error as APIClientError {
      if case .httpStatus(let status, _) = error, (400..<500).contains(status),
        status != 408 && status != 429
      {
        throw SetSyncFailure.rejected
      }
      throw error
    }
  }

  private func write(_ record: PendingSetRecord) async throws -> SetSyncReceipt {
    if record.deleting {
      if let id = record.draft.loggedSetID {
        guard let repository = logs as? any StudentAddedLogRepository else {
          throw SetSyncFailure.rejected
        }
        try await repository.deleteAddedSet(id: id, studentID: record.studentID)
      }
      return .deleted
    }
    if record.draft.isStudentAdded || record.fallbackSetIndex != nil {
      return try await writeAdded(record)
    }
    do {
      return .planned(try await logs.recordSet(record.plannedLog))
    } catch {
      guard Self.isMissingPlanExercise(error) else { throw error }
      // This 400 also covers unpublished or inaccessible plans. Only a fresh
      // published plan containing the original day can prove an exercise deletion.
      guard let plans,
        let plan = try await plans.refreshCurrentPlan(studentID: record.studentID),
        let day = plan.days.first(where: { $0.id == record.dayID }),
        !day.exercises.contains(where: { $0.id == record.draft.planExerciseID })
      else { throw SetSyncFailure.rejected }
      guard let repository = logs as? any StudentAddedLogRepository else {
        throw SetSyncFailure.rejected
      }
      let history = try await repository.fetchAllLogs(
        studentID: record.studentID, in: Date(timeIntervalSince1970: 0)...Date())
      guard history.isAuthoritative else { throw URLError(.cannotParseResponse) }
      let occupied = history.added.filter {
        $0.exerciseID == record.draft.exerciseID && $0.loggedDate == record.loggedDate
      }.map(\.setIndex)
      // Persist the allocation before sending. A lost response then retries the same slot.
      throw SetSyncFailure.convertToAdded((occupied.max() ?? -1) + 1)
    }
  }

  private func writeAdded(_ record: PendingSetRecord) async throws -> SetSyncReceipt {
    guard let repository = logs as? any StudentAddedLogRepository else {
      throw SetSyncFailure.rejected
    }
    let log = record.plannedLog
    let added = StudentAddedSetLog(
      id: log.id, studentID: record.studentID, planDayID: record.dayID,
      exerciseID: record.draft.exerciseID, setIndex: record.fallbackSetIndex ?? log.setIndex,
      loggedAt: log.loggedAt, loggedDate: record.loggedDate,
      weightKg: log.weightKg, reps: log.reps, rpe: log.rpe, actualRIR: log.actualRIR,
      completed: log.completed, failed: log.failed)
    return .added(try await repository.recordAddedSet(added))
  }

  private static func isMissingPlanExercise(_ error: Error) -> Bool {
    let response: (Int, Data)
    switch error {
    case APIError.httpStatus(let status, let data): response = (status, data)
    case APIClientError.httpStatus(let status, let data): response = (status, data)
    default: return false
    }
    guard response.0 == 400,
      let envelope = try? JSONDecoder().decode(ErrorEnvelope.self, from: response.1)
    else { return false }
    return envelope.error == "SETS_PLAN_EXERCISE_NOT_PUBLISHED"
  }

  private struct ErrorEnvelope: Decodable { let error: String }

  private func bindPendingVideos(_ record: PendingSetRecord, receipt: SetSyncReceipt) async {
    guard let videos else { return }
    let setID: UUID
    switch receipt {
    case .planned(let log): setID = log.id
    case .added(let log): setID = log.id
    case .deleted: return
    }
    for attachment in await videos.attachments(studentID: record.studentID)
    where attachment.awaitsSet(
      draftID: record.draft.id, trainingDate: record.trainingDate,
      slot: record.draft.pendingVideoSlot)
    {
      // #403 owns retained files, replacement ordering, and upload recovery.
      // A binding failure leaves that durable pending record untouched.
      _ = try? await videos.bindPending(recordID: attachment.id, setLogID: setID)
    }
  }
}
