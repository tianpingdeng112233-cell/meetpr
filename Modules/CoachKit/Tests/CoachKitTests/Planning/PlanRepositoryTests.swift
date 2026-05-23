import CoreModels
import Foundation
import RepositoryContracts
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
    exercises: PlanningFixtures.planExercises(),
    sets: PlanningFixtures.planSets()
  )

  let publishedPlans = await repository.publishedPlansSnapshot()
  #expect(publishedPlans.map(\.id) == [PlanningFixtures.planID])
}

@available(iOS 17.0, macOS 14.0, *)
@Test func inMemoryRepositoryPublishWritesStudentProjectionToStore() async throws {
  let store = SpyStudentPlanStore()
  let repository = InMemoryPlanRepository(
    students: PlanningFixtures.students(),
    catalog: PlanningFixtures.catalog(),
    store: store
  )

  try await repository.publishPlan(
    plan: PlanningFixtures.plan(),
    days: PlanningFixtures.planDays(),
    exercises: PlanningFixtures.planExercises(),
    sets: PlanningFixtures.planSets()
  )

  let projection = try #require(
    await store.getPublishedProjection(forStudent: PlanningFixtures.activeStudentID)
  )
  #expect(projection.cycleID == PlanningFixtures.planID)
  #expect(projection.weekIndex == 1)
  #expect(projection.days.first?.exercises.first?.exercise.id == PlanningFixtures.squatID)
}

@available(iOS 17.0, macOS 14.0, *)
private actor SpyStudentPlanStore: StudentPlanStore {
  private var projections: [UUID: StudentPlanView] = [:]

  func savePublishedProjection(_ projection: StudentPlanView, forStudent studentID: UUID) async {
    projections[studentID] = projection
  }

  func getPublishedProjection(forStudent studentID: UUID) async -> StudentPlanView? {
    projections[studentID]
  }
}
