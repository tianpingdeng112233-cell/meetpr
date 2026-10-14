import CoreModels
import DesignSystem
import SwiftUI

struct ExtraSetControls: View {
  let exercise: TodayWorkoutPresentation.Exercise
  let viewModel: TodayWorkoutViewModel
  let editable: Bool
  let onEdit: (TodayWorkoutPresentation.Row) -> Void
  var showsRows = true
  var showsAdd = true
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @State private var removal: UUID?

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.space2) {
      if showsRows {
        ForEach(exercise.rows.filter { $0.draft.isExtra }) { row in
          let layout =
            dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: MeetPRSpacing.space2))
            : AnyLayout(HStackLayout(spacing: MeetPRSpacing.space2))
          layout {
            Text(StudentStrings.localized(.addedExtra))
              .font(.caption).padding(MeetPRSpacing.space1)
              .background(Color.MeetPR.surfaceRaised, in: .capsule)
            Text(
              [
                UnitDisplay.weightText(
                  kg: row.draft.actualWeight,
                  unit: viewModel.onboardingProfile?.unitPreference ?? .kg),
                UnitDisplay.weightUnitSuffix(viewModel.onboardingProfile?.unitPreference ?? .kg),
                "×", row.draft.actualReps.map(String.init) ?? "—",
              ].joined(separator: " ")
            )
            .font(.callout.monospacedDigit())
            if let rpe = row.draft.actualRPE {
              Text("RPE " + StudentFormatting.decimal(rpe)).font(.caption)
            }
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
            if row.draft.completed {
              Image(systemName: row.draft.failed ? "xmark" : "checkmark")
                .foregroundStyle(row.draft.failed ? Color.MeetPR.danger : Color.MeetPR.success)
            }
            if editable {
              Button(StudentStrings.localized(.todayWorkoutScreen015)) { onEdit(row) }
                .font(.caption)
              Button {
                if row.record.videoState != .none {
                  viewModel.showAddedVideoError()
                } else if row.draft.loggedSetID == nil {
                  Task { await viewModel.removeStudentRow(id: row.id) }
                } else {
                  removal = row.id
                }
              } label: {
                Image(systemName: "xmark")
              }
              .accessibilityLabel(StudentStrings.localized(.addedRemoveSet))
              .frame(
                minWidth: MeetPRSpacing.minimumHitTarget, minHeight: MeetPRSpacing.minimumHitTarget)
            }
          }
        }
      }
      if editable && showsAdd {
        Button(StudentStrings.localized(.addedAddSet), systemImage: "plus") {
          viewModel.addExtraSet(exerciseID: exercise.id)
        }
        .foregroundStyle(Color.MeetPR.goldText)
        .frame(minHeight: MeetPRSpacing.minimumHitTarget)
        .disabled(exercise.rows.count(where: { $0.draft.isExtra }) >= StudentAddedRows.limit)
        .accessibilityIdentifier("studentAdded.addSet.\(exercise.stableIndex)")
        if exercise.rows.first?.draft.isAccessory != true {
          Text(StudentStrings.localized(.addedExtraHint)).font(.caption)
            .foregroundStyle(Color.MeetPR.textMuted)
        }
      }
    }
    .confirmationDialog(
      StudentStrings.localized(.addedConfirmSet),
      isPresented: Binding(
        get: { removal != nil }, set: { if !$0 { removal = nil } }), titleVisibility: .visible
    ) {
      Button(StudentStrings.localized(.addedRemove), role: .destructive) {
        if let removal { Task { await viewModel.removeStudentRow(id: removal) } }
      }
    }
  }
}
