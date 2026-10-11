import DesignSystem
import SwiftUI

/// Shares compression across the whole single-line heading instead of truncating the status pill.
struct TrainingWeekHeaderLayout: Layout {
  var alignsTrailingItem = false
  private let spacing = MeetPRSpacing.space1

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let widths = allocatedWidths(proposal: proposal, subviews: subviews)
    let height =
      zip(subviews, widths).map {
        $0.sizeThatFits(ProposedViewSize(width: $1, height: nil)).height
      }.max() ?? 0
    let contentWidth = widths.reduce(0, +) + gaps(subviews.count)
    let width = proposal.width.flatMap { $0.isFinite ? $0 : nil } ?? contentWidth
    return CGSize(
      width: alignsTrailingItem ? max(contentWidth, width) : contentWidth, height: height)
  }

  func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
  ) {
    let widths = allocatedWidths(
      proposal: ProposedViewSize(width: bounds.width, height: nil),
      subviews: subviews)
    var x = bounds.minX
    for (index, pair) in zip(subviews, widths).enumerated() {
      let (subview, width) = pair
      if alignsTrailingItem && index == subviews.count - 1 { x = bounds.maxX - width }
      subview.place(
        at: CGPoint(x: x, y: bounds.midY), anchor: .leading,
        proposal: ProposedViewSize(width: width, height: bounds.height))
      x += width + spacing
    }
  }

  private func allocatedWidths(proposal: ProposedViewSize, subviews: Subviews) -> [CGFloat] {
    let ideal = subviews.map { $0.sizeThatFits(.unspecified).width }
    let total = ideal.reduce(0, +)
    guard total > 0 else { return ideal }
    let proposedWidth = proposal.width.flatMap { $0.isFinite ? $0 : nil }
    let available = max(0, (proposedWidth ?? total + gaps(subviews.count)) - gaps(subviews.count))
    return ideal.map { min(1, available / total) * $0 }
  }

  private func gaps(_ count: Int) -> CGFloat {
    spacing * CGFloat(max(0, count - 1))
  }
}
