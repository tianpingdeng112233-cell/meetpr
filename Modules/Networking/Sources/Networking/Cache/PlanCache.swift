import Foundation

public actor PlanCache {
  private let store: JSONFileCache<TrainingPlanTree>

  public init(directory: URL? = nil) {
    store = JSONFileCache(directory: directory)
  }

  public func save(plan: TrainingPlanTree) async throws {
    try await store.save(plan, fileName: "plan-\(plan.plan.id.uuidString).json")
  }

  public func loadPlan(id: UUID) async -> TrainingPlanTree? {
    await store.load(fileName: "plan-\(id.uuidString).json")
  }
}
