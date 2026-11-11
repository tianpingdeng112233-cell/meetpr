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
    ZStack {
      Color.black.opacity(0.45).ignoresSafeArea()
      VStack(alignment: .leading, spacing: MeetPRSpacing.space4) {
        Text(StudentStrings.localized(.allDayAskCoach) + " · " + reference.exerciseName)
          .font(.headline)
          .fixedSize(horizontal: false, vertical: true)
        TextField(StudentStrings.localized(.allDayNotePlaceholder), text: $note, axis: .vertical)
          .lineLimit(3...6)
          .padding(MeetPRSpacing.space3)
          .background(Color.MeetPR.bgBase, in: .rect(cornerRadius: MeetPRRadius.card))
          .accessibilityIdentifier("allDay.note.input")
        if failed {
          Text(StudentStrings.trainingShareConversationFailed)
            .foregroundStyle(Color.MeetPR.danger)
        }
        HStack {
          Button(StudentStrings.localized(.addedCancel)) { dismiss() }
            .disabled(sending)
          Spacer()
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
        .frame(minHeight: MeetPRSpacing.minimumHitTarget)
      }
      .padding(MeetPRSpacing.space4)
      .frame(maxWidth: 360)
      .background(Color.MeetPR.surfaceCard, in: .rect(cornerRadius: MeetPRRadius.card))
      .padding(MeetPRSpacing.space4)
      .foregroundStyle(Color.MeetPR.textPrimary)
      .tint(Color.MeetPR.goldText)
      .accessibilityAddTraits(.isModal)
      .accessibilityIdentifier("allDay.note.dialog")
    }
    .interactiveDismissDisabled(sending)
  }
}

/// A transparent full-screen presentation centers the dialog and blocks the tab bar behind it.
struct ExerciseNotePresentation<Dialog: View>: ViewModifier {
  @Binding var reference: ExerciseRefV1?
  @ViewBuilder let dialog: (ExerciseRefV1) -> Dialog

  private struct Item: Identifiable {
    let reference: ExerciseRefV1
    var id: ExerciseRefV1 { reference }
  }

  private var item: Binding<Item?> {
    Binding(
      get: { reference.map { Item(reference: $0) } },
      set: { reference = $0?.reference })
  }

  func body(content: Content) -> some View {
    #if os(iOS)
      content.fullScreenCover(item: item) { item in
        dialog(item.reference).presentationBackground(.clear)
      }
    #else
      content.sheet(item: item) { item in dialog(item.reference) }
    #endif
  }
}
