import SwiftUI

/// The 52×44 week-calendar cell defined by `DayChip.dc.html`.
///
/// A rest day is intentionally point-free: only a planned session that was
/// missed receives the red state dot.
@MainActor
public struct MeetPRDayChip: View {
  public enum SelectedAppearance: Equatable, Sendable {
    case filled
    case outlined
  }

  public enum DayState: Equatable, Sendable {
    case done
    case missed
    case rest
    case today
    case future
  }

  @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

  private let weekday: String
  private let date: Int
  private let state: DayState
  private let isSelected: Bool
  private let width: CGFloat?
  private let selectedAppearance: SelectedAppearance
  private let onSelect: @MainActor () -> Void

  public init(
    weekday: String,
    date: Int,
    state: DayState,
    isSelected: Bool,
    width: CGFloat? = 52,
    selectedAppearance: SelectedAppearance = .filled,
    onSelect: @escaping @MainActor () -> Void
  ) {
    self.weekday = weekday
    self.date = date
    self.state = state
    self.isSelected = isSelected
    self.width = width
    self.selectedAppearance = selectedAppearance
    self.onSelect = onSelect
  }

  public var body: some View {
    Button(action: onSelect) {
      VStack(spacing: MeetPRSpacing.zero) {
        Text(weekday)
          .font(.MeetPR.system(size: MeetPRFontMetrics.size10, weight: .medium))
          .foregroundStyle(weekdayColor)

        Spacer(minLength: MeetPRSpacing.zero)

        Text(date.formatted())
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size13, weight: .bold))
          .foregroundStyle(dateColor)
          .padding(.bottom, MeetPRSpacing.point5)
      }
      .padding(.top, MeetPRSpacing.point5)
      .frame(width: width, height: 44)
      .frame(maxWidth: width == nil ? .infinity : nil)
      .background(backgroundColor)
      .clipShape(.rect(cornerRadius: MeetPRRadius.control))
      .overlay {
        if isSelected {
          RoundedRectangle(cornerRadius: MeetPRRadius.control)
            .stroke(Color.MeetPR.gold500, lineWidth: 1.5)
        }
      }
      .overlay(alignment: .topTrailing) {
        if let statusColor {
          statusDot(statusColor)
            .padding(.top, MeetPRSpacing.point5)
            .padding(.trailing, MeetPRSpacing.point6)
        }
      }
      .shadow(
        color: Color.MeetPR.cardShadow.opacity(isSelected ? 0 : 1),
        radius: 9,
        y: 4
      )
      .contentShape(.rect)
    }
    .frame(minWidth: MeetPRSpacing.minimumHitTarget, minHeight: MeetPRSpacing.minimumHitTarget)
    .accessibilityLabel(accessibilityText)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }

  private var weekdayColor: Color {
    if isSelected && selectedAppearance == .filled { return Color.MeetPR.inkOnCTAFill }
    switch state {
    case .rest, .future:
      return Color.MeetPR.textFaint
    case .done, .missed, .today:
      return Color.MeetPR.textDim
    }
  }

  private var dateColor: Color {
    if isSelected && selectedAppearance == .filled { return Color.MeetPR.inkOnCTAFill }
    switch state {
    case .rest, .future:
      return Color.MeetPR.textFaint
    case .done, .missed, .today:
      return Color.MeetPR.textPrimary
    }
  }

  private var backgroundColor: Color {
    guard isSelected else { return Color.MeetPR.surfaceCard }
    return selectedAppearance == .filled
      ? Color.MeetPR.ctaFill
      : Color.MeetPR.surfaceElevated
  }

  private var statusColor: Color? {
    switch state {
    case .done:
      Color.MeetPR.success
    case .missed:
      Color.MeetPR.danger
    case .today:
      Color.MeetPR.gold500
    case .future where isSelected:
      Color.MeetPR.gold500
    case .rest, .future:
      nil
    }
  }

  @ViewBuilder
  private func statusDot(_ color: Color) -> some View {
    dot(color)
  }

  @ViewBuilder
  private func dot(_ color: Color) -> some View {
    if state == .missed && differentiateWithoutColor {
      Circle()
        .stroke(color, lineWidth: 1.5)
        .frame(width: MeetPRSpacing.point5, height: MeetPRSpacing.point5)
    } else {
      Circle()
        .fill(color)
        .frame(width: MeetPRSpacing.point5, height: MeetPRSpacing.point5)
    }
  }

  private var accessibilityText: String {
    let stateText =
      switch state {
      case .done: DesignSystemStrings.completed
      case .missed: DesignSystemStrings.plannedButIncomplete
      case .rest: DesignSystemStrings.restDay
      case .today: DesignSystemStrings.today
      case .future: DesignSystemStrings.future
      }
    return DesignSystemStrings.dayAccessibilityLabel(
      weekday: weekday,
      date: date,
      state: stateText
    )
  }
}

#Preview("DayChip · All States · Dark") {
  HStack(spacing: MeetPRSpacing.space2) {
    MeetPRDayChip(
      weekday: DesignSystemStrings.weekdayMonday, date: 20, state: .done, isSelected: false
    ) {}
    MeetPRDayChip(
      weekday: DesignSystemStrings.weekdayTuesday, date: 21, state: .missed, isSelected: false
    ) {}
    MeetPRDayChip(
      weekday: DesignSystemStrings.weekdayWednesday, date: 22, state: .rest, isSelected: false
    ) {}
    MeetPRDayChip(
      weekday: DesignSystemStrings.weekdayThursday, date: 23, state: .today, isSelected: true
    ) {}
    MeetPRDayChip(
      weekday: DesignSystemStrings.weekdayFriday, date: 24, state: .future, isSelected: false
    ) {}
  }
  .padding()
  .background(Color.MeetPR.bgInset)
  .preferredColorScheme(.dark)
}

#Preview("DayChip · All States · Light") {
  HStack(spacing: MeetPRSpacing.space2) {
    MeetPRDayChip(
      weekday: DesignSystemStrings.weekdayMonday, date: 20, state: .done, isSelected: false
    ) {}
    MeetPRDayChip(
      weekday: DesignSystemStrings.weekdayTuesday, date: 21, state: .missed, isSelected: false
    ) {}
    MeetPRDayChip(
      weekday: DesignSystemStrings.weekdayWednesday, date: 22, state: .rest, isSelected: false
    ) {}
    MeetPRDayChip(
      weekday: DesignSystemStrings.weekdayThursday, date: 23, state: .today, isSelected: true
    ) {}
    MeetPRDayChip(
      weekday: DesignSystemStrings.weekdayFriday, date: 24, state: .future, isSelected: false
    ) {}
  }
  .padding()
  .background(Color.MeetPR.bgBase)
  .preferredColorScheme(.light)
}
