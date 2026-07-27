import CoreModels
import Foundation

public actor StudentPlanCache {
  // v2 invalidates projections whose PrescribedSet.setIndex was cached as
  // one-based before the execution domain standardized on zero-based indexes.
  private static let fileVersion = 2
  private let store: JSONFileCache<StudentPlanView>

  public init(directory: URL? = nil) {
    store = JSONFileCache(directory: directory)
  }

  public func save(plan: StudentPlanView, studentID: UUID) async throws {
    try await store.save(plan, fileName: fileName(studentID: studentID))
  }

  public func loadPlan(studentID: UUID) async -> StudentPlanView? {
    await store.load(fileName: fileName(studentID: studentID))
  }

  private func fileName(studentID: UUID) -> String {
    "student-\(studentID.uuidString)-plan-v\(Self.fileVersion).json"
  }
}
