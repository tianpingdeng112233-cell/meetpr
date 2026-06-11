import CoreModels
import Foundation
import Testing

@testable import StudentKit

@Test func catalogHasThirteenUniqueTokensWithinZodBounds() {
  let tokens = EquipmentCatalog.items.map(\.token)
  #expect(tokens.count == 13)
  #expect(Set(tokens).count == 13)  // zod uniqueItems
  for token in tokens {
    #expect(!token.isEmpty)
    #expect(token.count <= 50)  // zod per-item max(50)
  }
  #expect(tokens.count <= 30)  // zod max(30) items
}

@Test func homeTierPrefillsTheThreeBasics() {
  #expect(
    EquipmentCatalog.prefill(for: .homeWithRack) == [
      "barbell_dumbbell", "squat_bench_rack", "pullup_bar",
    ])
}

@Test func commercialTierPrefillsNineItems() {
  let prefill = EquipmentCatalog.prefill(for: .commercial)
  #expect(prefill.count == 9)
  #expect(prefill.contains("cable_lat_pulldown"))
  #expect(prefill.contains("seated_row"))
  #expect(!prefill.contains("lifting_platform"))
  #expect(!prefill.contains("safety_bar"))
}

@Test func professionalTierPrefillsAllThirteen() {
  let prefill = EquipmentCatalog.prefill(for: .professional)
  #expect(prefill.count == 13)
  #expect(prefill.contains("hack_squat"))
  #expect(prefill.contains("blocks_chains_bands"))
}

@Test func labelsResolveForEveryToken() {
  for item in EquipmentCatalog.items {
    #expect(EquipmentCatalog.label(for: item.token) == item.label)
  }
  #expect(EquipmentCatalog.label(for: "unknown_token") == "unknown_token")
}
