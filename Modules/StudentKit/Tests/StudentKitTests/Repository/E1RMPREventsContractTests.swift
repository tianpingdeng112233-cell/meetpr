import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import StudentKit

/// Contract tests for `prEvents(studentId:since:)` across both repository
/// implementations: time boundary is inclusive, students are isolated,
/// results sort ascending, and acknowledgement state is irrelevant.
@Suite struct E1RMPREventsContractTests {
  private let student = UUID()
  private let otherStudent = UUID()
  private let anchor = Date(timeIntervalSince1970: 1_774_000_000)

  private func event(
    studentId: UUID,
    offsetDays: Double,
    valueKg: Double,
    acknowledged: Bool = false
  ) -> PRBreakthroughEvent {
    let occurredAt = anchor.addingTimeInterval(offsetDays * 86_400)
    return PRBreakthroughEvent(
      id: UUID(),
      studentId: studentId,
      exerciseId: UUID(),
      pointId: UUID(),
      breakthroughE1RMKg: valueKg,
      previousMaxE1RMKg: valueKg - 5,
      occurredAt: occurredAt,
      acknowledgedAt: acknowledged ? occurredAt : nil
    )
  }

  private func repositories() -> [any E1RMRepository] {
    [
      InMemoryE1RMRepository(),
      LocalE1RMRepository(
        directory: FileManager.default.temporaryDirectory
          .appendingPathComponent("pr-contract-\(UUID().uuidString)")
      ),
    ]
  }

  @Test func windowIsInclusiveIsolatedSortedAndAckIndependent() async throws {
    for repository in repositories() {
      try await repository.recordPR(
        event(studentId: student, offsetDays: -10, valueKg: 100)
      )
      try await repository.recordPR(
        event(studentId: student, offsetDays: 0, valueKg: 110, acknowledged: true)
      )
      try await repository.recordPR(
        event(studentId: student, offsetDays: 5, valueKg: 105)
      )
      try await repository.recordPR(
        event(studentId: otherStudent, offsetDays: 5, valueKg: 999)
      )

      let events = try await repository.prEvents(studentId: student, since: anchor)

      // -10d excluded, boundary 0d included even though acknowledged,
      // other student's event isolated, ascending order by occurredAt.
      #expect(events.map(\.breakthroughE1RMKg) == [110, 105])
      #expect(events.map(\.occurredAt) == events.map(\.occurredAt).sorted())
    }
  }
}
