import DesignSystem
import SwiftUI

struct TrainingWeekCalendarRow: View {
  let cells: [TrainingSequenceCalendarCell]
  let today: Date
  let onSelect: (UUID) -> Void
  let onSwipe: (Bool) -> Void

  var body: some View {
    if cells.count > 7 {
      TrainingWeekCalendarScroll(cells: cells, today: today, onSelect: onSelect)
    } else {
      ViewThatFits(in: .horizontal) {
        TrainingWeekCalendarCells(cells: cells, today: today, onSelect: onSelect)
          .contentShape(.rect)
          .simultaneousGesture(
            DragGesture(minimumDistance: MeetPRSpacing.point30)
              .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                onSwipe(value.translation.width < 0)
              }
          )
        TrainingWeekCalendarScroll(cells: cells, today: today, onSelect: onSelect)
      }
    }
  }
}

private struct TrainingWeekCalendarScroll: View {
  let cells: [TrainingSequenceCalendarCell]
  let today: Date
  let onSelect: (UUID) -> Void
  @State private var scrollPosition: TrainingSequenceCalendarCell.Identity?

  var body: some View {
    ScrollView(.horizontal) {
      TrainingWeekCalendarCells(cells: cells, today: today, onSelect: onSelect)
    }
    .scrollIndicators(.hidden)
    .scrollPosition(id: $scrollPosition, anchor: .center)
    .onChange(of: cells, initial: true) { _, cells in
      scrollPosition = cells.first { $0.trainingDay?.isSelected == true }?.id
    }
  }
}

private struct TrainingWeekCalendarCells: View {
  let cells: [TrainingSequenceCalendarCell]
  let today: Date
  let onSelect: (UUID) -> Void

  var body: some View {
    TrainingWeekCalendarLayout(weights: cells.map { _ in 1 }) {
      ForEach(cells) { cell in
        switch cell {
        case .training(let item):
          TrainingWeekDayCell(item: item, today: today) { onSelect(item.id) }
        case .rest(let date):
          TrainingWeekRestCell(date: date, today: today)
        }
      }
    }
    .scrollTargetLayout()
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
  let today: Date
  let onSelect: () -> Void
  @Environment(\.locale) private var locale
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    let display = TrainingWeekCellPresentation(cell: .training(item), today: today, locale: locale)
    Button(action: onSelect) {
      VStack(spacing: MeetPRSpacing.space2) {
        Text(display.weekday)
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size11))
          .tracking(1)
          .foregroundStyle(item.isSelected ? Color.MeetPR.goldText : Color.MeetPR.textSecondary)
        Text(String(Calendar.current.component(.day, from: item.day.date)))
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size15, weight: .bold))
          .foregroundStyle(colorScheme == .dark ? Color.MeetPR.bgBase : Color.MeetPR.gold900)
          .frame(width: 36, height: 36)
          .background(
            colorScheme == .dark ? Color.MeetPR.textPrimary : Color.MeetPR.gold200, in: .circle
          )
          .overlay {
            if item.isSelected {
              Circle().stroke(Color.MeetPR.gold500, lineWidth: 2).padding(-3)
            }
          }
          .overlay(alignment: .bottomTrailing) {
            if item.state == .completed {
              Image(systemName: "checkmark")
                .font(.MeetPR.system(size: MeetPRFontMetrics.size10, weight: .bold))
                .foregroundStyle(Color.MeetPR.inkOnCTAFill)
                .frame(width: 16, height: 16)
                .background(Color.MeetPR.success, in: .circle)
                .overlay { Circle().stroke(Color.MeetPR.bgBase, lineWidth: 2) }
                .offset(x: 3, y: 2)
            }
          }
      }
      .frame(minWidth: 36, minHeight: 64)
      .frame(maxWidth: .infinity)
      .contentShape(.rect)
    }
    .buttonStyle(PressScaleButtonStyle())
    .accessibilityLabel(display.accessibilityLabel)
    .accessibilityAddTraits(item.isSelected ? .isSelected : [])
    .accessibilityIdentifier("training.day.\(item.id)")
  }
}

private struct TrainingWeekRestCell: View {
  let date: Date
  let today: Date
  @Environment(\.locale) private var locale

  var body: some View {
    let display = TrainingWeekCellPresentation(cell: .rest(date), today: today, locale: locale)
    VStack(spacing: MeetPRSpacing.space2) {
      Text(display.weekday)
        .font(.MeetPR.mono(size: MeetPRFontMetrics.size11)).tracking(1)
      Text(String(Calendar.current.component(.day, from: date)))
        .font(.MeetPR.mono(size: MeetPRFontMetrics.size15))
        .frame(width: 36, height: 36)
    }
    .frame(minWidth: 36, minHeight: 64)
    .frame(maxWidth: .infinity)
    .foregroundStyle(Color.MeetPR.textMuted)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(display.accessibilityLabel)
  }
}
