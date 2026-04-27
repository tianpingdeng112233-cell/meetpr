import Foundation

public enum UserRole: String, Codable, Hashable, Sendable, CaseIterable {
  case coach = "coach"
  case coachedStudent = "coached_student"
  case selfTrainStudent = "self_train_student"
}
