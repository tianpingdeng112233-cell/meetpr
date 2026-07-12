import CoreModels
import Foundation
import Testing

@testable import CoachKit

@available(iOS 17.0, macOS 14.0, *)
@Test func previewCatalogContainsFourSyntheticCompetitionLifts() async throws {
  let catalog = try await previewCatalog()
  let competitionLifts = catalog.filter(\.isCompetitionLift)

  #expect(competitionLifts.count == 4)
  #expect(
    Set(competitionLifts.map(\.name)) == [
      "比赛式深蹲", "比赛式卧推", "比赛式传统硬拉", "比赛式相扑硬拉",
    ]
  )
  #expect(competitionLifts.allSatisfy { $0.exerciseType == .mainLift })
  #expect(competitionLifts.allSatisfy { $0.name.localizedStandardContains("比赛式") })
}

@available(iOS 17.0, macOS 14.0, *)
@Test func previewCatalogTotalCountIsTwelveTwentyThree() async throws {
  let catalog = try await previewCatalog()

  // spec 043 added 3 catalog exercises (离心卧推 / 弹力带窄推 / 安全杠节奏深蹲): 1224→1227.
  // The catalog fix added 2 low-bar squat variations (低杠位暂停深蹲 / 低杠位节奏深蹲): 1227→1229.
  // Duplicate-nameEn dedup merged 10 entries into their canonical spelling: 1229→1219.
  #expect(catalog.count == 1223)
  #expect(InMemoryPlanRepository.loadBundledCatalogV2().count == 1219)
  #expect(InMemoryPlanRepository.syntheticCompetitionLifts().count == 4)
  let deadlifts = InMemoryPlanRepository.syntheticCompetitionLifts().filter {
    $0.mainLiftFamily == .deadlift
  }
  #expect(Set(deadlifts.compactMap(\.competitionStance)) == [.conventional, .sumo])
}

@available(iOS 17.0, macOS 14.0, *)
@Test func previewCatalogHasNoDuplicateIDs() async throws {
  let catalog = try await previewCatalog()

  #expect(Set(catalog.map(\.id)).count == catalog.count)
}

// 规范名 is the ExerciseMatcher/alias-canonical resolution key, so a duplicate
// Chinese name would make bindings ambiguous — guard it at the data level.
@available(iOS 17.0, macOS 14.0, *)
@Test func previewCatalogHasNoDuplicateChineseNames() async throws {
  let catalog = try await previewCatalog()

  #expect(Set(catalog.map(\.name)).count == catalog.count)
}

@available(iOS 17.0, macOS 14.0, *)
@Test func previewCatalogAllExercisesHaveValidEnums() async throws {
  let imported = InMemoryPlanRepository.loadBundledCatalogV2()
  let encoder = JSONEncoder()
  encoder.dateEncodingStrategy = .iso8601
  let exerciseData = try encoder.encode(imported)
  let decoder = JSONDecoder()
  decoder.dateDecodingStrategy = .iso8601
  let decoded = try decoder.decode([Exercise].self, from: exerciseData)

  #expect(decoded.count == 1219)
  #expect(decoded.allSatisfy { !$0.muscleGroups.isEmpty })
  #expect(decoded.allSatisfy { !$0.equipment.isEmpty })
  #expect(decoded.allSatisfy { !$0.movementPattern.isEmpty })
}

@available(iOS 17.0, macOS 14.0, *)
@Test func previewCatalogCoversAllExerciseTypes() async throws {
  let catalog = try await previewCatalog()

  #expect(Set(catalog.map(\.exerciseType)) == [.mainLift, .mainLiftVariation, .accessory])
}

@available(iOS 17.0, macOS 14.0, *)
@Test func previewCatalogCoversAllLiftFamilies() async throws {
  let catalog = try await previewCatalog()
  let competitionFamilies = Set(
    catalog
      .filter { $0.exerciseType == .mainLift }
      .compactMap(\.mainLiftFamily)
  )

  #expect(competitionFamilies == [.squat, .bench, .deadlift])
}

@available(iOS 17.0, macOS 14.0, *)
private func previewCatalog() async throws -> [Exercise] {
  let repository = InMemoryPlanRepository.preview()
  let mainLifts = try await repository.fetchMainLiftCatalog()
  let accessories = try await repository.fetchAccessoryExercises(filters: .empty)
  return mainLifts + accessories
}
