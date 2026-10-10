import DesignSystem
import SwiftUI

/// Shared navigation row for Progress and Profile. The value moves as one unit.
struct StudentMenuRow: View {
  let icon: String
  let title: String
  var value: String?
  var valueColor: Color = .MeetPR.textMuted
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: MeetPRSpacing.space3) {
        Image(systemName: icon)
          .font(.system(size: MeetPRFontMetrics.size20, weight: .medium))
          .foregroundStyle(Color.MeetPR.gold500)
          .frame(width: MeetPRSpacing.point40, height: MeetPRSpacing.point40)
          .background(Color.MeetPR.surfaceRaised, in: .rect(cornerRadius: MeetPRRadius.control))
          .accessibilityHidden(true)
        StudentMenuTextLayout {
          Text(title)
            .font(.MeetPR.body(size: MeetPRFontMetrics.size15, weight: .bold))
            .foregroundStyle(Color.MeetPR.textPrimary)
            .fixedSize()
          if let value, !value.isEmpty {
            StudentMenuValueLayout {
              let segments = value.components(separatedBy: " · ")
              ForEach(segments.indices, id: \.self) { index in
                Text(segments[index] + (index < segments.count - 1 ? " · " : ""))
                  .fixedSize()
              }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(value)
            .font(.MeetPR.mono(size: MeetPRFontMetrics.size13))
            .foregroundStyle(valueColor)
            .fixedSize(horizontal: false, vertical: true)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        Image(systemName: "chevron.right")
          .font(.system(size: MeetPRFontMetrics.size14, weight: .semibold))
          .foregroundStyle(Color.MeetPR.textDim)
          .accessibilityHidden(true)
      }
      .padding(MeetPRSpacing.space4)
      .frame(minHeight: MeetPRSpacing.minimumHitTarget + MeetPRSpacing.space6)
      .background(Color.MeetPR.surfaceCard, in: .rect(cornerRadius: MeetPRRadius.card))
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(
      [title, value].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", "))
  }
}

struct StudentMenuTextLayout: Layout {
  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
    let width = proposal.width ?? sizes.reduce(0) { $0 + $1.width }
    let fits = sizes.reduce(0) { $0 + $1.width } + MeetPRSpacing.space2 <= width
    let measured = fits ? sizes : wrappedSizes(width: width, subviews: subviews)
    let height =
      fits
      ? measured.map(\.height).max() ?? 0
      : measured.reduce(0) { $0 + $1.height } + MeetPRSpacing.point3
    return CGSize(width: width, height: height)
  }

  func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
  ) {
    let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
    let fits = sizes.reduce(0) { $0 + $1.width } + MeetPRSpacing.space2 <= bounds.width
    let measured = fits ? sizes : wrappedSizes(width: bounds.width, subviews: subviews)
    for index in subviews.indices {
      let size = measured[index]
      let x = index == 0 || !fits ? bounds.minX : bounds.maxX - size.width
      let y =
        fits
        ? bounds.midY - size.height / 2
        : bounds.minY + (index == 0 ? 0 : measured[0].height + MeetPRSpacing.point3)
      subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
    }
  }

  private func wrappedSizes(width: CGFloat, subviews: Subviews) -> [CGSize] {
    subviews.map { $0.sizeThatFits(ProposedViewSize(width: width, height: nil)) }
  }

}

/// Wrap only between complete summary segments; numbers and units stay together.
private struct StudentMenuValueLayout: Layout {
  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
    let width = min(proposal.width ?? .infinity, sizes.reduce(0) { $0 + $1.width })
    let origins = positions(sizes: sizes, width: width)
    let height = zip(origins, sizes).map { $0.y + $1.height }.max() ?? 0
    return CGSize(width: width, height: height)
  }

  func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
  ) {
    let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
    let origins = positions(sizes: sizes, width: bounds.width)
    for index in subviews.indices {
      subviews[index].place(
        at: CGPoint(x: bounds.minX + origins[index].x, y: bounds.minY + origins[index].y),
        proposal: ProposedViewSize(sizes[index]))
    }
  }

  private func positions(sizes: [CGSize], width: CGFloat) -> [CGPoint] {
    var x: CGFloat = 0
    var y: CGFloat = 0
    var lineHeight: CGFloat = 0
    return sizes.map { size in
      if x > 0 && x + size.width > width {
        x = 0
        y += lineHeight
        lineHeight = 0
      }
      let origin = CGPoint(x: x, y: y)
      x += size.width
      lineHeight = max(lineHeight, size.height)
      return origin
    }
  }
}
