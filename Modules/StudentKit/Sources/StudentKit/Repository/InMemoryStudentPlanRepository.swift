import CoreModels
import Foundation
import RepositoryContracts

public actor InMemoryStudentPlanRepository: StudentPlanRepository {
  private let store: any StudentPlanStore
  private var calendar: Calendar

  public init(store: any StudentPlanStore, calendar: Calendar = .current) {
    self.store = store
    self.calendar = calendar
  }

  public func fetchCurrentPlan(studentID: UUID) async throws -> StudentPlanView? {
    await store.getPublishedProjection(forStudent: studentID)
  }

  public func fetchDay(studentID: UUID, date: Date) async throws -> StudentPlanDay? {
    guard let plan = await store.getPublishedProjection(forStudent: studentID) else {
      return nil
    }
    return plan.days.first { calendar.isDate($0.date, inSameDayAs: date) }
  }

  public func fetchCycleDays(studentID: UUID) async throws -> [StudentPlanDay] {
    guard let plan = await store.getPublishedProjection(forStudent: studentID) else {
      return []
    }
    return plan.days.sorted { $0.date < $1.date }
  }
}
