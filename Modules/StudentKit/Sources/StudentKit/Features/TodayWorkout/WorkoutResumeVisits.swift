import Foundation

/// One last-opened civil day per student, cycle and training day. Presenting the
/// question leaves that original date intact until the student chooses an action.
struct WorkoutResumeVisits {
  var defaults = UserDefaults.standard
  var calendar = WorkoutDatePolicy.deviceCalendar

  func open(student: UUID, plan: UUID, day: UUID, today: Date, prompt: Bool) -> Date? {
    let key = key(student, plan, day)
    if prompt, let parts = defaults.array(forKey: key) as? [Int], parts.count == 3,
      let previous = calendar.date(
        from: DateComponents(year: parts[0], month: parts[1], day: parts[2])),
      previous < calendar.startOfDay(for: today)
    {
      return previous
    }
    continueDay(student: student, plan: plan, day: day, today: today)
    return nil
  }

  func continueDay(student: UUID, plan: UUID, day: UUID, today: Date) {
    let key = key(student, plan, day)
    let parts = calendar.dateComponents([.year, .month, .day], from: today)
    guard let year = parts.year, let month = parts.month, let date = parts.day else { return }
    if defaults.array(forKey: key) as? [Int] != [year, month, date] {
      defaults.set([year, month, date], forKey: key)
    }
  }

  private func key(_ student: UUID, _ plan: UUID, _ day: UUID) -> String {
    "student.workoutVisit.\(student).\(plan).\(day)"
  }
}
