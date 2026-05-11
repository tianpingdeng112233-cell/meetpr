import Foundation
import Testing

@testable import CoachKit

@available(iOS 17.0, macOS 14.0, *)
@Test func weightInputFieldKgToPercentBasicConversion() {
  #expect(WeightInputField.kgToPercent(100, oneRM: 200) == Decimal(50))
  #expect(WeightInputField.kgToPercent(150, oneRM: 200) == Decimal(75))
  #expect(WeightInputField.kgToPercent(180, oneRM: 200) == Decimal(90))
}

@available(iOS 17.0, macOS 14.0, *)
@Test func weightInputFieldPercentToKgBasicConversion() {
  #expect(WeightInputField.percentToKg(50, oneRM: 200) == Decimal(100))
  #expect(WeightInputField.percentToKg(75, oneRM: 200) == Decimal(150))
  #expect(WeightInputField.percentToKg(90, oneRM: 200) == Decimal(180))
}

@available(iOS 17.0, macOS 14.0, *)
@Test func weightInputFieldRoundTripStableAtCommonBenchmark() {
  let percent = WeightInputField.kgToPercent(150, oneRM: 200)
  #expect(percent == Decimal(75))
  let kgBack = WeightInputField.percentToKg(percent.planningDoubleValue, oneRM: 200)
  #expect(kgBack == Decimal(150))
}

@available(iOS 17.0, macOS 14.0, *)
@Test func weightInputFieldKgToPercentRoundsResultToHalfPercent() throws {
  // 50.5 / 200 * 100 = 25.25 → rounds to 25.5 at 0.5 increment
  let expected = try #require(Decimal(string: "25.5"))
  #expect(WeightInputField.kgToPercent(50.5, oneRM: 200) == expected)
}

@available(iOS 17.0, macOS 14.0, *)
@Test func weightInputFieldPercentToKgRoundsResultToHalfKg() throws {
  // 180 * 67 / 100 = 120.6 → rounds to 120.5 at 0.5 increment
  let expected = try #require(Decimal(string: "120.5"))
  #expect(WeightInputField.percentToKg(67, oneRM: 180) == expected)
}

@available(iOS 17.0, macOS 14.0, *)
@Test func weightInputFieldRoundsRawInputBeforeConverting() throws {
  // raw input 100.7 first rounds to 100.5; 100.5/200*100 = 50.25 → 50.5
  let expected = try #require(Decimal(string: "50.5"))
  #expect(WeightInputField.kgToPercent(100.7, oneRM: 200) == expected)
}

@available(iOS 17.0, macOS 14.0, *)
@Test func weightInputFieldZeroOneRMReturnsZero() {
  #expect(WeightInputField.kgToPercent(100, oneRM: 0) == 0)
  #expect(WeightInputField.percentToKg(80, oneRM: 0) == 0)
}

@available(iOS 17.0, macOS 14.0, *)
@Test func weightInputFieldNegativeOneRMReturnsZero() {
  #expect(WeightInputField.kgToPercent(100, oneRM: -10) == 0)
  #expect(WeightInputField.percentToKg(80, oneRM: -10) == 0)
}
