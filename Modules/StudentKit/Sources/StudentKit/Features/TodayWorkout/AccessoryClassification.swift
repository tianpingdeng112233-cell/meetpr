import CoreModels

/// The plan's main-lift flag never determines this recording flow.
enum AccessoryClassification {
  static func isAccessory(exerciseType: ExerciseType?) -> Bool {
    exerciseType == .accessory
  }
}
