import CoreModels
import DesignSystem
import SwiftUI

/// One-off geometry from the 4b mockup that has no scale-token equivalent.
/// Named so nobody reads a font metric as a height (or vice versa).
enum BindEnterCodeMetrics {
  /// `height:54` on the primary CTA.
  static let ctaHeight: CGFloat = 54
  /// `height:48` on the secondary 清空重输 button.
  static let secondaryButtonHeight: CGFloat = 48
  /// The 2×24 caret inside the active box.
  static let caretWidth: CGFloat = 2
  static let caretHeight: CGFloat = 24
  /// Unscaled box height: `aspect-ratio:1/1.18` on the ~62pt flexible column
  /// the 5-per-row grid produces at 390pt wide.
  static let cellHeight: CGFloat = 73
  /// `box-shadow: 0 0 0 3px` is a 3pt ring sitting *outside* the border, so the
  /// stroke is inset by half its width to keep it flush with the edge.
  static let focusRingWidth: CGFloat = 3

  /// CSS `line-height` targets, resolved against IBM Plex Sans' real metrics
  /// (measured with CoreText — `lineSpacing` *adds* to the font's own line
  /// height, it does not replace it).
  enum LineSpacing {
    /// 14pt × 1.55 = 21.70 target − 18.1998 natural.
    static let body14: CGFloat = 3.5
    /// 12.5pt × 1.60 = 20.00 target − 16.2498 natural.
    static let caption125Loose: CGFloat = 3.75
    /// 12.5pt × 1.55 = 19.375 target − 16.2498 natural.
    static let caption125: CGFloat = 3.125
  }
}

/// The boxed code field: `InviteCodeFormat.length` cells laid out 5-per-row
/// with a transparent `TextField` on top.
///
/// ⚠️ The mockup draws **6** boxes in a single row. This repo's codes are 10
/// characters (`InviteCodeFormat.length`), and 10 single-row boxes leave ~27pt
/// each — too narrow for the mono 26pt glyph — so the grid wraps to 2×5 and the
/// code length is untouched. See `docs/design/login-v3/CARD-bind.md` §1.
@available(iOS 17.0, macOS 14.0, *)
struct InviteCodeEntry: View {
  @Binding var code: String
  let errorMessage: String?
  let pasteError: String?
  let onPaste: () -> Void
  @FocusState private var isFocused: Bool

