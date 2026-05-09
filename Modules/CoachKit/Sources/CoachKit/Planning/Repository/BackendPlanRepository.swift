import CoreModels
import Foundation

// swiftlint:disable:next todo
// TODO: spec NNN backend wiring.
public struct BackendPlanRepository: Sendable {
  public init() {}

  public func fetchAccessoryExercises(filters: AccessoryFilters) async throws -> [Exercise] {
    _ = filters
    fatalError("TODO: spec 006 backend wiring")
  }
}
