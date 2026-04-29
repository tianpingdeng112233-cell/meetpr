import Testing

@testable import CoachKit

@available(iOS 17.0, macOS 14.0, *)
@Test func inMemoryRepositoryFetchesAllStudents() async throws {
  let repository = PlanningFixtures.repository()

  let students = try await repository.fetchStudents()

  #expect(students.count == 4)
  #expect(students.contains { $0.displayName == "王小明" })
}

@available(iOS 17.0, macOS 14.0, *)
@Test func inMemoryRepositoryFiltersMainLiftCatalog() async throws {
  let repository = PlanningFixtures.repository()

  let catalog = try await repository.fetchMainLiftCatalog()

  #expect(catalog.count == 7)
  #expect(!catalog.contains { $0.id == PlanningFixtures.accessoryID })
}

@available(iOS 17.0, macOS 14.0, *)
@Test func inMemoryRepositoryStoresPublishedPlans() async throws {
  let repository = PlanningFixtures.repository()

  try await repository.publishPlan(
    plan: PlanningFixtures.plan(),
    days: PlanningFixtures.planDays(),
    exercises: PlanningFixtures.planExercises()
  )

  let publishedPlans = await repository.publishedPlansSnapshot()
  #expect(publishedPlans.map(\.id) == [PlanningFixtures.planID])
}
