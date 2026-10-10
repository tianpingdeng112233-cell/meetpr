import CoreModels
import Testing

@testable import StudentKit

@Test func accessoryClassificationRequiresResolvedCatalogType() {
  #expect(AccessoryClassification.isAccessory(exerciseType: .accessory))
  #expect(!AccessoryClassification.isAccessory(exerciseType: .mainLift))
  #expect(!AccessoryClassification.isAccessory(exerciseType: .mainLiftVariation))
  #expect(!AccessoryClassification.isAccessory(exerciseType: nil))
  #expect(!AccessoryClassification.isAccessory(exerciseType: ExerciseType(rawValue: "unknown")))
}
