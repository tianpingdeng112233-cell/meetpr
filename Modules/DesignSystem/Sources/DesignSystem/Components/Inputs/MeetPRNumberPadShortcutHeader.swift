import SwiftUI

/// Context line + optional shortcut chips above the keypad (spec 081 quick-log:
/// "同步到全部 N 组" / "下一格 →"); the caller resolves the value it hands over.
@MainActor
struct MeetPRNumberPadShortcutHeader: View {
  let contextText: String?
  let syncTitle: String?
  let nextTitle: String?
  let onSync: (@MainActor () -> Void)?
  let onNext: (@MainActor () -> Void)?

  var body: some View {
    HStack(spacing: MeetPRSpacing.space2) {
      if let contextText {
        Text(contextText)
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size12))
          .foregroundStyle(Color.MeetPR.textMuted)
          .lineLimit(1)
      }
      Spacer(minLength: MeetPRSpacing.space1)
      if let syncTitle, let onSync {
        shortcutButton(syncTitle, action: onSync)
      }
      if let nextTitle, let onNext {
        shortcutButton(nextTitle, action: onNext)
      }
    }
    .padding(.horizontal, MeetPRSpacing.space1)
    .padding(.bottom, MeetPRSpacing.space2)
  }

  private func shortcutButton(
    _ title: String,
    action: @escaping @MainActor () -> Void
  ) -> some View {
    Button(action: action) {
      Text(title)
        .font(.MeetPR.body(size: MeetPRFontMetrics.size12, weight: .semibold))
        .foregroundStyle(Color.MeetPR.goldText)
        .padding(.horizontal, MeetPRSpacing.point10)
        .frame(minHeight: MeetPRSpacing.point30)
        .background(Color.MeetPR.goldRGB.opacity(0.12), in: .capsule)
    }
    .buttonStyle(PressScaleButtonStyle())
  }
}
