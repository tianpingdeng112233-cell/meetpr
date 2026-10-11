import DesignSystem
import SwiftUI

struct ProfileCoachNotificationNote: View {
  var body: some View {
    Text(StudentStrings.localized(.profileNotify))
      .font(.MeetPR.body(size: MeetPRFontMetrics.size12))
      .foregroundStyle(Color.MeetPR.textMuted)
      .multilineTextAlignment(.center)
      .frame(maxWidth: .infinity)
  }
}
