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

  public var body: some View {
    Group {
      if day.exercises.isEmpty {
        ContentUnavailableView("休息日", systemImage: "bed.double")
      } else {
        ScrollView {
          VStack(alignment: .leading, spacing: MeetPRSpacing.point14) {
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
    .background(Color.MeetPR.bgBase)
    .navigationTitle(StudentFormatting.dayMonthFormatter.string(from: day.date))
  }

  private func exerciseCard(_ exercise: StudentPlanExercise) -> some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.point10) {
      Text(exercise.exercise.name)
        .font(.headline)
        .foregroundStyle(Color.MeetPR.textPrimary)

      if let note = CoachNoteDisplay.text(exercise.notes) {
        CoachNotePill(note: note, background: Color.MeetPR.surfaceElevated)
      }

      ForEach(exercise.prescribedSets) { set in
        let log = logs.first {
          $0.planExerciseID == exercise.id && $0.setIndex == set.setIndex
        }
        HStack {
          VStack(alignment: .leading, spacing: MeetPRSpacing.point2) {
            Text("第 \(set.setIndex + 1) 组")
              .font(.subheadline)
              .foregroundStyle(Color.MeetPR.textSecondary)
            if let coachNote = CoachNoteDisplay.text(set.coachNote) {
              Text("备注 \(coachNote)")
                .font(.caption)
                .foregroundStyle(Color.MeetPR.textSecondary)
                .lineLimit(2)
            }
          }
          Spacer()
          if let log {
            Text(StudentFormatting.result(weightKg: log.weightKg, reps: log.reps, rpe: log.rpe))
              .font(.subheadline.monospacedDigit())
              .foregroundStyle(log.completed ? Color.MeetPR.success : Color.MeetPR.textPrimary)
          } else {
            Text(StudentFormatting.prescribed(set))
              .font(.subheadline.monospacedDigit())
              .foregroundStyle(Color.MeetPR.textTertiary)
          }
        }
      }
    }
    .padding(MeetPRSpacing.point14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.MeetPR.surfaceCard)
    .overlay {
      RoundedRectangle(cornerRadius: MeetPRRadius.control)
        .stroke(Color.MeetPR.borderDefault, lineWidth: 1)
    }
    .clipShape(.rect(cornerRadius: MeetPRRadius.control))
  }
}
