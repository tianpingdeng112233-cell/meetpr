import CoreModels
import Foundation
import RepositoryContracts

/// Shared in-memory plan-projection store for DEMO_MODE and tests.
///
/// The coach publish path writes published `StudentPlanView` projections here;
/// the student read path reads them. Process-scoped: cleared when the app is
/// killed. That is acceptable for V0.1 — real cross-device persistence (coach
/// publishes on one device, student fetches on another) is spec 026's backend
/// wiring, not this in-memory store.
public actor InMemoryPlanStore: StudentPlanStore {
  private var projections: [UUID: StudentPlanView] = [:]

  public init() {}

  public func savePublishedProjection(
    _ projection: StudentPlanView,
    forStudent studentID: UUID
  ) async {
    projections[studentID] = projection
  }

  public func getPublishedProjection(forStudent studentID: UUID) async -> StudentPlanView? {
    projections[studentID]
  }
}
