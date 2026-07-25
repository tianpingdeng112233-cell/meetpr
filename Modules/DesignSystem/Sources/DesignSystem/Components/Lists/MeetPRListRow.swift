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
        .buttonStyle(PressScaleButtonStyle(isDisabled: false))
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
          .font(.MeetPR.system(size: MeetPRFontMetrics.size20, weight: .medium))
          .foregroundStyle(Color.MeetPR.gold500)
          .frame(width: 20, height: 20)
      } else {
        Circle()
          .stroke(Color.MeetPR.borderStrong, lineWidth: 1.5)
          .frame(width: 20, height: 20)
      }

      VStack(alignment: .leading, spacing: MeetPRSpacing.point3) {
        Text(title)
          .font(.MeetPR.body(size: 14, weight: .semibold))
          .foregroundStyle(Color.MeetPR.textPrimary)
          .lineLimit(1)

        Text(subtitle)
          .font(.MeetPR.body(size: 12))
          .foregroundStyle(Color.MeetPR.textTertiary)
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
          .font(.MeetPR.system(size: MeetPRFontMetrics.size14, weight: .semibold))
          .foregroundStyle(Color.MeetPR.textMuted)
      }
    }
    .padding(.horizontal, MeetPRSpacing.md)
    .padding(.vertical, MeetPRSpacing.sm)
    .frame(minHeight: 52)
    .background(Color.MeetPR.surfaceCard)
  }
}

#Preview("MeetPRListRow") {
  VStack(spacing: MeetPRSpacing.zero) {
    MeetPRListRow(
      title: "Chen Lei",
      subtitle: "W3D1 - last logged 2h ago",
      status: .ready,
      showsPRBadge: true
    ) {}
    Divider().background(Color.MeetPR.borderDefault)
    MeetPRListRow(title: "Ma Wei", subtitle: "W3D1 - queued", status: .pending) {}
    Divider().background(Color.MeetPR.borderDefault)
    MeetPRListRow(title: "Yan Bo", subtitle: "W2D3 - 5 days behind", status: .overdue) {}
  }
  .clipShape(.rect(cornerRadius: MeetPRRadius.lg))
  .overlay {
    RoundedRectangle(cornerRadius: MeetPRRadius.lg)
      .stroke(Color.MeetPR.borderDefault, lineWidth: 1)
  }
  .padding()
  .background(Color.MeetPR.bgBase)
  .preferredColorScheme(.dark)
}

#Preview("MeetPRListRow Light") {
  MeetPRListRow(title: "Chen Lei", subtitle: "W3D1 - last logged 2h ago", status: .ready) {}
    .padding()
    .background(Color.MeetPR.bgBase)
    .preferredColorScheme(.light)
}
