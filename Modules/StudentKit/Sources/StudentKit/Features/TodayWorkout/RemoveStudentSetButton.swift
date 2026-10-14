import DesignSystem
import SwiftUI

struct RemoveStudentSetButton: View {
  let row: TodayWorkoutPresentation.Row
  let viewModel: TodayWorkoutViewModel
  @State private var confirmsRemoval = false

  var body: some View {
    Button {
      if row.record.videoState != .none {
        viewModel.showAddedVideoError()
      } else if row.draft.loggedSetID == nil {
        Task { await viewModel.removeStudentRow(id: row.id) }
      } else {
        confirmsRemoval = true
      }
    } label: {
      Image(systemName: "xmark")
        .frame(minWidth: MeetPRSpacing.minimumHitTarget, minHeight: MeetPRSpacing.minimumHitTarget)
    }
    .accessibilityLabel(StudentStrings.localized(.addedRemoveSet))
    .foregroundStyle(Color.MeetPR.textMuted)
    .disabled(!viewModel.accessorySavingIDs.isEmpty)
    .confirmationDialog(
      StudentStrings.localized(.addedConfirmSet), isPresented: $confirmsRemoval,
      titleVisibility: .visible
    ) {
      Button(StudentStrings.localized(.addedRemove), role: .destructive) {
        Task { await viewModel.removeStudentRow(id: row.id) }
      }
    }
  }
}
