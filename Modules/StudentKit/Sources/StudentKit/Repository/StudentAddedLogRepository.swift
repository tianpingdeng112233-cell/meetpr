import CoreModels
import Foundation
import RepositoryContracts

/// Student-only execution capability; plan-only repository consumers retain their original contract.
public protocol StudentAddedLogRepository: StudentTrainingLogRepository {
  func fetchAllLogs(studentID: UUID, in range: ClosedRange<Date>) async throws -> StudentWorkoutLogs
  func recordAddedSet(_ log: StudentAddedSetLog) async throws -> StudentAddedSetLog
  func deleteAddedSet(id: UUID, studentID: UUID) async throws
}

public struct StudentWorkoutLogs: Sendable {
  public let planned: [StudentSetLog]
  public let added: [StudentAddedSetLog]
  public let isAuthoritative: Bool
  public let isCompleteLedger: Bool

  public init(
    planned: [StudentSetLog], added: [StudentAddedSetLog],
    isAuthoritative: Bool = true, isCompleteLedger: Bool = false
  ) {
    self.planned = planned
    self.added = added
    self.isAuthoritative = isAuthoritative
    self.isCompleteLedger = isCompleteLedger
  }
}
