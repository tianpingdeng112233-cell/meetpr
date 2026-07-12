import Foundation

/// Catalog discriminator for competition-equivalent lift variants.
public enum CompetitionStance: String, Codable, Hashable, Sendable, CaseIterable {
  case lowBar = "low_bar"
  case highBar = "high_bar"
  case conventional = "conventional"
  case sumo = "sumo"
}
