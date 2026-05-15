import Foundation

public enum MovementPattern: String, Codable, Hashable, Sendable, CaseIterable {
  case warmUp = "warm_up"
  case horizontalPush = "horizontal_push"
  case horizontalPull = "horizontal_pull"
  case verticalPush = "vertical_push"
  case verticalPull = "vertical_pull"
  case squat = "squat"
  case hipHinge = "hip_hinge"
  case other = "other"
}
