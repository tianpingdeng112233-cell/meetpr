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
@Test func previewCatalogTotalCountIsTwelveThirtyFour() async throws {
  let catalog = try await previewCatalog()

  // The bundled export contains 1230 rows, plus four synthetic competition
  // lifts required by the planning catalog.
  #expect(catalog.count == 1234)
  #expect(InMemoryPlanRepository.loadBundledCatalogV2().count == 1230)
  #expect(InMemoryPlanRepository.syntheticCompetitionLifts().count == 4)
}

@available(iOS 17.0, macOS 14.0, *)
@Test func previewCatalogHasNoDuplicateIDs() async throws {
  let catalog = try await previewCatalog()

  #expect(Set(catalog.map(\.id)).count == catalog.count)
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

  #expect(decoded.count == 1230)
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
