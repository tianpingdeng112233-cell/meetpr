import CoreModels
import Foundation
import RepositoryContracts

public actor InMemoryReadinessRepository: ReadinessRepository {
  private var checkins: [String: ReadinessCheckin]

  public init(seed: [ReadinessCheckin] = []) {
    var initial: [String: ReadinessCheckin] = [:]
    for checkin in seed {
      initial[Self.key(checkin.studentId, checkin.checkinDate)] = checkin
    }
    self.checkins = initial
  }

  public func submit(_ checkin: ReadinessCheckin) async throws {
    checkins[Self.key(checkin.studentId, checkin.checkinDate)] = checkin
  }

  public func fetchCheckin(
    studentId: UUID,
    checkinDate: String
  ) async throws -> ReadinessCheckin? {
    checkins[Self.key(studentId, checkinDate)]
  }

  private static func key(_ studentId: UUID, _ checkinDate: String) -> String {
    "\(studentId.uuidString)|\(checkinDate)"
  }
}
