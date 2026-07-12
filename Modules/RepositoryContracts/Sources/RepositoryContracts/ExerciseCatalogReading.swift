import CoreModels

/// Read-only exercise catalog seam for client-side history rebuilds.
public protocol ExerciseCatalogReading: Sendable {
  func fetchExerciseCatalog() async throws -> [Exercise]
}
