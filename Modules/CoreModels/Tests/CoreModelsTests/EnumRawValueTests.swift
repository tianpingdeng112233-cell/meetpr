import CoreModels
import Foundation
import Testing

@Test func userRoleEncodesSnakeCaseRawValue() throws {
  try expectEncoded(UserRole.coachedStudent, contains: #""coached_student""#)
}

@Test func trainingModeEncodesSnakeCaseRawValue() throws {
  try expectEncoded(TrainingMode.selfTrain, contains: #""self_train""#)
}

@Test func genderEncodesBackendRawValue() throws {
  try expectEncoded(Gender.female, contains: #""F""#)
}

@Test func unitSystemEncodesRawValue() throws {
  try expectEncoded(UnitSystem.imperial, contains: #""imperial""#)
}

@Test func squatStanceEncodesSnakeCaseRawValue() throws {
  try expectEncoded(SquatStance.highBar, contains: #""high_bar""#)
}

@Test func deadliftStanceEncodesRawValue() throws {
  try expectEncoded(DeadliftStance.conventional, contains: #""conventional""#)
}

@Test func benchGripEncodesRawValue() throws {
  try expectEncoded(BenchGrip.wide, contains: #""wide""#)
}

@Test func gymTierEncodesSnakeCaseRawValue() throws {
  try expectEncoded(GymTier.homeWithRack, contains: #""home_with_rack""#)
}

@Test func bindRequestStatusEncodesRawValue() throws {
  try expectEncoded(BindRequestStatus.cancelled, contains: #""cancelled""#)
}

@Test func inviteCodeTypeEncodesSnakeCaseRawValue() throws {
  try expectEncoded(InviteCodeType.personalPermanent, contains: #""personal_permanent""#)
}

private func expectEncoded<Value: Encodable>(_ value: Value, contains rawValue: String) throws {
  let json = try encodedJSONString(value)

  #expect(json.contains(rawValue))
}
