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
          .font(.title3.bold())
          .foregroundStyle(Color.MeetPR.fgPrimary)
        if let action {
          Spacer()
          Button(action.label, action: action.handler)
            .font(.subheadline)
            .foregroundStyle(Color.MeetPR.brandRed)
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
      .background(Color.MeetPR.surface1)
      .overlay {
        RoundedRectangle(cornerRadius: 12)
          .stroke(Color.MeetPR.border, lineWidth: 1)
      }
      .clipShape(.rect(cornerRadius: 12))
  }
}
