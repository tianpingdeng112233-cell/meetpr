import CoreModels
import Foundation
import Testing

@testable import CoachKit

@Test(arguments: [
  ("滑輪下拉", "高位下拉"), ("槓鈴窄臥推", "窄握卧推"),
  ("不碰胸暫停1秒槓鈴臥推（3cm)", "spoto 卧推"),
  ("保護槓重啟槓鈴深蹲", "架上(PIN)深蹲"), ("彈力繩臥推", "弹力带卧推"),
  ("彈力繩相撲硬舉", "弹力带辅助相扑硬拉"), ("槓鈴屈體划船", "杠铃划船"),
  ("槓鈴早安", "早安式"), ("啞鈴後腳抬高蹲", "后脚抬高分腿蹲"),
])
func traditionalTaiwanAliasesResolveAndSearch(query: String, canonical: String) throws {
  let catalog = InMemoryPlanRepository.loadBundledCatalogV2()
  let match = ExerciseMatcher.resolve(rawName: query, catalog: catalog, aliases: .bundled())
  #expect(match?.name == canonical)
  let exercise = try #require(catalog.first { $0.name == canonical })
  #expect(ExerciseSearch.matches(exercise, query: query))
}

@Test func traditionalAmbiguousNamesRemainUnbound() {
  let catalog = InMemoryPlanRepository.loadBundledCatalogV2()
  for query in ["Cable三頭伸展", "槓鈴上斜窄臥推"] {
    #expect(ExerciseMatcher.resolve(rawName: query, catalog: catalog, aliases: .bundled()) == nil)
  }
}
