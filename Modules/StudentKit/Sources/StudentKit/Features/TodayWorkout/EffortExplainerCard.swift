import DesignSystem
import SwiftUI

/// A separate presentation leaves the underlying input and effort switch untouched.
struct EffortExplainerButton: View {
  let kind: ActualEffortMode
  var isAccessoryHeader = false
  var isInlineHeader = false
  @Environment(\.colorScheme) private var colorScheme
  @State private var isPresented = false

  var body: some View {
    Button {
      isPresented = true
    } label: {
      EffortHelpIcon(isAccessoryHeader: isAccessoryHeader || isInlineHeader)
        .offset(y: isAccessoryHeader && !isInlineHeader ? -MeetPRSpacing.space2 : 0)
        .frame(
          width: isAccessoryHeader || isInlineHeader ? AccessoryEffortHeaderLayout.badgeWidth : 44,
          height: isInlineHeader ? AccessoryEffortHeaderLayout.badgeWidth : 44
        )
        .padding(.horizontal, isInlineHeader ? 5 : 0)
        .padding(.vertical, isInlineHeader ? 4 : 0)
        .contentShape(.rect)
    }
    .padding(.horizontal, isInlineHeader ? -5 : 0)
    .padding(.vertical, isInlineHeader ? -4 : 0)
    .buttonStyle(.plain)
    .accessibilityLabel(EffortExplainer.content(for: kind).helpLabel)
    .accessibilityIdentifier("effortExplainer.help.\(kind.rawValue)")
    #if os(iOS)
      .fullScreenCover(isPresented: $isPresented) {
        EffortExplainerCard(kind: kind)
        .preferredColorScheme(colorScheme)
        .presentationBackground(.clear)
      }
    #else
      .sheet(isPresented: $isPresented) {
        EffortExplainerCard(kind: kind)
        .preferredColorScheme(colorScheme)
        .presentationBackground(.clear)
      }
    #endif
  }
}

struct EffortHelpIcon: View {
  let isAccessoryHeader: Bool

  var body: some View {
    Group {
      if isAccessoryHeader {
        // A 14pt symbol font has a larger intrinsic image size. Constrain the image itself,
        // not just the surrounding hit frame, so its left edge cannot enter the toggle.
        Image(systemName: "questionmark.circle")
          .resizable()
          .scaledToFit()
          .frame(
            width: AccessoryEffortHeaderLayout.badgeWidth,
            height: AccessoryEffortHeaderLayout.badgeWidth)
      } else {
        Image(systemName: "questionmark.circle")
          .font(.system(size: 18, weight: .regular))
      }
    }
    .foregroundStyle(Color.MeetPR.textMuted)
  }
}

private struct EffortExplainerCard: View {
  let kind: ActualEffortMode
  @Environment(\.dismiss) private var dismiss
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    ZStack {
      Button {
        dismiss()
      } label: {
        Color.black.opacity(colorScheme == .dark ? 0.60 : 0.45)
          .ignoresSafeArea()
      }
      .buttonStyle(.plain)
      .accessibilityHidden(true)

      ViewThatFits(in: .vertical) {
        EffortExplainerCardBody(kind: kind, onClose: { dismiss() })
          .fixedSize(horizontal: false, vertical: true)
        ScrollView {
          EffortExplainerCardBody(kind: kind, onClose: { dismiss() })
        }
      }
      .background(Color.MeetPR.surfaceElevated)
      .clipShape(.rect(cornerRadius: 18))
      .overlay {
        RoundedRectangle(cornerRadius: 18)
          .stroke(Color.MeetPR.borderStrong, lineWidth: 1)
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 20)
    }
    .lineLimit(nil)
    .accessibilityAddTraits(.isModal)
    .accessibilityAction(.escape) { dismiss() }
  }
}

