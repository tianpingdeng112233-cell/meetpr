import Testing

@testable import CoreModels

private let softJump = 0.10
private let hardJump = 0.18

private func verdict(newE1RMKg: Double, priorBestKg: Double?) -> E1RMAnomalyClassifier.Verdict {
  E1RMAnomalyClassifier.classify(
    newE1RMKg: newE1RMKg,
    priorNormalBestKg: priorBestKg,
    softJump: softJump,
    hardJump: hardJump
  )
}

@Test func anomalyClassifierTrustsColdStartAndNonPositiveBaselines() {
  #expect(verdict(newE1RMKg: 200, priorBestKg: nil) == .normal)
  #expect(verdict(newE1RMKg: 200, priorBestKg: 0) == .normal)
  #expect(verdict(newE1RMKg: 200, priorBestKg: -1) == .normal)
}

@Test func anomalyClassifierKeepsNormalChangesTrusted() {
  #expect(verdict(newE1RMKg: 180, priorBestKg: 200) == .normal)
  #expect(verdict(newE1RMKg: 204, priorBestKg: 200) == .normal)
  #expect(verdict(newE1RMKg: 220, priorBestKg: 200) == .normal)
}

@Test func anomalyClassifierQuarantinesSoftAnomalies() {
  #expect(verdict(newE1RMKg: 224, priorBestKg: 200) == .lowConfidence)
  #expect(verdict(newE1RMKg: 236, priorBestKg: 200) == .lowConfidence)
}

@Test func anomalyClassifierFlagsHardAnomaliesForFutureConfirmation() {
  #expect(verdict(newE1RMKg: 350, priorBestKg: 200) == .suspectHard)
}
