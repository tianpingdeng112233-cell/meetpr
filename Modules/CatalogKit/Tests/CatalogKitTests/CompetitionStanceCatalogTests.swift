import CatalogKit
import CoreModels
import Testing

@Test func bundledCatalogMarksOnlyUnpausedSquatStanceVariants() throws {
  let catalog = ExerciseCatalog.loadBundled()
  let lowBar = try #require(catalog.first { $0.name == "低杠位深蹲" })
  let highBar = try #require(catalog.first { $0.name == "高杠位深蹲" })
  let pausedLowBar = try #require(catalog.first { $0.name == "低杠位暂停深蹲" })

  #expect(lowBar.competitionStance == .lowBar)
  #expect(highBar.competitionStance == .highBar)
  #expect(pausedLowBar.competitionStance == nil)
}
