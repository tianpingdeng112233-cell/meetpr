import DesignSystem
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct PendingBindReminderCard: View {
  let isRequesting: Bool
  let onRequest: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Label(StudentStrings.localized(.bindReminderTitle), systemImage: "bell")
        .font(.MeetPR.body(size: MeetPRFontMetrics.size15, weight: .bold))
        .foregroundStyle(Color.MeetPR.textPrimary)
      Text(StudentStrings.localized(.bindReminderBody))
        .font(.MeetPR.body(size: MeetPRFontMetrics.size13))
        .foregroundStyle(Color.MeetPR.textSecondary)
      Button(action: onRequest) {
        Text(StudentStrings.localized(.bindReminderEnable))
          .font(.MeetPR.body(size: MeetPRFontMetrics.size15, weight: .bold))
          .foregroundStyle(Color.MeetPR.surfaceCard)
          .frame(maxWidth: .infinity, minHeight: 44)
          .background(Color.MeetPR.textPrimary, in: .capsule)
          .contentShape(.capsule)
      }
      .disabled(isRequesting)
      .accessibilityIdentifier("bind.reminder.enable")
    }
    .padding(.vertical, 14)
    .padding(.horizontal, 16)
    .background(Color.MeetPR.gold500.opacity(0.08))
    .clipShape(.rect(cornerRadius: MeetPRRadius.card))
    .overlay {
      RoundedRectangle(cornerRadius: MeetPRRadius.card)
        .stroke(Color.MeetPR.gold500, lineWidth: 1.5)
    }
  }
}
