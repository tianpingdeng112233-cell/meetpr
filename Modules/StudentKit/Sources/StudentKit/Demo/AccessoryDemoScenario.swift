import CoreModels
import Foundation

/// Opt-in acceptance fixtures; no flags means the existing Demo remains byte-for-byte in shape.
enum AccessoryDemoScenario {
  static var enabled: Bool {
    ProcessInfo.processInfo.arguments.contains { $0.hasPrefix("--spec089-") }
  }
  static var upgrade: Bool { has("upgrade") }
  static var usesPounds: Bool { has("lb") }

  static func configure(_ plan: StudentPlanView) -> StudentPlanView {
    guard enabled, plan.days.count > 3,
      let template = plan.days[3].exercises.first(where: { $0.exercise.isAccessory })
    else { return plan }
    let days = plan.days.enumerated().map { index, day in
      guard index == 2 else { return day }
      let sets = (0..<3).map { index in
        PrescribedSet(
          id: identifier(100 + index), setIndex: index,
          weightKg: has("rpe") || has("bodyweight") ? nil : 60,
          intensity: has("bodyweight") ? .rir(2) : .rpe(8),
          loadMode: has("bodyweight") ? .rir : has("rpe") ? .rpe : .fixedWeight,
          reps: 12, restSeconds: has("coach-rest") ? 75 : nil,
          coachNote: has("bodyweight") ? "bodyweight" : index == 1 ? "3-1-1" : nil)
      }
      let accessory = StudentPlanExercise(
        id: identifier(20), exercise: template.exercise, sequenceIndex: 1,
        prescribedSets: sets, notes: day.exercises.first?.notes)
      return StudentPlanDay(
        id: day.id, weekNumber: day.weekNumber, dayOfWeek: day.dayOfWeek, sortOrder: day.sortOrder,
        date: day.date, exercises: day.exercises + [accessory])
    }
    return StudentPlanView(
      cycleID: plan.cycleID, weekIndex: plan.weekIndex, startDate: plan.startDate,
      endDate: plan.endDate, planKind: plan.planKind, publishedAt: plan.publishedAt,
      days: days)
  }

  static func logs(plan: StudentPlanView, studentID: UUID) -> [StudentSetLog] {
    guard plan.days.count > 2 else { return [] }
    return plan.days.prefix(3).enumerated().flatMap { dayIndex, day in
      day.exercises.flatMap { exercise -> [StudentSetLog] in
        let sets =
          dayIndex == 2 && exercise.exercise.isAccessory
          ? (upgrade ? Array(exercise.prescribedSets.prefix(1)) : []) : exercise.prescribedSets
        return sets.map { set in
          StudentSetLog(
            id: dayIndex == 2 && exercise.exercise.isAccessory ? identifier(200) : set.id,
            studentID: studentID, planExerciseID: exercise.id, exerciseID: exercise.exercise.id,
            setIndex: set.setIndex, loggedAt: day.date.addingTimeInterval(36_000),
            weightKg: set.weightKg ?? 55, reps: set.reps ?? 12, rpe: nil, completed: true)
        }
      }
    } + previousLogs(plan: plan, studentID: studentID)
  }

  static var videoAttachments: [VideoAttachment] {
    guard enabled, upgrade else { return [] }
    return [
      VideoAttachment(
        id: identifier(201), setLogID: identifier(200), studentID: StudentDemoSeed.studentID,
        remoteAttachmentID: identifier(202), status: .uploaded, contentType: "video/mp4",
        durationSeconds: 10, sizeBytes: 100, recordedAt: Date(), uploadedAt: Date())
    ]
  }

  private static func previousLogs(plan: StudentPlanView, studentID: UUID) -> [StudentSetLog] {
    guard let exercise = plan.days[2].exercises.last else { return [] }
    return (0..<3).map { index in
      StudentSetLog(
        id: identifier(300 + index), studentID: studentID, planExerciseID: identifier(30),
        exerciseID: exercise.exercise.id, setIndex: index,
        loggedAt: plan.days[2].date.addingTimeInterval(-604_800),
        weightKg: 55, reps: 10, rpe: 7, completed: true)
    }
  }

  private static func has(_ flag: String) -> Bool {
    ProcessInfo.processInfo.arguments.contains("--spec089-\(flag)")
  }

  private static func identifier(_ number: Int) -> UUID {
    let suffix = String(number)
    guard
      let id = UUID(
        uuidString:
          "08900000-0000-0000-0000-" + String(repeating: "0", count: 12 - suffix.count) + suffix)
    else { preconditionFailure("Invalid accessory Demo identifier") }
    return id
  }
}
