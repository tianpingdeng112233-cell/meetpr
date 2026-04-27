import SwiftUI

@MainActor
public struct StatusBadge: View {
  public enum Status: Sendable {
    case ready
    case pending
    case overdue
    case completed
    case live

    var title: String {
      switch self {
      case .ready: "READY"
      case .pending: "PENDING"
      case .overdue: "OVERDUE"
      case .completed: "COMPLETED"
      case .live: "TRAINING"
      }
    }

    var foreground: Color {
      switch self {
      case .ready:
        Color.MeetPR.green
      case .pending:
        Color.MeetPR.fgTertiary
      case .overdue:
        Color.MeetPR.amber
      case .completed:
        Color.MeetPR.fgPrimary
      case .live:
        Color.MeetPR.brandRed
      }
    }

    var background: Color {
      switch self {
      case .ready:
        Color.MeetPR.greenSoft
      case .pending, .completed:
        .clear
      case .overdue:
        Color.MeetPR.amberSoft
      case .live:
        Color.MeetPR.brandRedSoft
      }
    }

    var border: Color {
      switch self {
      case .ready:
        Color.MeetPR.green.opacity(0.3)
      case .pending:
        Color.MeetPR.border
      case .overdue:
        Color.MeetPR.amber.opacity(0.3)
      case .completed:
        Color.MeetPR.fgPrimary
      case .live:
        Color.MeetPR.brandRed.opacity(0.3)
      }
    }

    var iconName: String? {
      switch self {
      case .ready:
        "checkmark.circle.fill"
      case .live:
        "record.circle"
      case .pending, .overdue, .completed:
        nil
      }
    }
  }

  private let status: Status
  private let title: String

  public init(status: Status, title: String? = nil) {
    self.status = status
    self.title = title ?? status.title
  }

  public var body: some View {
    HStack(spacing: 6) {
      if let iconName = status.iconName {
        Image(systemName: iconName)
          .font(.system(size: 11, weight: .semibold))
      }

      Text(title.uppercased())
        .font(.system(size: MeetPRFontMetrics.captionSize, weight: .semibold, design: .monospaced))
        .tracking(0.88)
    }
    .foregroundStyle(status.foreground)
    .padding(.horizontal, 10)
    .padding(.vertical, 5)
    .background(status.background)
    .overlay {
      Capsule()
        .stroke(status.border, lineWidth: 1)
    }
    .clipShape(.capsule)
    .accessibilityLabel(title)
    .accessibilityHint("Shows the current status.")
  }
}

#Preview("StatusBadge") {
  HStack(spacing: MeetPRSpacing.sm) {
    StatusBadge(status: .ready)
    StatusBadge(status: .pending)
    StatusBadge(status: .overdue)
    StatusBadge(status: .completed)
    StatusBadge(status: .live)
  }
  .padding()
  .background(Color.MeetPR.bg)
  .preferredColorScheme(.dark)
}

#Preview("StatusBadge Light") {
  StatusBadge(status: .ready)
    .padding()
    .background(Color.MeetPR.bg)
    .preferredColorScheme(.light)
}
