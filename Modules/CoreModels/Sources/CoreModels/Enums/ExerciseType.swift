import Foundation

public enum ExerciseType: String, Codable, Hashable, Sendable, CaseIterable {
  case mainLift = "main_lift"
  case mainLiftVariation = "main_lift_variation"
  case accessory = "accessory"
}
