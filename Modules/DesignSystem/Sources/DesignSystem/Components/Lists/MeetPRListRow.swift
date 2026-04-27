import SwiftUI

@MainActor
public struct MeetPRListRow: View {
  private let title: String
  private let subtitle: String
  private let leadingSystemName: String?
  private let status: StatusBadge.Status?
  private let showsPRBadge: Bool
  private let showsTrailingChevron: Bool
  private let action: (@MainActor () -> Void)?

  @State private var feedbackTrigger = false

  public init(
    title: String,
    subtitle: String,
    leadingSystemName: String? = nil,
    status: StatusBadge.Status? = nil,
    showsPRBadge: Bool = false,
    showsTrailingChevron: Bool = true,
    action: (@MainActor () -> Void)? = nil
  ) {
    self.title = title
    self.subtitle = subtitle
    self.leadingSystemName = leadingSystemName
    self.status = status
    self.showsPRBadge = showsPRBadge
    self.showsTrailingChevron = showsTrailingChevron
    self.action = action
  }

  public var body: some View {
    Group {
      if let action {
        Button {
          feedbackTrigger.toggle()
          action()
        } label: {
          MeetPRListRowContent(
            title: title,
            subtitle: subtitle,
            leadingSystemName: leadingSystemName,
            status: status,
            showsPRBadge: showsPRBadge,
            showsTrailingChevron: showsTrailingChevron
          )
        }
        .buttonStyle(MeetPRPressOpacityButtonStyle(isDisabled: false))
      } else {
        MeetPRListRowContent(
          title: title,
          subtitle: subtitle,
          leadingSystemName: leadingSystemName,
          status: status,
          showsPRBadge: showsPRBadge,
          showsTrailingChevron: showsTrailingChevron
        )
      }
    }
    .sensoryFeedback(.impact(weight: .light), trigger: feedbackTrigger)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(title), \(subtitle)")
    .accessibilityHint(action == nil ? "List row." : "Opens details.")
  }
}

@MainActor
private struct MeetPRListRowContent: View {
  let title: String
  let subtitle: String
  let leadingSystemName: String?
  let status: StatusBadge.Status?
  let showsPRBadge: Bool
  let showsTrailingChevron: Bool

  var body: some View {
    HStack(spacing: MeetPRSpacing.md) {
      if let leadingSystemName {
        Image(systemName: leadingSystemName)
          .font(.system(size: 20, weight: .medium))
          .foregroundStyle(Color.MeetPR.fgPrimary)
          .frame(width: 24, height: 24)
      } else {
        Circle()
          .stroke(Color.MeetPR.fgPrimary, lineWidth: 1.75)
          .frame(width: 24, height: 24)
      }

      VStack(alignment: .leading, spacing: 3) {
        Text(title)
          .font(Font.MeetPR.bodyEmphasis)
          .foregroundStyle(Color.MeetPR.fgPrimary)
          .lineLimit(1)

        Text(subtitle)
          .font(Font.MeetPR.footnote)
          .foregroundStyle(Color.MeetPR.fgTertiary)
          .lineLimit(1)
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      if showsPRBadge {
        PRBadge(.newPR)
      }

      if let status {
        StatusBadge(status: status)
      }

      if showsTrailingChevron {
        Image(systemName: "chevron.right")
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(Color.MeetPR.fgTertiary)
      }
    }
    .padding(.horizontal, MeetPRSpacing.base)
    .padding(.vertical, MeetPRSpacing.md)
    .frame(minHeight: 56)
    .background(Color.MeetPR.surface1)
  }
}

#Preview("MeetPRListRow") {
  VStack(spacing: 0) {
    MeetPRListRow(
      title: "Chen Lei",
      subtitle: "W3D1 - last logged 2h ago",
      status: .ready,
      showsPRBadge: true
    ) {}
    Divider().background(Color.MeetPR.border)
    MeetPRListRow(title: "Ma Wei", subtitle: "W3D1 - queued", status: .pending) {}
    Divider().background(Color.MeetPR.border)
    MeetPRListRow(title: "Yan Bo", subtitle: "W2D3 - 5 days behind", status: .overdue) {}
  }
  .clipShape(.rect(cornerRadius: MeetPRRadius.lg))
  .overlay {
    RoundedRectangle(cornerRadius: MeetPRRadius.lg)
      .stroke(Color.MeetPR.border, lineWidth: 1)
  }
  .padding()
  .background(Color.MeetPR.bg)
  .preferredColorScheme(.dark)
}

#Preview("MeetPRListRow Light") {
  MeetPRListRow(title: "Chen Lei", subtitle: "W3D1 - last logged 2h ago", status: .ready) {}
    .padding()
    .background(Color.MeetPR.bg)
    .preferredColorScheme(.light)
}
