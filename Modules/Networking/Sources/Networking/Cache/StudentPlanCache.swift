import CoreModels
import Foundation

public actor StudentPlanCache {
  private let store: JSONFileCache<[TrainingPlan]>

  public init(directory: URL? = nil) {
    store = JSONFileCache(directory: directory)
  }

  public func save(plans: [TrainingPlan], studentID: UUID) async throws {
    try await store.save(plans, fileName: "student-\(studentID.uuidString)-plans.json")
  }

  public func loadPlans(studentID: UUID) async -> [TrainingPlan]? {
    await store.load(fileName: "student-\(studentID.uuidString)-plans.json")
  }
}
