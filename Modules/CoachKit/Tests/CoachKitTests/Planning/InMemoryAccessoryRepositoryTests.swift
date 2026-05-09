import CoreModels
import Testing

@testable import CoachKit

@available(iOS 17.0, macOS 14.0, *)
@Test func accessoryRepositoryEmptyFilterReturnsAllAccessoriesOnly() async throws {
  let repository = InMemoryPlanRepository.preview()

  let exercises = try await repository.fetchAccessoryExercises(filters: .empty)

  #expect(exercises.count == 34)
  #expect(exercises.allSatisfy { $0.exerciseType == .accessory })
  #expect(!exercises.contains { $0.exerciseType == .mainLift })
}

@available(iOS 17.0, macOS 14.0, *)
@Test func accessoryRepositoryFiltersSingleFacetSingleValue() async throws {
  let repository = InMemoryPlanRepository.preview()
  let filters = AccessoryFilters(muscleGroups: [.quad])

  let exercises = try await repository.fetchAccessoryExercises(filters: filters)

  #expect(exercises.contains { $0.name == "哈克深蹲" })
  #expect(exercises.allSatisfy { Set($0.muscleGroups).isDisjoint(with: [.quad]) == false })
}

@available(iOS 17.0, macOS 14.0, *)
@Test func accessoryRepositoryFiltersSingleFacetMultipleValuesAsOr() async throws {
  let repository = InMemoryPlanRepository.preview()
  let filters = AccessoryFilters(muscleGroups: [.quad, .glute])

  let exercises = try await repository.fetchAccessoryExercises(filters: filters)

  #expect(exercises.contains { $0.name == "哈克深蹲" })
  #expect(exercises.contains { $0.name == "臀冲" })
  #expect(
    exercises.allSatisfy {
      !Set($0.muscleGroups).isDisjoint(with: Set([MuscleGroup.quad, .glute]))
    })
}

@available(iOS 17.0, macOS 14.0, *)
@Test func accessoryRepositoryFiltersAcrossFacetsAsAnd() async throws {
  let repository = InMemoryPlanRepository.preview()
  let filters = AccessoryFilters(
    muscleGroups: [.quad],
    equipment: [.barbell],
    movementPatterns: [.push]
  )

  let exercises = try await repository.fetchAccessoryExercises(filters: filters)

  #expect(exercises.contains { $0.name == "杠铃前蹲举" })
  #expect(exercises.contains { $0.name == "杠铃箭步蹲" })
  #expect(
    exercises.allSatisfy { exercise in
      !Set(exercise.muscleGroups).isDisjoint(with: [.quad])
        && !Set(exercise.equipment).isDisjoint(with: [.barbell])
        && !Set(exercise.movementPattern).isDisjoint(with: [.push])
    })
}

@available(iOS 17.0, macOS 14.0, *)
@Test func accessoryRepositoryReturnsEmptyArrayForNoMatches() async throws {
  let repository = InMemoryPlanRepository.preview()
  let filters = AccessoryFilters(
    muscleGroups: [.biceps],
    equipment: [.machine],
    movementPatterns: [.push]
  )

  let exercises = try await repository.fetchAccessoryExercises(filters: filters)

  #expect(exercises.isEmpty)
}

@available(iOS 17.0, macOS 14.0, *)
@Test func previewRepositoryStudentIDsAreStableAcrossLaunches() async throws {
  let firstRepository = InMemoryPlanRepository.preview()
  let secondRepository = InMemoryPlanRepository.preview()

  let firstStudents = try await firstRepository.fetchStudents()
  let secondStudents = try await secondRepository.fetchStudents()

  #expect(firstStudents.map(\.id) == secondStudents.map(\.id))
  #expect(firstStudents.map(\.profile.id) == secondStudents.map(\.profile.id))
}
