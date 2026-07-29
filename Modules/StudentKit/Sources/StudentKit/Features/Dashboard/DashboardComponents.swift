import DesignSystem
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct DashboardSection<Content: View>: View {
  let title: String
  var action: (label: String, handler: () -> Void)?
  @ViewBuilder let content: Content

  init(
    title: String,
    action: (label: String, handler: () -> Void)? = nil,
    @ViewBuilder content: () -> Content
  ) {
    self.title = title
    self.action = action
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text(title)
          .font(.MeetPR.display(size: MeetPRFontMetrics.size20))
          .foregroundStyle(Color.MeetPR.textPrimary)
        if let action {
          Spacer()
          Button(action.label, action: action.handler)
            .font(.MeetPR.body(size: MeetPRFontMetrics.size15, weight: .semibold))
            .foregroundStyle(Color.MeetPR.goldText)
        }
      }
      content
    }
  }
}

@available(iOS 17.0, macOS 14.0, *)
struct DashboardCard: ViewModifier {
  func body(content: Content) -> some View {
    content
      .padding(14)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Color.MeetPR.surfaceCard)
      .overlay {
        RoundedRectangle(cornerRadius: 12)
          .stroke(Color.MeetPR.borderDefault, lineWidth: 1)
      }
      .clipShape(.rect(cornerRadius: 12))
  }
}
