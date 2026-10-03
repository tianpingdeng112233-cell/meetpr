import DesignSystem
import SwiftUI

struct TrainingWeekCalendarRow: View {
  let cells: [TrainingSequenceCalendarCell]
  let onSelect: (UUID) -> Void
  let onSwipe: (Bool) -> Void

  var body: some View {
    if cells.count > 7 {
      TrainingWeekCalendarScroll(cells: cells, onSelect: onSelect)
    } else {
      ViewThatFits(in: .horizontal) {
        TrainingWeekCalendarCells(cells: cells, onSelect: onSelect)
          .contentShape(.rect)
          .simultaneousGesture(
            DragGesture(minimumDistance: MeetPRSpacing.point30)
              .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                onSwipe(value.translation.width < 0)
              }
          )
        TrainingWeekCalendarScroll(cells: cells, onSelect: onSelect)
      }
    }
  }
}

private struct TrainingWeekCalendarScroll: View {
  let cells: [TrainingSequenceCalendarCell]
  let onSelect: (UUID) -> Void

  var body: some View {
    ScrollView(.horizontal) {
      TrainingWeekCalendarCells(cells: cells, onSelect: onSelect)
    }
    .scrollIndicators(.hidden)
  }
}

private struct TrainingWeekCalendarCells: View {
  let cells: [TrainingSequenceCalendarCell]
  let onSelect: (UUID) -> Void

  var body: some View {
    TrainingWeekCalendarLayout(weights: cells.map { $0.trainingDay == nil ? 0.7 : 1 }) {
      ForEach(cells) { cell in
        switch cell {
        case .training(let item):
          TrainingWeekDayCell(item: item) { onSelect(item.id) }
        case .rest(let date):
          TrainingWeekRestCell(date: date)
        }
      }
    }
  }
}

/// Measures the labels before distributing width, so long dates and Dynamic Type can scroll.
private struct TrainingWeekCalendarLayout: Layout {
  let weights: [CGFloat]
  private let spacing = MeetPRSpacing.space1

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
    let unit = zip(sizes, weights).map { $0.width / $1 }.max() ?? 0
    let minimumWidth = unit * weights.reduce(0, +) + spacing * CGFloat(max(0, sizes.count - 1))
    let proposedWidth = proposal.width.flatMap { $0.isFinite ? $0 : nil } ?? minimumWidth
    return CGSize(width: max(minimumWidth, proposedWidth), height: sizes.map(\.height).max() ?? 0)
  }

  func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
  ) {
    let totalWeight = weights.reduce(0, +)
    guard totalWeight > 0 else { return }
    let gaps = spacing * CGFloat(max(0, subviews.count - 1))
    let unit = (bounds.width - gaps) / totalWeight
    var x = bounds.minX
    for (subview, weight) in zip(subviews, weights) {
      let width = unit * weight
      subview.place(
        at: CGPoint(x: x, y: bounds.minY), anchor: .topLeading,
        proposal: ProposedViewSize(width: width, height: bounds.height))
      x += width + spacing
    }
  }
}

private struct TrainingWeekDayCell: View {
  let item: TrainingSequenceDay
  let onSelect: () -> Void
  @Environment(\.locale) private var locale

  var body: some View {
    Button(action: onSelect) {
      VStack(spacing: MeetPRSpacing.space2) {
        Text(TrainingWeekCalendarDate.weekday(item.day.date, locale: locale))
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size11))
          .foregroundStyle(Color.MeetPR.textMuted)
        Image(systemName: item.state == .completed ? "checkmark.circle.fill" : "circle")
          .font(.MeetPR.system(size: MeetPRFontMetrics.size17))
          .foregroundStyle(statusColor)
        Text("D\(item.dayNumber)")
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size14, weight: .bold))
          .foregroundStyle(Color.MeetPR.textPrimary)
        Text(TrainingWeekCalendarDate.shortDate(item.day.date))
          .font(
            .MeetPR.mono(
              size: MeetPRFontMetrics.size11,
              weight: item.state == .current ? .bold : .regular)
          )
          .foregroundStyle(item.state == .current ? Color.MeetPR.goldText : Color.MeetPR.textMuted)
      }
      .lineLimit(1)
      .fixedSize(horizontal: true, vertical: true)
      .padding(.horizontal, MeetPRSpacing.point2)
      .padding(.vertical, MeetPRSpacing.space3)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(
        item.state == .current ? Color.MeetPR.goldRGB.opacity(0.12) : Color.MeetPR.surfaceCard
      )
      .clipShape(.rect(cornerRadius: MeetPRRadius.control))
      .overlay {
        RoundedRectangle(cornerRadius: MeetPRRadius.control)
          .strokeBorder(
            item.isSelected ? Color.MeetPR.textPrimary : .clear,
            lineWidth: MeetPRSpacing.point2)
      }
      .contentShape(.rect)
    }
    .buttonStyle(PressScaleButtonStyle())
    .accessibilityAddTraits(item.isSelected ? .isSelected : [])
    .accessibilityValue(
      item.state == .current ? StudentStrings.localized(.trainingWeekCurrentDay) : ""
    )
    .accessibilityIdentifier("training.day.\(item.id)")
  }

  private var statusColor: Color {
    switch item.state {
    case .completed: Color.MeetPR.success
    case .current: Color.MeetPR.goldText
    case .upcoming: Color.MeetPR.textDim
    }
  }
}

private struct TrainingWeekRestCell: View {
  let date: Date
  @Environment(\.locale) private var locale

  var body: some View {
    VStack(spacing: MeetPRSpacing.space2) {
      Text(TrainingWeekCalendarDate.weekday(date, locale: locale))
        .font(.MeetPR.mono(size: MeetPRFontMetrics.size11))
      Spacer(minLength: 0)
      Text(StudentStrings.localized(.trainingWeekRest, locale: locale))
        .font(.MeetPR.body(size: MeetPRFontMetrics.size11))
      Spacer(minLength: 0)
      Text(TrainingWeekCalendarDate.shortDate(date))
        .font(.MeetPR.mono(size: MeetPRFontMetrics.size11))
    }
    .lineLimit(1)
    .fixedSize(horizontal: true, vertical: false)
    .padding(.vertical, MeetPRSpacing.space3)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .foregroundStyle(Color.MeetPR.textMuted)
    .background(Color.MeetPR.bgStack, in: .rect(cornerRadius: MeetPRRadius.control))
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(
      StudentStrings.replacing(
        .trainingWeekRestAccessibility,
        values: [
          TrainingWeekCalendarDate.weekday(date, locale: locale),
          TrainingWeekCalendarDate.shortDate(date),
        ], locale: locale))
  }
}

private enum TrainingWeekCalendarDate {
  static func weekday(_ date: Date, locale: Locale) -> String {
    var style = Date.FormatStyle().weekday(.abbreviated).locale(locale)
    style.calendar = PlanCalendarDayIdentity.utcCalendar
    style.timeZone = PlanCalendarDayIdentity.utcTimeZone
    return date.formatted(style)
  }

  static func shortDate(_ date: Date) -> String {
    let parts = PlanCalendarDayIdentity.utcCalendar.dateComponents([.month, .day], from: date)
    return "\(parts.month ?? 0)/\(parts.day ?? 0)"
  }
}
