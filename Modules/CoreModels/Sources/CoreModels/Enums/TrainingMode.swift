import Foundation

public enum TrainingMode: String, Codable, Hashable, Sendable, CaseIterable {
  case coached = "coached"
  case selfTrain = "self_train"
}
