import SwiftUI

/// The large-title header used at the top of tab roots (mirrors the iOS
/// `.navigationBarTitleDisplayMode(.large)` lockup the design uses):
/// optional mono eyebrow + heavy display title + optional subtitle.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
public struct LargeTitleBar: View {
  private let eyebrow: String?
  private let title: String
  private let titleSize: CGFloat
  private let subtitle: String?

  public init(
    eyebrow: String? = nil, title: String, titleSize: CGFloat = 34, subtitle: String? = nil
  ) {
    self.eyebrow = eyebrow
    self.title = title
    self.titleSize = titleSize
    self.subtitle = subtitle
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.xs) {
      if let eyebrow { Eyebrow(eyebrow) }
      Text(title)
        .font(.MeetPR.display(size: titleSize, weight: .black))
        .tracking(-0.7)
        .foregroundStyle(Color.MeetPR.textPrimary)
        .fixedSize(horizontal: false, vertical: true)
      if let subtitle {
        Text(subtitle)
          .font(Font.MeetPR.footnote)
          .foregroundStyle(Color.MeetPR.textSecondary)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, MeetPRSpacing.pageHorizontal)
    .padding(.top, MeetPRSpacing.xs)
    .padding(.bottom, MeetPRSpacing.md)
    .accessibilityElement(children: .combine)
  }
}

#Preview("LargeTitleBar") {
  VStack(spacing: MeetPRSpacing.space6) {
    LargeTitleBar(title: "今日")
    LargeTitleBar(eyebrow: "中周期 · 第 03 / 04 周", title: "SBD 力量块", subtitle: "张教练 · 顶组 + 减载")
  }
  .background(Color.MeetPR.bgBase)
  .preferredColorScheme(.dark)
}
