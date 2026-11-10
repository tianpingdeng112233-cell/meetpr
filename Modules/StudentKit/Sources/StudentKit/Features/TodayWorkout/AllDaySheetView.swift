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
  @State private var previewManuallySelected = false

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
              ?? (previewManuallySelected
                ? previewExpanded == group.id : group.id == groups.first?.id),
            hidesName: group.hidesName,
            viewModel: viewModel, editable: editable,
            onExpand: {
              if let viewModel {
                viewModel.toggleAllDayExpansion(group.id)
              } else {
                let current = previewManuallySelected ? previewExpanded : groups.first?.id
                previewExpanded = current == group.id ? nil : group.id
                previewManuallySelected = true
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

private struct AllDayTimelineNode: View {
  let node: AllDayExercise.Node
  let last: Bool

  var body: some View {
    VStack(spacing: MeetPRSpacing.space1) {
      Circle()
        .fill(
          node == .completed
            ? Color.MeetPR.success
            : node == .pending
              ? Color.MeetPR.textDim : Color.MeetPR.gold500
        )
        .overlay {
          if node == .current {
            Circle().fill(
              LinearGradient(
                colors: [Color.MeetPR.goldGradientStart, Color.MeetPR.goldGradientEnd],
                startPoint: .top, endPoint: .bottom))
          }
          if node == .completed {
            Image(systemName: "checkmark")
              .font(.MeetPR.system(size: MeetPRFontMetrics.size12, weight: .bold))
              .foregroundStyle(Color.MeetPR.inkOnCTAFill)
          }
        }
        .frame(width: 22, height: 22)
        .background {
          if node == .current { Circle().fill(Color.MeetPR.goldRGB.opacity(0.16)).padding(-4) }
        }
      if !last {
        Rectangle()
          .fill(
            node == .completed
              ? Color.MeetPR.success
              : node == .current
                ? Color.MeetPR.gold500 : Color.MeetPR.borderStrong
          )
          .overlay {
            if node == .current {
              LinearGradient(
                colors: [Color.MeetPR.goldGradientStart, Color.MeetPR.goldGradientEnd],
                startPoint: .top, endPoint: .bottom)
            }
          }
          .frame(width: 3)
          .frame(maxHeight: .infinity)
      }
    }
    .padding(.top, MeetPRSpacing.space2)
    .frame(width: 22)
    .accessibilityHidden(true)
  }
}
