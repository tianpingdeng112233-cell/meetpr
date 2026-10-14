import CoreModels
import DesignSystem
import Networking
import SwiftUI

@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct CoachDayDetailView: View {
  let day: StudentExecutionDay

  var body: some View {
    let presentation = CoachDayDetailPresentation(day: day)
    ScrollView {
      VStack(alignment: .leading, spacing: MeetPRSpacing.base) {
        if let code = day.dayCode {
          let status = day.hasTrained ? CoachDetailStrings.completed : CoachDetailStrings.notStarted
          Text("\(code) · \(status)")
            .font(Font.MeetPR.footnote)
            .foregroundStyle(Color.MeetPR.fgSecondary)
        }
        ForEach(presentation.planned) { group in
          CoachPlannedExerciseCard(group: group)
        }
        ForEach(presentation.added) { group in
          CoachAddedExerciseCard(group: group)
        }
        if presentation.planned.isEmpty && presentation.added.isEmpty {
          if day.allLogs.isEmpty {
            ContentUnavailableView(
              CoachStudentDetailStrings.text("coach.execution.restDay"), systemImage: "moon"
            )
            .frame(maxWidth: .infinity)
          } else {
            Card(accessibilityLabel: CoachStudentDetailStrings.text("coach.execution.freeLog")) {
              VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
                Text(CoachStudentDetailStrings.text("coach.execution.freeLog"))
                  .font(Font.MeetPR.headline)
                  .foregroundStyle(Color.MeetPR.fgPrimary)
                CoachReadOnlySets(logs: day.allLogs)
              }
            }
          }
        }
      }
      .padding(MeetPRSpacing.base)
    }
    .navigationTitle(CoachStudentFormatting.fullDateText(day.date))
    .background(Color.MeetPR.bg)
  }
}

@MainActor
private struct CoachPlannedExerciseCard: View {
  let group: CoachDayDetailPresentation.Planned

  var body: some View {
    let name = CoachLocalization.exerciseName(group.exercise.exercise)
    let recorded = group.prescribed.count
    let total = group.exercise.prescribedSets.count
    Card(accessibilityLabel: name) {
      VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
        Text(name)
          .font(Font.MeetPR.headline)
          .foregroundStyle(Color.MeetPR.fgPrimary)
        Text(
          CoachLocalization.localized(
            "coach.execution.loggedSetsFraction \(recorded) \(total)"
          )
        )
        .font(Font.MeetPR.footnote)
        .foregroundStyle(Color.MeetPR.fgSecondary)
        CoachReadOnlySets(logs: group.prescribed)
        if !group.extra.isEmpty {
          Text(CoachLocalization.localized("coach.execution.addedByStudent"))
            .font(Font.MeetPR.footnote)
            .foregroundStyle(Color.MeetPR.fgSecondary)
          CoachReadOnlySets(logs: group.extra)
        }
        if group.prescribed.isEmpty && group.extra.isEmpty {
          Text(CoachStudentDetailStrings.text("coach.execution.noLoggedSets"))
            .font(Font.MeetPR.body)
            .foregroundStyle(Color.MeetPR.fgSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, MeetPRSpacing.sm)
        }
      }
    }
  }
}

@MainActor
private struct CoachAddedExerciseCard: View {
  let group: CoachDayDetailPresentation.Added

  var body: some View {
    let name =
      group.exercise.map { CoachLocalization.exerciseName($0) }
      ?? CoachLocalization.localized("coach.planning.common.unknownExercise")
    Card(accessibilityLabel: name) {
      VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
        Text(name)
          .font(Font.MeetPR.headline)
          .foregroundStyle(Color.MeetPR.fgPrimary)
        Text(CoachLocalization.localized("coach.execution.studentAddedSets \(group.logs.count)"))
          .font(Font.MeetPR.footnote)
          .foregroundStyle(Color.MeetPR.fgSecondary)
        CoachReadOnlySets(logs: group.logs)
      }
    }
  }

}

@MainActor
private struct CoachReadOnlySets: View {
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  let logs: [CoachSetLogDTO]

  var body: some View {
    ForEach(logs) { log in
      CoachSetReadOnlyRow(log: log, isAccessibilitySize: dynamicTypeSize.isAccessibilitySize)
    }
  }
}
