import Foundation

public enum MovementPattern: String, Codable, Hashable, Sendable, CaseIterable {
  case squat = "squat"
  case horizontalPush = "horizontal_push"
  case verticalPush = "vertical_push"
  case hipHinge = "hip_hinge"
  case horizontalPull = "horizontal_pull"
  case verticalPull = "vertical_pull"
  case other = "other"
  case warmUp = "warm_up"
}
