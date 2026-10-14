import CoreModels
import Foundation

/// Fresh server names override bundled names without hiding logs when the catalog is offline.
enum CoachDayExerciseCatalog {
  static let bundled: [UUID: Exercise] = Dictionary(
    (InMemoryPlanRepository.syntheticCompetitionLifts()
      + InMemoryPlanRepository.loadBundledCatalogV2())
      .map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

  static func load(planning: (any PlanRepository)?) async -> [UUID: Exercise] {
    guard let planning else { return bundled }
    async let main = try? planning.fetchMainLiftCatalog()
    async let accessories = try? planning.fetchAccessoryExercises(filters: .empty)
    let fresh = await (main ?? []) + (accessories ?? [])
    return bundled.merging(
      Dictionary(
        fresh.map { ($0.id, $0) },
        uniquingKeysWith: { first, _ in first }), uniquingKeysWith: { _, fresh in fresh })
  }
}
