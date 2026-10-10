import DesignSystem
import SwiftUI

struct StudentSelectionBlock: View {
  let title: String
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Text(title)
        .font(.MeetPR.body(size: MeetPRFontMetrics.size13, weight: .semibold))
        .multilineTextAlignment(.center)
        .foregroundStyle(isSelected ? Color.MeetPR.bgBase : Color.MeetPR.textPrimary)
        .frame(maxWidth: .infinity, minHeight: MeetPRSpacing.minimumHitTarget)
        .padding(.horizontal, MeetPRSpacing.xs)
        .background(
          isSelected ? Color.MeetPR.textPrimary : Color.MeetPR.surfaceCard,
          in: .rect(cornerRadius: MeetPRRadius.control)
        )
        .overlay {
          RoundedRectangle(cornerRadius: MeetPRRadius.control)
            .stroke(Color.MeetPR.borderDefault, lineWidth: 1)
        }
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }
}
