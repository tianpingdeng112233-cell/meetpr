import CoreModels
import DesignSystem
import SwiftUI

struct AllDaySheetView: View {
  let presentation: TodayWorkoutPresentation
  let viewModel: TodayWorkoutViewModel?
  let editable: Bool
  let today: Date
  let onVideo: (TodayWorkoutPresentation.Row) -> Void
  let onNote: (TodayWorkoutSetRowDraft) -> Void
  @State private var showsPicker = false
  @State private var removal: UUID?
  @State private var previewExpanded: UUID?

  private var groups: [AllDayExercise] {
    viewModel?.allDaySheet
      ?? AllDayExercise.build(
        drafts: presentation.exercises.flatMap(\.rows).map(\.draft), collapsed: [])
  }

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.space4) {
      AllDaySummary(
        date: presentation.day.date, today: today, exercises: groups.count,
        sets: groups.flatMap(\.rows).count, editable: editable)
      ForEach(groups) { group in
        HStack(alignment: .top, spacing: MeetPRSpacing.space3) {
          AllDayTimelineNode(node: group.node, last: group.id == groups.last?.id)
          AllDayExerciseBlock(
            group: group,
            note: presentation.exercises.first { $0.id == group.id }?.note ?? "",
            expanded: viewModel.map { $0.expandedAllDayExerciseID == group.id }
              ?? (previewExpanded == group.id),
            hidesName: group.hidesName,
            viewModel: viewModel, editable: editable,
            onExpand: {
              if let viewModel {
                viewModel.toggleAllDayExpansion(group.id)
              } else {
                previewExpanded = previewExpanded == group.id ? nil : group.id
              }
            },
            onVideo: { draft in
              let row =
                presentation.exercises.flatMap(\.rows).first { $0.id == draft.id }
                ?? TodayWorkoutPresentation.Row(
                  id: draft.id,
                  stableIndex: viewModel?.currentDrafts?.firstIndex { $0.id == draft.id } ?? 0,
                  record: TodayWorkoutPresentation.record(
                    from: draft, index: SetDisplayNumber.number(for: draft), videoState: .none),
                  draft: draft, suggestionOutcome: nil)
              onVideo(row)
            }, onNote: onNote,
            onRemove: { removal = group.rows.first?.exerciseID })
        }
        .fixedSize(horizontal: false, vertical: true)
      }
      if editable, let viewModel {
        Button(StudentStrings.localized(.addedAddExercise), systemImage: "plus") {
          showsPicker = true
        }
        .font(.MeetPR.body(size: MeetPRFontMetrics.size14))
        .foregroundStyle(Color.MeetPR.goldText)
        .frame(maxWidth: .infinity, minHeight: MeetPRSpacing.minimumHitTarget)
        .disabled(
          groups.filter { $0.rows.first?.isStudentAdded == true }.count >= StudentAddedRows.limit
        )
        .accessibilityIdentifier("studentAdded.addExercise")
        .sheet(isPresented: $showsPicker) {
          StudentExercisePicker(
            viewModel: viewModel, day: presentation.day,
            addedIDs: Set(groups.flatMap(\.rows).filter(\.isStudentAdded).map(\.exerciseID)))
        }
      }
    }
    .confirmationDialog(
      StudentStrings.localized(.addedConfirmExercise),
      isPresented: Binding(get: { removal != nil }, set: { if !$0 { removal = nil } }),
      titleVisibility: .visible
    ) {
      Button(StudentStrings.localized(.addedRemove), role: .destructive) {
        if let removal { Task { await viewModel?.removeStudentExercise(exerciseID: removal) } }
      }
    }
  }
}

private struct AllDaySummary: View {
  let date: Date
  let today: Date
  let exercises: Int
  let sets: Int
  let editable: Bool

  var body: some View {
    HStack(alignment: .firstTextBaseline) {
      Text(
        StudentStrings.replacing(
          .allDaySummary,
          values: [
            Calendar.current.isDate(date, inSameDayAs: today)
              ? StudentStrings.localized(.allDayToday) : StudentFormatting.monthDay(date),
            String(exercises),
          ])
      )
      .font(.MeetPR.body(size: MeetPRFontMetrics.size15, weight: .semibold))
      Spacer(minLength: MeetPRSpacing.space2)
      Text(
        StudentStrings.replacing(
          editable ? .allDayEditHint : .allDaySetCount, values: [String(sets)])
      )
      .font(.MeetPR.body(size: MeetPRFontMetrics.size12))
      .foregroundStyle(Color.MeetPR.textSecondary)
    }
    .foregroundStyle(Color.MeetPR.textPrimary)
  }
}
