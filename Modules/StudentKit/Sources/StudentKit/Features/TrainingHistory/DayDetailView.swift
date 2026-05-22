import CoreModels
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
public struct DayDetailView: View {
  let day: StudentPlanDay
  let logs: [StudentSetLog]

  public init(day: StudentPlanDay, logs: [StudentSetLog]) {
    self.day = day
    self.logs = logs
  }

  public var body: some View {
    List {
      if day.exercises.isEmpty {
        Text("休息日")
          .foregroundStyle(.secondary)
      } else {
        ForEach(day.exercises) { exercise in
          Section(exercise.exercise.name) {
            ForEach(exercise.prescribedSets) { set in
              let log = logs.first {
                $0.planExerciseID == exercise.id && $0.setIndex == set.setIndex
              }
              HStack {
                Text("第 \(set.setIndex + 1) 组")
                Spacer()
                if let log {
                  let weight = StudentFormatting.decimal(log.weightKg)
                  let rpe = StudentFormatting.decimal(log.rpe)
                  Text("\(weight)kg x \(log.reps) · RPE \(rpe)")
                    .monospacedDigit()
                } else {
                  Text(StudentFormatting.prescribed(set))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                }
              }
            }
          }
        }
      }
    }
    .navigationTitle(StudentFormatting.dayMonthFormatter.string(from: day.date))
  }
}
