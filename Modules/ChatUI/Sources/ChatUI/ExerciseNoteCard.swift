import CoreModels
import DesignSystem
import SwiftUI

@Observable
@MainActor
public final class ExerciseNoteNavigation {
  public var reference: ExerciseRefV1?
  public var studentID: UUID?
  public init() {}
}

public struct ExerciseNoteCard: View {
  public let message: ChatMessage
  @Environment(ExerciseNoteNavigation.self) private var navigation: ExerciseNoteNavigation?
  @Environment(\.dismiss) private var dismiss

  public init(message: ChatMessage) { self.message = message }

  public var body: some View {
    if let reference = message.exerciseRef, reference.version == 1 {
      Button {
        navigation?.studentID = message.senderID
        navigation?.reference = reference
        dismiss()
      } label: {
        VStack(alignment: .leading, spacing: MeetPRSpacing.space2) {
          HStack {
            Text("\(reference.shortDate) · \(reference.exerciseName) · \(ChatStrings.studentNote)")
              .font(.MeetPR.body(size: MeetPRFontMetrics.size14, weight: .semibold))
            Image(systemName: "chevron.right")
          }
          .foregroundStyle(Color.MeetPR.goldText)
          Text(
            message.text?.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
              .dropFirst().first.map(String.init) ?? message.text ?? ""
          )
          .font(.MeetPR.body(size: MeetPRFontMetrics.size14))
          .foregroundStyle(Color.MeetPR.textPrimary)
          .multilineTextAlignment(.leading)
        }
        .padding(MeetPRSpacing.space3)
        .background(Color.MeetPR.surfaceCard, in: .rect(cornerRadius: MeetPRRadius.card))
      }
      .buttonStyle(.plain)
      .accessibilityIdentifier("chat.exerciseNote")
    }
  }
}