private struct EffortExplainerCardBody: View {
  let kind: ActualEffortMode
  let onClose: () -> Void
  @ScaledMetric(relativeTo: .headline) private var titleSize = 18.0
  @ScaledMetric(relativeTo: .footnote) private var captionSize = 13.0
  @AccessibilityFocusState private var titleFocused: Bool

  var body: some View {
    let content = EffortExplainer.content(for: kind)
    VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .top, spacing: 4) {
        VStack(alignment: .leading, spacing: 4) {
          Text(content.title)
            .font(.system(size: titleSize, weight: .semibold))
            .foregroundStyle(Color.MeetPR.textPrimary)
            .accessibilityAddTraits(.isHeader)
            .accessibilityFocused($titleFocused)
          Text(content.subtitle)
            .font(.system(size: captionSize))
            .foregroundStyle(Color.MeetPR.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        Button(action: onClose) {
          Image(systemName: "xmark")
            .font(.system(size: 16))
            .foregroundStyle(Color.MeetPR.textMuted)
            .frame(width: 44, height: 44)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(StudentStrings.localized(.effortExplainerClose))
      }
      if !content.rows.isEmpty {
        VStack(spacing: 0) {
          ForEach(content.rows, id: \.value) { row in
            EffortExplainerTableRow(row: row)
          }
        }
      }
      if let example = content.example {
        EffortExplainerExample(text: example)
      }
      Text(content.closing)
        .font(.system(size: captionSize))
        .foregroundStyle(Color.MeetPR.textMuted)
    }
    .fixedSize(horizontal: false, vertical: true)
    .padding(.top, 20)
    .padding(.horizontal, 20)
    .padding(.bottom, kind == .rpe ? 16 : 18)
    .onAppear { titleFocused = true }
  }
}

private struct EffortExplainerTableRow: View {
  let row: EffortExplainerContent.Row
  @ScaledMetric(relativeTo: .body) private var textSize = 15.0
  @ScaledMetric(relativeTo: .body) private var valueWidth = 40.0

  var body: some View {
    VStack(spacing: 0) {
      Rectangle().fill(Color.MeetPR.borderStrong).frame(height: 1)
      HStack(alignment: .firstTextBaseline, spacing: 12) {
        Text(row.value)
          .font(.system(size: textSize, weight: .bold, design: .monospaced))
          .foregroundStyle(Color.MeetPR.gold500)
          .frame(width: valueWidth, alignment: .leading)
        Text(row.description)
          .font(.system(size: textSize))
          .foregroundStyle(Color.MeetPR.textSecondary)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .padding(.vertical, 9)
    }
    .accessibilityElement(children: .combine)
  }
}

private struct EffortExplainerExample: View {
  let text: String
  @ScaledMetric(relativeTo: .body) private var textSize = 15.0

  var body: some View {
    styledExample
      .font(.system(size: textSize))
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.vertical, 12)
      .padding(.horizontal, 14)
      .background(Color.MeetPR.surfaceRaised, in: .rect(cornerRadius: 10))
  }

  private var styledExample: Text {
    let parts = text.split(separator: " → ", maxSplits: 1)
    guard parts.count == 2 else { return Text(text) }
    let introduction = Text(parts[0]).foregroundStyle(Color.MeetPR.textSecondary)
    let arrow = Text(" → ").foregroundStyle(Color.MeetPR.textMuted)
    let answer = Text(parts[1])
      .font(.system(size: textSize, weight: .bold, design: .monospaced))
      .foregroundStyle(Color.MeetPR.gold500)
    return Text("\(introduction)\(arrow)\(answer)")
  }

}

struct EffortRIRHint: View {
  let value: String
  @ScaledMetric(relativeTo: .footnote) private var textSize = 13.0

  var body: some View {
    if let hint = EffortExplainer.rirStepperCopy(value) {
      Text(hint)
        .font(.system(size: textSize))
        .foregroundStyle(Color.MeetPR.textSecondary)
        .frame(maxWidth: .infinity)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier("setEntry.rirHint")
    }
  }
}
