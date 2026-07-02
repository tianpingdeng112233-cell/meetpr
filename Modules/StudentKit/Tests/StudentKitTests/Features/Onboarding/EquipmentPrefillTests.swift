import CoreModels
import Foundation
import Testing

@testable import StudentKit

@Test func catalogHasTwentyThreeUniqueTokensWithinZodBounds() {
  let tokens = EquipmentCatalog.items.map(\.token)
  #expect(tokens.count == 23)
  #expect(Set(tokens).count == 23)  // zod uniqueItems
  for token in tokens {
    #expect(!token.isEmpty)
    #expect(token.count <= 50)  // zod per-item max(50)
  }
  #expect(tokens.count <= 30)  // zod max(30) items
}

@Test func groupsPartitionTheCatalog() {
  var seen = 0
  for group in EquipmentItem.Group.allCases {
    let items = EquipmentCatalog.items(in: group)
    #expect(!items.isEmpty)
    seen += items.count
  }
  #expect(seen == EquipmentCatalog.items.count)
}

@Test func homeTierPrefillsBasicsAndBucket() {
  #expect(
    EquipmentCatalog.prefill(for: .homeWithRack) == [
      "barbell_dumbbell", "squat_bench_rack", "pullup_bar", "db_max_20",
    ])
}

@Test func commercialTierPrefillsTenItems() {
  let prefill = EquipmentCatalog.prefill(for: .commercial)
  #expect(prefill.count == 10)
  #expect(prefill.contains("smith_machine"))
  #expect(prefill.contains("db_max_40"))
  #expect(prefill.contains("landmine"))
  // Research: 商业房无专项杆 / 微增片 / 海豹划船凳 → not prefilled.
  #expect(!prefill.contains("power_bar_stiff"))
  #expect(!prefill.contains("fractional_plates"))
  #expect(!prefill.contains("seal_row"))
}

@Test func professionalTierPrefillsTwentyItems() {
  let prefill = EquipmentCatalog.prefill(for: .professional)
  #expect(prefill.count == 20)
  #expect(prefill.contains("power_bar_stiff"))
  #expect(prefill.contains("deadlift_bar"))
  #expect(prefill.contains("seal_row"))
  #expect(prefill.contains("fractional_plates"))
  #expect(prefill.contains("rack_pins_blocks"))
  // Research: Smith rare in PL gyms; 40kg bucket, not 40+.
  #expect(!prefill.contains("smith_machine"))
  #expect(!prefill.contains("db_max_40_plus"))
  #expect(prefill.count <= 30)  // zod max(30) items
}

@Test func everyTokenGatesCoachProgramming() {
  // Selection rule (v2, David 2026-07-02): comp-environment facts that
  // don't change what the coach programs stay out of the vocabulary.
  let tokens = Set(EquipmentCatalog.items.map(\.token))
  #expect(!tokens.contains("calibrated_plates"))
  #expect(!tokens.contains("chalk_allowed"))
  #expect(!tokens.contains("combo_rack"))
  // v2.2: dropped per David — 国内几乎没有,教练不会排进计划.
  #expect(!tokens.contains("reverse_hyper"))
}

@Test func everyTierPrefillsExactlyOneDumbbellBucket() {
  let bucket = Set(EquipmentCatalog.dumbbellMaxTokens)
  #expect(bucket.count == 3)
  for tier in GymTier.allCases {
    let picked = EquipmentCatalog.prefill(for: tier).filter(bucket.contains)
    #expect(picked.count == 1, "tier \(tier) must seed exactly one dumbbell cap")
  }
}

@Test func labelsResolveForEveryToken() {
  for item in EquipmentCatalog.items {
    #expect(EquipmentCatalog.label(for: item.token) == item.label)
  }
  #expect(EquipmentCatalog.label(for: "unknown_token") == "unknown_token")
}

@Test func retiredV1TokensStillResolveLabels() {
  // Profiles saved before the v2 vocabulary must keep rendering (D3:
  // overrides store the checked set verbatim, no migration on read).
  #expect(EquipmentCatalog.label(for: "heavy_dumbbells") == "哑铃区(>30kg)")
  #expect(EquipmentCatalog.label(for: "blocks_chains_bands") == "块铃 / 链子 / 弹力带")
  #expect(EquipmentCatalog.label(for: "reverse_hyper") == "反向过伸机")
}
