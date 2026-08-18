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
    StudentStrings.replacing(
      .dayDetailView001, values: ["\(SetIndexDisplay.number(forZeroBasedIndex: setIndex))"])
  }

  public var body: some View {
    Group {
      if day.exercises.isEmpty {
        ContentUnavailableView(
          StudentStrings.localized(.dayDetailView002), systemImage: "bed.double")
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
    .background(Color.MeetPR.bgBase)
    .navigationTitle(StudentFormatting.dayMonth(day.date))
  }

  private func exerciseCard(_ exercise: StudentPlanExercise) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(StudentExerciseName.display(exercise.exercise))
        .font(.MeetPR.display(size: MeetPRFontMetrics.size20))
        .foregroundStyle(Color.MeetPR.textPrimary)

      if let note = CoachNoteDisplay.text(exercise.notes) {
        CoachNotePill(note: note, background: Color.MeetPR.surfaceElevated)
      }

      ForEach(exercise.prescribedSets) { set in
        let log = logs.first {
          $0.planExerciseID == exercise.id && $0.setIndex == set.setIndex
        }
        HStack {
          VStack(alignment: .leading, spacing: 2) {
            Text(Self.setLabel(forZeroBasedIndex: set.setIndex))
              .font(.MeetPR.mono(size: MeetPRFontMetrics.size15))
              .foregroundStyle(Color.MeetPR.textSecondary)
            if let coachNote = CoachNoteDisplay.text(set.coachNote) {
              Text(StudentStrings.replacing(.dayDetailView003, values: ["\(coachNote)"]))
                .font(.MeetPR.body(size: MeetPRFontMetrics.size11, weight: .medium))
                .foregroundStyle(Color.MeetPR.textSecondary)
                .lineLimit(2)
            }
          }
          Spacer()
          if let log {
            Text(StudentFormatting.result(weightKg: log.weightKg, reps: log.reps, rpe: log.rpe))
              .font(.MeetPR.mono(size: MeetPRFontMetrics.size15, weight: .semibold))
              .foregroundStyle(log.completed ? Color.MeetPR.success : Color.MeetPR.textPrimary)
          } else {
            Text(StudentFormatting.prescribed(set))
              .font(.MeetPR.mono(size: MeetPRFontMetrics.size15))
              .foregroundStyle(Color.MeetPR.textMuted)
          }
        }
      }
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.MeetPR.surfaceCard)
    .overlay {
      RoundedRectangle(cornerRadius: 12)
        .stroke(Color.MeetPR.borderDefault, lineWidth: 1)
    }
    .clipShape(.rect(cornerRadius: 12))
  }
}
