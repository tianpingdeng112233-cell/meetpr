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
            Text(value)
              .font(.MeetPR.mono(size: MeetPRFontMetrics.size13))
              .foregroundStyle(valueColor)
              .fixedSize()
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

private struct StudentMenuTextLayout: Layout {
  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
    let width = proposal.width ?? sizes.reduce(0) { $0 + $1.width }
    let fits = sizes.reduce(0) { $0 + $1.width } + MeetPRSpacing.space2 <= width
    let height =
      fits
      ? sizes.map(\.height).max() ?? 0
      : sizes.reduce(0) { $0 + $1.height } + MeetPRSpacing.point3
    return CGSize(width: width, height: height)
  }

  func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
  ) {
    let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
    let fits = sizes.reduce(0) { $0 + $1.width } + MeetPRSpacing.space2 <= bounds.width
    for index in subviews.indices {
      let size = sizes[index]
      let x = index == 0 || !fits ? bounds.minX : bounds.maxX - size.width
      let y =
        fits
        ? bounds.midY - size.height / 2
        : bounds.minY + (index == 0 ? 0 : sizes[0].height + MeetPRSpacing.point3)
      subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
    }
  }
}
