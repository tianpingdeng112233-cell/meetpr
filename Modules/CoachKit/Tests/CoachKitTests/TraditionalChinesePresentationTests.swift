import CoreModels
import Foundation
import Testing

@testable import CoachKit

@Test func traditionalCatalogNamesAndWeekdaysUseTaiwanVocabulary() throws {
  let locale = Locale(identifier: "zh-Hant-TW")
  #expect(CoachLocalization.exerciseName("比赛式传统硬拉", isCatalog: true, locale: locale) == "比賽式傳統硬舉")
  #expect(CoachLocalization.exerciseName("我自己的动作", locale: locale) == "我自己的动作")
  let date = try #require(
    Calendar(identifier: .gregorian).date(
      from: DateComponents(year: 2030, month: 8, day: 18, hour: 12)))
  #expect(CoachTodayFormatting.dateText(date, locale: locale).contains("週日"))
}

@Test func traditionalSetInputMatchesSimplifiedParsing() {
  #expect(SetLineParser.parseSetsReps("4組") == SetLineParser.parseSetsReps("4组"))
  #expect(
    SetLineParser.expand(setsCell: "4*3", intensityCell: "D100/L110 遞增5kg").map(\.weightKg)
      == SetLineParser.expand(setsCell: "4*3", intensityCell: "D100/L110 递增5kg").map(\.weightKg))
}

@Test func traditionalImportedNamesResolveToSimplifiedCanonicalNames() {
  let catalog =
    InMemoryPlanRepository.syntheticCompetitionLifts()
    + InMemoryPlanRepository.loadBundledCatalogV2()
  let aliases = ExerciseAliasTable(
    version: 1,
    aliases: [ExerciseAlias(alias: "相扑硬拉", canonical: "比赛式相扑硬拉")])
  let match = ExerciseMatcher.resolve(rawName: "相撲硬舉", catalog: catalog, aliases: aliases)
  #expect(match?.name == "比赛式相扑硬拉")
}

@Test func traditionalTempoNamesKeepOriginalNameAndParseSameCue() {
  let parsed = SetLineParser.stripTempoSuffix("節奏深蹲310")
  #expect(parsed.name == "節奏深蹲")
  #expect(parsed.tempoNote == SetLineParser.stripTempoSuffix("节奏深蹲310").tempoNote)
  #expect(SetLineParser.isTempoContext(exerciseName: "離心臥推", intensityCell: ""))
}

@Test func traditionalDemoVideoNamesUseCatalogProvenance() throws {
  let names = try CoachDemoSeed.pendingVideos().map {
    CoachLocalization.exerciseName(
      try #require($0.exerciseName), isCatalog: $0.isCatalogExercise,
      locale: Locale(identifier: "zh-Hant"))
  }
  #expect(names == ["比賽式深蹲", "暫停深蹲", "比賽式臥推", "比賽式臥推", "窄握臥推", "比賽式傳統硬舉"])
}
