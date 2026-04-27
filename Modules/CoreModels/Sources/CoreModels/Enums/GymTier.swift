import Foundation

public enum GymTier: String, Codable, Hashable, Sendable, CaseIterable {
  case homeWithRack = "home_with_rack"
  case commercial = "commercial"
  case professional = "professional"
}
