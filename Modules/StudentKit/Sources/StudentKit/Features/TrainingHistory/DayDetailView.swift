import CoreModels
import DesignSystem
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
public struct DayDetailView: View {
  let day: StudentPlanDay
  let logs: [StudentSetLog]

  public init(day: StudentPlanDay, logs: [StudentSetLog]) {
    self.day = day
    self.logs = logs
  }

  static func setLabel(forZeroBasedIndex setIndex: Int) -> String {
    "第 \(SetIndexDisplay.number(forZeroBasedIndex: setIndex)) 组"
  }

  public var body: some View {
    Group {
      if day.exercises.isEmpty {
        ContentUnavailableView("休息日", systemImage: "bed.double")
      } else {
        ScrollView {
          VStack(alignment: .leading, spacing: 14) {
            ForEach(day.exercises) { exercise in
              exerciseCard(exercise)
            }
          }
          .padding()
        }
        .scrollContentBackground(.hidden)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.MeetPR.bg)
    .navigationTitle(StudentFormatting.dayMonthFormatter.string(from: day.date))
  }

  private func exerciseCard(_ exercise: StudentPlanExercise) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(exercise.exercise.name)
        .font(.headline)
        .foregroundStyle(Color.MeetPR.fgPrimary)

      if let note = CoachNoteDisplay.text(exercise.notes) {
        CoachNotePill(note: note, background: Color.MeetPR.surface2)
      }

      ForEach(exercise.prescribedSets) { set in
        let log = logs.first {
          $0.planExerciseID == exercise.id && $0.setIndex == set.setIndex
        }
        HStack {
          VStack(alignment: .leading, spacing: 2) {
            Text(Self.setLabel(forZeroBasedIndex: set.setIndex))
              .font(.subheadline)
              .foregroundStyle(Color.MeetPR.fgSecondary)
            if let coachNote = CoachNoteDisplay.text(set.coachNote) {
              Text("备注 \(coachNote)")
                .font(.caption)
                .foregroundStyle(Color.MeetPR.fgSecondary)
                .lineLimit(2)
            }
          }
          Spacer()
          if let log {
            Text(StudentFormatting.result(weightKg: log.weightKg, reps: log.reps, rpe: log.rpe))
              .font(.subheadline.monospacedDigit())
              .foregroundStyle(log.completed ? Color.MeetPR.green : Color.MeetPR.fgPrimary)
          } else {
            Text(StudentFormatting.prescribed(set))
              .font(.subheadline.monospacedDigit())
              .foregroundStyle(Color.MeetPR.fgTertiary)
          }
        }
      }
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.MeetPR.surface1)
    .overlay {
      RoundedRectangle(cornerRadius: 12)
        .stroke(Color.MeetPR.border, lineWidth: 1)
    }
    .clipShape(.rect(cornerRadius: 12))
  }
}
