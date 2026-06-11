import CoreModels
import Foundation

public actor StudentPlanCache {
  private let store: JSONFileCache<StudentPlanView>

  public init(directory: URL? = nil) {
    store = JSONFileCache(directory: directory)
  }

  public func save(plan: StudentPlanView, studentID: UUID) async throws {
    try await store.save(plan, fileName: "student-\(studentID.uuidString)-plan.json")
  }

  public func loadPlan(studentID: UUID) async -> StudentPlanView? {
    await store.load(fileName: "student-\(studentID.uuidString)-plan.json")
  }
}
