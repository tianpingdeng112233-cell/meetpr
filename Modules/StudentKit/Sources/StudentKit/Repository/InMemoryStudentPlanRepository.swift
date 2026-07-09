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

  public func shiftDay(id: UUID, to date: Date, studentID: UUID) async throws {
    try await updateDay(id: id, studentID: studentID, shiftedToDate: date)
  }

  public func cancelShift(dayID: UUID, studentID: UUID) async throws {
    try await updateDay(id: dayID, studentID: studentID, shiftedToDate: nil)
  }

  private func updateDay(
    id: UUID,
    studentID: UUID,
    shiftedToDate: Date?
  ) async throws {
    guard let plan = await store.getPublishedProjection(forStudent: studentID) else {
      throw PlanDayShiftError.planNotActive
    }
    let days = plan.days.map { day in
      guard day.id == id else { return day }
      return StudentPlanDay(
        id: day.id,
        date: day.scheduledDate,
        shiftedToDate: shiftedToDate,
        exercises: day.exercises
      )
    }
    let updated = StudentPlanView(
      cycleID: plan.cycleID,
      weekIndex: plan.weekIndex,
      startDate: plan.startDate,
      planKind: plan.planKind,
      days: days
    )
    await store.savePublishedProjection(updated, forStudent: studentID)
  }
}
