import Foundation

/// Student-only weight history. The profile remains the shared current-weight read surface.
protocol BodyWeightRepository: Sendable {
  func fetchBodyWeights() async throws -> [BodyWeightRecord]
  func saveTodaysWeight(_ kilograms: Decimal) async throws -> Decimal?
  func deleteBodyWeight(on date: String) async throws -> Decimal?
}

struct BodyWeightRecord: Equatable, Identifiable, Sendable {
  let recordedOn: String
  let weightKg: Decimal
  var id: String { recordedOn }
}

enum BodyWeightError: Error { case unavailable, notFound }
