import SwiftUI

/// One cell of the week calendar strip, per the handoff `DayChip` contract.
///
/// Exactly one status dot, top-right: green for a completed day, red for a
/// planned day that was missed, breathing gold for today. Rest days show no
/// dot at all — the design is explicit that a rest day is never "missed" —
/// and drop to faint text. Today-while-selected inverts to the navy fill in
/// both themes with a gold ring.
public struct MeetPRDayChip: View {
  public enum DayState: Equatable, Sendable {
    case done
    case missed
    case rest
    case today
    case future
  }

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  private let weekday: String
  private let date: Int
  private let state: DayState
  private let isSelected: Bool
  private let onSelect: () -> Void

  public init(
    weekday: String,
    date: Int,
    state: DayState,
    isSelected: Bool,
    onSelect: @escaping () -> Void
  ) {
    self.weekday = weekday
    self.date = date
    self.state = state
    self.isSelected = isSelected
    self.onSelect = onSelect
  }

  /// Navy in both themes — the one deliberate non-dynamic fill in the system,
  /// mirroring `--cta-bg`'s light value so "today" reads identically anywhere.
  private static let todaySelectedFill = Color(red: 17 / 255, green: 24 / 255, blue: 39 / 255)

  private var isInverted: Bool { state == .today && isSelected }

  private var textColor: Color {
    if isInverted { return .white }
    switch state {
    case .rest, .future: return Color.MeetPR.textFaint
    case .done, .missed, .today: return Color.MeetPR.textPrimary
    }
  }

  private var dotColor: Color? {
    switch state {
    case .done: Color.MeetPR.success
    case .missed: Color.MeetPR.danger
    case .today: Color.MeetPR.gold500
    case .rest, .future: nil
    }
  }

  public var body: some View {
    Button(action: onSelect) {
      VStack(spacing: 3) {
        Text(weekday)
          .font(.MeetPR.system(size: MeetPRFontMetrics.size10))
          .foregroundStyle(isInverted ? Color.white : Color.MeetPR.textTertiary)
        Text("\(date)")
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size14, weight: .bold))
          .foregroundStyle(textColor)
      }
      // 44pt is the §2 floor; the strip scrolls when seven don't fit.
      .frame(minWidth: 44, maxWidth: .infinity, minHeight: 44)
      .background(background)
      .clipShape(.rect(cornerRadius: MeetPRRadius.control))
      .overlay {
        if isSelected {
          RoundedRectangle(cornerRadius: MeetPRRadius.control)
            .stroke(Color.MeetPR.gold500, lineWidth: 1.5)
        }
      }
      .overlay(alignment: .topTrailing) {
        if let dotColor {
          statusDot(dotColor)
            .padding(.top, 5)
            .padding(.trailing, 6)
        }
      }
      // 44pt cell + padding keeps the touch target at the minimum.
      .contentShape(Rectangle())
      .accessibilityLabel(accessibilityText)
    }
    .buttonStyle(PressScaleButtonStyle())
  }

  @ViewBuilder
  private var background: some View {
    if isInverted {
      Self.todaySelectedFill
    } else if isSelected {
      Color.MeetPR.goldSoft
    } else {
      Color.MeetPR.surfaceCard
    }
  }

  @ViewBuilder
  private func statusDot(_ color: Color) -> some View {
    if state == .today && !reduceMotion {
      TimelineView(.animation) { context in
        let cycle = context.date.timeIntervalSinceReferenceDate
          .truncatingRemainder(dividingBy: 1.8)
        let phase = (1 - cos((cycle / 1.8) * 2 * .pi)) / 2
        Circle()
          .fill(color)
          .frame(width: 5, height: 5)
          .opacity(0.55 + 0.45 * phase)
          .scaleEffect(1 + 0.25 * phase)
      }
    } else {
      Circle().fill(color).frame(width: 5, height: 5)
    }
  }

  private var accessibilityText: String {
    let stateText =
      switch state {
      case .done: "已完成"
      case .missed: "未完成"
      case .rest: "休息日"
      case .today: "今天"
      case .future: "未开始"
      }
    return "周\(weekday) \(date)日，\(stateText)\(isSelected ? "，已选中" : "")"
  }
}
