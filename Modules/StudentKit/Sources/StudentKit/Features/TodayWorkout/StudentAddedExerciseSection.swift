import CoreModels
import DesignSystem
import SwiftUI

struct StudentAddedExerciseSection: View {
  let viewModel: TodayWorkoutViewModel
  let day: StudentPlanDay
  let editable: Bool
  @State private var showsPicker = false
  @State private var removal: UUID?

  private var exerciseIDs: [UUID] {
    var ids: [UUID] = []
    for row in viewModel.currentDrafts ?? [] where row.isStudentAdded {
      if !ids.contains(row.exerciseID) { ids.append(row.exerciseID) }
    }
    return ids
  }

  var body: some View {
    VStack(spacing: MeetPRSpacing.space3) {
      ForEach(exerciseIDs, id: \.self) { id in
        let rows = (viewModel.currentDrafts ?? []).filter {
          $0.isStudentAdded && $0.exerciseID == id
        }
        VStack(alignment: .leading, spacing: MeetPRSpacing.space2) {
          HStack {
            Text(rows.first?.displayExerciseName ?? "").font(.headline)
            Text(StudentStrings.localized(.addedAdded)).font(.caption)
              .padding(MeetPRSpacing.space1).background(Color.MeetPR.surfaceRaised, in: .capsule)
            Spacer()
            if editable {
              Button(StudentStrings.localized(.addedRemove)) { removal = id }.font(.caption)
            }
          }
          StudentAddedInlineRows(drafts: rows, viewModel: viewModel, editable: editable)
          if editable {
            Button(StudentStrings.localized(.addedAddSet), systemImage: "plus") {
              viewModel.addStudentSet(exerciseID: id)
            }
            .frame(minHeight: MeetPRSpacing.minimumHitTarget)
            .disabled(rows.count >= StudentAddedRows.limit)
          }
        }
        .padding(MeetPRSpacing.space3)
        .background(Color.MeetPR.surfaceCard, in: .rect(cornerRadius: MeetPRRadius.card))
      }
      if editable {
        Button(StudentStrings.localized(.addedAddExercise), systemImage: "plus") {
          showsPicker = true
        }
        .frame(maxWidth: .infinity, minHeight: MeetPRSpacing.minimumHitTarget)
        .overlay {
          RoundedRectangle(cornerRadius: MeetPRRadius.card)
            .strokeBorder(Color.MeetPR.borderStrong, style: StrokeStyle(lineWidth: 1, dash: [4]))
        }
        .disabled(exerciseIDs.count >= StudentAddedRows.limit)
        .accessibilityIdentifier("studentAdded.addExercise")
        Text(StudentStrings.localized(.addedAddedHint)).font(.caption)
          .foregroundStyle(Color.MeetPR.textMuted).multilineTextAlignment(.center)
      }
    }
    .foregroundStyle(Color.MeetPR.textPrimary)
    .sheet(isPresented: $showsPicker) {
      StudentExercisePicker(viewModel: viewModel, day: day, addedIDs: Set(exerciseIDs))
    }
    .confirmationDialog(
      StudentStrings.localized(.addedConfirmExercise),
      isPresented: Binding(
        get: { removal != nil }, set: { if !$0 { removal = nil } }), titleVisibility: .visible
    ) {
      Button(StudentStrings.localized(.addedRemove), role: .destructive) {
        if let removal { Task { await viewModel.removeStudentExercise(exerciseID: removal) } }
      }
    }
  }
}
