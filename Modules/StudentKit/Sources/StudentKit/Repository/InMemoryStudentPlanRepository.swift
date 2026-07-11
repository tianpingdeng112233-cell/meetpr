import CoreModels
import Foundation
import RepositoryContracts

public actor InMemoryStudentPlanRepository: StudentPlanRepository {
  private struct ShiftBatch: Sendable {
    let previousPlan: StudentPlanView
  }

  private let store: any StudentPlanStore
  private var calendar: Calendar
  private let now: @Sendable () -> Date
  private var batchesByStudentID: [UUID: [ShiftBatch]] = [:]

  public init(
    store: any StudentPlanStore,
    calendar: Calendar? = nil,
    now: @escaping @Sendable () -> Date = { Date() }
  ) {
    self.store = store
    if let calendar {
      self.calendar = calendar
    } else {
      var utcCalendar = Calendar(identifier: .gregorian)
      utcCalendar.timeZone = TimeZone(secondsFromGMT: 0) ?? utcCalendar.timeZone
      self.calendar = utcCalendar
    }
    self.now = now
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

  public func shiftPlan(id: UUID, studentID: UUID) async throws -> PlanShiftResult {
    guard let plan = await store.getPublishedProjection(forStudent: studentID), plan.cycleID == id
    else {
      throw PlanShiftError.planNotActive
    }
    let createdAt = now()
    let today = calendar.startOfDay(for: createdAt)
    guard
      plan.days.contains(where: {
        calendar.isDate($0.date, inSameDayAs: today) && !$0.exercises.isEmpty
      })
    else {
      throw PlanShiftError.onlyToday
    }

    let batchID = UUID()
    var shiftedDays: [ShiftedPlanDay] = []
    let updatedDays = plan.days.map { day in
      guard calendar.startOfDay(for: day.date) >= today,
        let shiftedDate = calendar.date(byAdding: .day, value: 1, to: day.date)
      else { return day }
      shiftedDays.append(ShiftedPlanDay(dayID: day.id, shiftedToDate: shiftedDate))
      return StudentPlanDay(
        id: day.id,
        date: day.scheduledDate,
        shiftedToDate: shiftedDate,
        exercises: day.exercises
      )
    }
    let updated = StudentPlanView(
      cycleID: plan.cycleID,
      weekIndex: plan.weekIndex,
      startDate: plan.startDate,
      endDate: plan.endDate,
      planKind: plan.planKind,
      totalShiftDays: plan.totalShiftDays + 1,
      latestShiftCreatedAt: createdAt,
      days: updatedDays
    )
    batchesByStudentID[studentID, default: []].append(
      ShiftBatch(previousPlan: plan)
    )
    await store.savePublishedProjection(updated, forStudent: studentID)
    return PlanShiftResult(
      batchID: batchID,
      shiftedDays: shiftedDays,
      totalShiftDays: updated.totalShiftDays
    )
  }

  public func cancelPlanShift(id: UUID, studentID: UUID) async throws {
    guard let plan = await store.getPublishedProjection(forStudent: studentID), plan.cycleID == id
    else {
      throw PlanShiftError.planNotActive
    }
    guard !batchesByStudentID[studentID, default: []].isEmpty else {
      throw PlanShiftError.noActiveShift
    }
    guard Self.isSameDayUTC(plan.latestShiftCreatedAt, now()) else {
      throw PlanShiftError.undoWindowPassed
    }
    guard let batch = batchesByStudentID[studentID]?.removeLast() else {
      throw PlanShiftError.noActiveShift
    }
    await store.savePublishedProjection(batch.previousPlan, forStudent: studentID)
  }

  private static func isSameDayUTC(_ lhs: Date?, _ rhs: Date) -> Bool {
    guard let lhs else { return false }
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone
    return calendar.isDate(lhs, inSameDayAs: rhs)
  }
}
