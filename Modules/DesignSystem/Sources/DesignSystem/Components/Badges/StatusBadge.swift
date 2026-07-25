import SwiftUI

@MainActor
public struct StatusBadge: View {
  public enum Tone: Sendable {
    case success
    case neutral
    case danger
    case gold

    var foreground: Color {
      switch self {
      case .success: Color.MeetPR.success
      case .neutral: Color.MeetPR.textTertiary
      case .danger: Color.MeetPR.danger
      case .gold: Color.MeetPR.gold500
      }
    }

    var background: Color {
      switch self {
      case .success: Color.MeetPR.successSoft
      case .neutral: Color.MeetPR.surfaceElevated
      case .danger: Color.MeetPR.dangerSoft
      case .gold: Color.MeetPR.goldSoft
      }
    }

    var border: Color {
      foreground.opacity(0.32)
    }
  }

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

    var tone: Tone {
      switch self {
      case .ready, .completed: .success
      case .pending: .neutral
      case .overdue: .danger
      case .live: .gold
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
  private let tone: Tone

  public init(status: Status, title: String? = nil) {
    self.status = status
    self.title = title ?? status.title
    self.tone = status.tone
  }

  public init(_ title: String, tone: Tone) {
    self.status = .pending
    self.title = title
    self.tone = tone
  }

  public var body: some View {
    HStack(spacing: MeetPRSpacing.point6) {
      if let iconName = status.iconName {
        Image(systemName: iconName)
          .font(.MeetPR.system(size: MeetPRFontMetrics.size11, weight: .semibold))
      }

      Text(title.uppercased())
        .font(.MeetPR.mono(size: 11, weight: .bold))
        .tracking(0.72)
    }
    .foregroundStyle(tone.foreground)
    .padding(.horizontal, MeetPRSpacing.sm)
    .padding(.vertical, MeetPRSpacing.xs)
    .background(tone.background)
    .overlay {
      Capsule()
        .stroke(tone.border, lineWidth: 1)
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
  .background(Color.MeetPR.bgBase)
  .preferredColorScheme(.dark)
}

#Preview("StatusBadge Light") {
  StatusBadge(status: .ready)
    .padding()
    .background(Color.MeetPR.bgBase)
    .preferredColorScheme(.light)
}
