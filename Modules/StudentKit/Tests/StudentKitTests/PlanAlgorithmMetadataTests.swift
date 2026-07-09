import Foundation
import Testing

@testable import StudentKit

@Test func algorithmMetadataBuildsChineseBadgesAndFreshTM() throws {
  let metadata = PlanAlgorithmMetadata(
    blockType: "strength",
    mesocyclePhase: "intensification",
    trainingMax: Decimal(string: "92.5"),
    tmSetAt: date("2026-07-01T00:00:00Z")
  )

  let badges = metadata.badges(now: date("2026-07-20T00:00:00Z"))

  #expect(badges.map(\.title) == ["力量块", "强化", "训练最大值 ≈ 0.9×1RM 92.5kg"])
  #expect(badges.allSatisfy { $0.tone == .normal })
}

@Test func algorithmMetadataHidesNilAndUnknownFields() {
  let metadata = PlanAlgorithmMetadata(
    blockType: nil,
    mesocyclePhase: "unknown_phase",
    trainingMax: nil,
    tmSetAt: nil
  )

  #expect(metadata.badges().isEmpty)
  #expect(metadata.isEmpty)
}

@Test func algorithmMetadataMarksTMStaleAfterSixWeeks() throws {
  let metadata = PlanAlgorithmMetadata(
    blockType: nil,
    mesocyclePhase: nil,
    trainingMax: Decimal(string: "90"),
    tmSetAt: date("2026-07-01T00:00:00Z")
  )

  let boundary = metadata.badges(now: date("2026-08-12T00:00:00Z"))
  let stale = metadata.badges(now: date("2026-08-12T00:00:01Z"))

  #expect(boundary.first?.title == "训练最大值 ≈ 0.9×1RM 90kg")
  #expect(boundary.first?.tone == .normal)
  #expect(stale.first?.title == "训练最大值 ≈ 0.9×1RM 90kg · 需复测")
  #expect(stale.first?.tone == .stale)
}

private func date(_ rawValue: String) -> Date {
  ISO8601DateFormatter().date(from: rawValue) ?? Date(timeIntervalSince1970: 0)
}
