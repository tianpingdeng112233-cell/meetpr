import DesignSystem
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct GrowthScreenHeader: View {
  let showsChat: Bool
  let unreadCount: Int
  let onOpenChat: @MainActor () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.point14) {
      HStack(alignment: .top) {
        MeetPRMark.header
          .frame(width: 97, height: 24, alignment: .leading)
        Spacer()
        if showsChat {
          HeaderChatButton(
            unreadCount: unreadCount,
            accessibilityLabel: StudentStrings.localized(.trainingHistoryView012),
            action: onOpenChat
          )
        }
      }
      Text(StudentStrings.localized(.trainingHistoryView013))
        .font(.MeetPR.display(size: MeetPRFontMetrics.size34))
        .foregroundStyle(Color.MeetPR.textPrimary)

    }
    .accessibilityElement(children: .combine)
  }
}