  private let columns = Array(
    repeating: GridItem(.flexible(), spacing: MeetPRSpacing.space2),
    count: 5
  )

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.space2) {
      LazyVGrid(columns: columns, spacing: MeetPRSpacing.space2) {
        ForEach(0..<InviteCodeFormat.length, id: \.self) { index in
          InviteCodeCell(
            character: character(at: index),
            isCurrent: isFocused && index == code.count
              && code.count < InviteCodeFormat.length,
            hasError: errorMessage != nil
          )
        }
      }
      .accessibilityHidden(true)
      // Invisible input carrying the keyboard and the single VoiceOver element
      // — the boxes themselves are pure decoration.
      //
      // Do **not** try to make this field cover the grid: the platform text
      // control keeps its own ~16pt intrinsic height no matter what SwiftUI
      // frame wraps it (measured: `342×16 @ y=69` against a 154pt grid, as a
      // ZStack sibling *and* as an overlay), so only a thin band in the middle
      // would ever hit-test. Focus for the rest of the grid comes from the
      // explicit tap path below, which does not depend on that frame at all.
      .overlay {
        TextField("", text: $code)
          .textFieldStyle(.plain)
          .foregroundStyle(.clear)
          .tint(.clear)
          .focused($isFocused)
          .accessibilityLabel("邀请码")
          .accessibilityValue(code.isEmpty ? "未输入" : code)
          .accessibilityHint("输入 \(InviteCodeFormat.length) 位邀请码,不含 I、O、0、1")
          #if os(iOS)
            .keyboardType(.asciiCapable)
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled()
          #endif
      }
      .contentShape(.rect)
      .onTapGesture { isFocused = true }

      HStack(alignment: .firstTextBaseline, spacing: MeetPRSpacing.space2) {
        // Keeps the alphabet constraint visible: `EnterCodeViewModel` rejects
        // I/O/0/1, and "字母数字" alone would imply they are allowed.
        Text("\(InviteCodeFormat.length) 位字母数字,不含 I、O、0、1")
          .font(Font.MeetPR.body(size: MeetPRFontMetrics.size12))
          .foregroundStyle(Color.MeetPR.textMuted)

        Spacer(minLength: MeetPRSpacing.space2)

        Button(action: onPaste) {
          Label("从剪贴板粘贴", systemImage: "doc.on.clipboard")
            .font(Font.MeetPR.body(size: 12.5, weight: .semibold))
            .foregroundStyle(Color.MeetPR.goldText)
        }
        .accessibilityHint("粘贴有效的 \(InviteCodeFormat.length) 位邀请码")
      }

      if let pasteError {
        Label(pasteError, systemImage: "exclamationmark.circle")
          .font(Font.MeetPR.body(size: MeetPRFontMetrics.size12))
          .foregroundStyle(Color.MeetPR.dangerMuted)
      }

      if let errorMessage {
        Label(errorMessage, systemImage: "exclamationmark.circle.fill")
          .font(Font.MeetPR.body(size: 12.5))
          .lineSpacing(BindEnterCodeMetrics.LineSpacing.caption125)
          .foregroundStyle(Color.MeetPR.dangerMuted)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private func character(at index: Int) -> Character? {
    guard index < code.count else { return nil }
    return code[code.index(code.startIndex, offsetBy: index)]
  }
}

/// A single code box: filled boxes are cards, the active box takes the gold
/// stroke plus a 3pt 10% halo, boxes not yet reached stay a flat ghost.
@available(iOS 17.0, macOS 14.0, *)
private struct InviteCodeCell: View {
  let character: Character?
  let isCurrent: Bool
  let hasError: Bool

  /// `Font.MeetPR.mono` resolves to `Font.custom(_:size:)`, which scales with
  /// Dynamic Type. The box has to scale in step or a large-text run would let
  /// the glyph push filled cells taller than their empty neighbours and leave
  /// the rows ragged, so the height is scaled off the same `.body` metric.
  @ScaledMetric(relativeTo: .body)
  private var cellHeight: CGFloat = BindEnterCodeMetrics.cellHeight

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: MeetPRRadius.control)
        .fill(backgroundColor)
        .frame(maxWidth: .infinity)

      if let character {
        Text(String(character))
          .font(Font.MeetPR.mono(size: MeetPRFontMetrics.size26, weight: .semibold))
          .foregroundStyle(Color.MeetPR.textPrimary)
          .lineLimit(1)
          .minimumScaleFactor(0.6)
      } else if isCurrent {
        RoundedRectangle(cornerRadius: MeetPRRadius.micro)
          .fill(Color.MeetPR.gold500)
          .frame(
            width: BindEnterCodeMetrics.caretWidth,
            height: BindEnterCodeMetrics.caretHeight
          )
      }
    }
    .frame(maxWidth: .infinity, minHeight: cellHeight, maxHeight: cellHeight)
    .background {
      if character != nil || isCurrent {
        Color.clear.meetPRCardSurface(.card, fill: backgroundColor)
      }
    }
    .overlay {
      RoundedRectangle(cornerRadius: MeetPRRadius.control)
        .stroke(borderColor, lineWidth: 1)
    }
    .overlay {
      if isCurrent, !hasError {
        RoundedRectangle(cornerRadius: MeetPRRadius.control)
          .inset(by: -BindEnterCodeMetrics.focusRingWidth / 2)
          .stroke(
            Color.MeetPR.gold500.opacity(0.1),
            lineWidth: BindEnterCodeMetrics.focusRingWidth
          )
      }
    }
  }

  private var backgroundColor: Color {
    character == nil && !isCurrent ? Color.MeetPR.surfaceRaised : Color.MeetPR.surfaceCard
  }

  private var borderColor: Color {
    if hasError {
      Color.MeetPR.danger
    } else if isCurrent {
      Color.MeetPR.gold500
    } else if character != nil {
      Color.MeetPR.borderDefault
    } else {
      Color.MeetPR.borderSubtle
    }
  }
}
