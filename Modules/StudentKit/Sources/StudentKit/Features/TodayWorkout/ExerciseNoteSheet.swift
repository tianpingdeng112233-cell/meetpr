import CoreModels
import DesignSystem
import SwiftUI

struct ExerciseNoteSheet: View {
  let reference: ExerciseRefV1
  let send: (String) async -> Bool
  @Environment(\.dismiss) private var dismiss
  @State private var note = ""
  @State private var sending = false
  @State private var failed = false

  var body: some View {
    NavigationStack {
      VStack(alignment: .leading, spacing: MeetPRSpacing.space4) {
        TextField(StudentStrings.localized(.allDayNotePlaceholder), text: $note, axis: .vertical)
          .lineLimit(5...10)
          .padding(MeetPRSpacing.space3)
          .background(Color.MeetPR.surfaceCard, in: .rect(cornerRadius: MeetPRRadius.card))
        if failed {
          Text(StudentStrings.trainingShareConversationFailed)
            .foregroundStyle(Color.MeetPR.danger)
        }
        Spacer()
      }
      .padding(MeetPRSpacing.space4)
      .background(Color.MeetPR.bgBase)
      .navigationTitle(StudentStrings.localized(.allDayAskCoach) + " · " + reference.exerciseName)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(StudentStrings.localized(.addedCancel)) { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(StudentStrings.localized(.allDaySend)) {
            sending = true
            Task {
              if await send(note) { dismiss() } else { failed = true }
              sending = false
            }
          }
          .disabled(
            sending || note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
              || reference.body(note: note, english: true).utf16.count > 2000)
        }
      }
    }
    .presentationDetents([.medium])
  }
}
