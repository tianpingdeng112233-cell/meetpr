import SwiftUI

/// The legend groups partition the roster, so their weights sum to the row count.
/// Use only the bar's proposal, never the surrounding scroll container's width.
struct CoachWeekLegendLayout: Layout {
  let weights: [Int]
  let spacing: CGFloat

  func sizeThatFits(
    proposal: ProposedViewSize,
    subviews: Subviews,
    cache: inout ()
  ) -> CGSize {
    let size = proposal.replacingUnspecifiedDimensions(by: .zero)
    return CGSize(
      width: size.width.isFinite ? max(0, size.width) : 0,
      height: size.height.isFinite ? max(0, size.height) : 0
    )
  }

  func placeSubviews(
    in bounds: CGRect,
    proposal: ProposedViewSize,
    subviews: Subviews,
    cache: inout ()
  ) {
    for (subview, frame) in zip(subviews, frames(in: bounds)) {
      subview.place(
        at: frame.origin,
        anchor: .topLeading,
        proposal: ProposedViewSize(frame.size)
      )
    }
  }

  func frames(in bounds: CGRect) -> [CGRect] {
    let total = weights.reduce(0, +)
    let gapCount = max(0, weights.count - 1)
    let gap = gapCount > 0 ? min(spacing, max(0, bounds.width) / CGFloat(gapCount)) : 0
    let availableWidth = max(0, bounds.width - gap * CGFloat(gapCount))
    var x = bounds.minX
    return weights.map { weight in
      let width = total > 0 ? availableWidth * CGFloat(weight) / CGFloat(total) : 0
      let frame = CGRect(x: x, y: bounds.minY, width: width, height: bounds.height)
      x += width + gap
      return frame
    }
  }
}
