import CoreModels
import DesignSystem
import SwiftUI

struct StudentAddedInlineRows: View {
  let drafts: [TodayWorkoutSetRowDraft]
  let viewModel: TodayWorkoutViewModel
  let editable: Bool
  @State private var edits: [UUID: AccessoryRow] = [:]
  @State private var removal: UUID?

  var body: some View {
    VStack(spacing: MeetPRSpacing.space2) {
      AccessoryColumns {
        ForEach(
          [
            StudentStrings.localized(.accessorySet), StudentStrings.localized(.accessoryLast),
            UnitDisplay.weightUnitSuffix(viewModel.onboardingProfile?.unitPreference ?? .kg)
              .uppercased(),
            StudentStrings.localized(.setEntrySheet003), "RPE", "✓",
          ], id: \.self
        ) { title in
          Text(title).font(.caption2).foregroundStyle(Color.MeetPR.textMuted)
            .frame(maxWidth: .infinity)
        }
      }
      ForEach(drafts) { draft in
        VStack(alignment: .trailing, spacing: MeetPRSpacing.zero) {
          AccessoryLogRow(
            row: Binding(get: { row(draft) }, set: { edits[draft.id] = $0 }),
            number: draft.prescribed.setIndex + 1,
            isSaving: viewModel.accessorySavingIDs.contains(draft.id),
            isDisabled: !editable || !viewModel.accessorySavingIDs.isEmpty,
            showsValidation: false, onEdit: {},
            onSave: {
              let input = row(draft)
              Task { await viewModel.saveAccessoryRow(input) }
            })
          if editable {
            Button(StudentStrings.localized(.addedRemoveSet), systemImage: "xmark") {
              if draft.loggedSetID == nil {
                Task { await viewModel.removeStudentRow(id: draft.id) }
              } else {
                removal = draft.id
              }
            }
            .font(.caption).foregroundStyle(Color.MeetPR.textMuted)
            .frame(minHeight: MeetPRSpacing.minimumHitTarget)
          }
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

  private func row(_ draft: TodayWorkoutSetRowDraft) -> AccessoryRow {
    let unit = viewModel.onboardingProfile?.unitPreference ?? .kg
    var row = viewModel.studentAddedInput(draft: draft, unit: unit)
    if let edit = edits[draft.id], edit.draft == draft { row.input = edit.input }
    return row
  }
}
