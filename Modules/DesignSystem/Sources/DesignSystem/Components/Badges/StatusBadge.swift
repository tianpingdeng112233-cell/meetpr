import SwiftUI

/// The four-tone capsule defined by `Badge.dc.html`.
///
/// `StatusBadge` remains the public name used throughout the app. The W0
/// `init(_:tone:)` and `init(status:title:)` entries stay quarantined on their
/// frozen rendering; v3 callers must use `init(_:tone:dot:)`.
@MainActor
public struct StatusBadge: View {
  public enum Tone: Sendable {
    case gold
    case success
    case danger
    case neutral

    fileprivate var foreground: Color {
      switch self {
      case .gold: Color.MeetPR.gold500
      case .success: Color.MeetPR.success
      case .danger: Color.MeetPR.danger
      case .neutral: Color.MeetPR.textMuted
      }
    }

    fileprivate var background: Color {
      switch self {
      case .gold: Color.MeetPR.goldRGB.opacity(0.14)
      case .success: Color.MeetPR.successRGB.opacity(0.14)
      case .danger: Color.MeetPR.dangerRGB.opacity(0.14)
      case .neutral: Color.MeetPR.surfaceKey
      }
    }
  }

  /// Frozen W0 vocabulary for existing coach screens. It keeps the W0
  /// rendering path until the coach migration wave.
  public enum Status: Sendable {
    case ready
    case pending
    case overdue
    case completed
    case live

    fileprivate var text: String {
      switch self {
      case .ready: "READY"
      case .pending: "PENDING"
      case .overdue: "OVERDUE"
      case .completed: "COMPLETED"
      case .live: "TRAINING"
      }
    }

    fileprivate var tone: Tone {
      switch self {
      case .ready, .completed: .success
      case .pending: .neutral
      case .overdue: .danger
      case .live: .gold
      }
    }

    fileprivate var iconName: String? {
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

  let text: String
  let tone: Tone
  let showsDot: Bool
  let usesLegacyRendering: Bool
  private let legacyStatus: Status?

  public init(_ text: String, tone: Tone) {
    self.text = text
    self.tone = tone
    self.showsDot = false
    self.usesLegacyRendering = true
    self.legacyStatus = nil
  }

  public init(_ text: String, tone: Tone, dot: Bool) {
    self.text = text
    self.tone = tone
    self.showsDot = dot
    self.usesLegacyRendering = false
    self.legacyStatus = nil
  }

  public init(status: Status, title: String? = nil) {
    self.text = title ?? status.text
    self.tone = status.tone
    self.showsDot = false
    self.usesLegacyRendering = true
    self.legacyStatus = status
  }

  public var body: some View {
    Group {
      if usesLegacyRendering {
        LegacyStatusBadge(status: legacyStatus, title: text, tone: tone)
      } else {
        badge
      }
    }
  }

  private var badge: some View {
    HStack(spacing: MeetPRSpacing.point6) {
      if showsDot {
        Circle()
          .fill(tone.foreground)
          .frame(width: MeetPRSpacing.point5, height: MeetPRSpacing.point5)
          .accessibilityHidden(true)
      }

      Text(text)
        .font(.MeetPR.mono(size: MeetPRFontMetrics.size11, weight: .semibold))
        .tracking(0.44)
        .lineLimit(1)
    }
    .foregroundStyle(tone.foreground)
    .padding(.horizontal, MeetPRSpacing.space3)
    .padding(.vertical, MeetPRSpacing.space1)
    .background(tone.background)
    .clipShape(.rect(cornerRadius: MeetPRRadius.pill))
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(text)
  }
}

/// ⛔️ FROZEN W0 view — compatibility quarantine, not a v3 component.
///
/// Both W0 public entries use this rendering. New Badge calls use
/// `StatusBadge(_:tone:dot:)`; delete this after the coach migration wave.
@MainActor
private struct LegacyStatusBadge: View {
  let status: StatusBadge.Status?
  let title: String
  let tone: StatusBadge.Tone

  var body: some View {
    HStack(spacing: LegacyStatusBadgeContract.spacing) {
      if let iconName = status?.iconName {
        Image(systemName: iconName)
          .font(.MeetPR.system(size: MeetPRFontMetrics.size11, weight: .semibold))
      }

      Text(title.uppercased())
        .font(.MeetPR.mono(size: LegacyStatusBadgeContract.fontSize, weight: .bold))
        .tracking(LegacyStatusBadgeContract.tracking)
    }
    .foregroundStyle(foreground)
    .padding(.horizontal, LegacyStatusBadgeContract.horizontalPadding)
    .padding(.vertical, LegacyStatusBadgeContract.verticalPadding)
    .background(background)
    .overlay {
      Capsule()
        .stroke(
          foreground.opacity(LegacyStatusBadgeContract.borderOpacity),
          lineWidth: LegacyStatusBadgeContract.borderWidth
        )
    }
    .clipShape(.capsule)
    .accessibilityLabel(title)
    .accessibilityHint("Shows the current status.")
  }

  private var foreground: Color {
    switch tone {
    case .success: Color.MeetPR.success
    case .neutral: Color.MeetPR.textTertiary
    case .danger: Color.MeetPR.danger
    case .gold: Color.MeetPR.gold500
    }
  }

  private var background: Color {
    switch tone {
    case .success: Color.MeetPR.successTint
    case .neutral: Color.MeetPR.surfaceElevated
    case .danger: Color.MeetPR.dangerSoft
    case .gold: Color.MeetPR.goldSoft
    }
  }
}

enum LegacyStatusBadgeContract {
  static let spacing = MeetPRSpacing.point6
  static let fontSize: CGFloat = 11
  static let tracking: CGFloat = 0.72
  static let horizontalPadding = MeetPRSpacing.sm
  static let verticalPadding = MeetPRSpacing.xs
  static let borderOpacity = 0.32
  static let borderWidth: CGFloat = 1
}

#Preview("Badge · All Tones · Dark") {
  HStack(spacing: MeetPRSpacing.space2) {
    StatusBadge(DesignSystemStrings.current, tone: .gold, dot: false)
    StatusBadge(DesignSystemStrings.coachNotified, tone: .success, dot: true)
    StatusBadge(DesignSystemStrings.threeDaysWithoutTraining, tone: .danger, dot: true)
    StatusBadge(DesignSystemStrings.restDay, tone: .neutral, dot: false)
  }
  .padding()
  .background(Color.MeetPR.surfaceCard)
  .preferredColorScheme(.dark)
}

#Preview("Badge · All Tones · Light") {
  HStack(spacing: MeetPRSpacing.space2) {
    StatusBadge(DesignSystemStrings.current, tone: .gold, dot: false)
    StatusBadge(DesignSystemStrings.coachNotified, tone: .success, dot: true)
    StatusBadge(DesignSystemStrings.threeDaysWithoutTraining, tone: .danger, dot: true)
    StatusBadge(DesignSystemStrings.restDay, tone: .neutral, dot: false)
  }
  .padding()
  .background(Color.MeetPR.surfaceCard)
  .preferredColorScheme(.light)
}
