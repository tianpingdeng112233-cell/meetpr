import DesignSystem
import SwiftUI

/// Black-gold v3 palette. The card first shipped on the legacy red tokens because ChatUI was
/// written before the student-side redo landed; the redo did not reach this module, so an
/// outgoing card sat as a red block in an otherwise gold thread.
enum ChatSetCardColorToken: Equatable, Sendable {
  case goldCTA
  case surfaceCard
  case ctaText
  case ctaTextMuted
  case textPrimary
  case textTertiary
  case borderDefault
  case gold500

  var color: Color {
    switch self {
    case .goldCTA:
      Color.MeetPR.goldCTA
    case .surfaceCard:
      Color.MeetPR.surfaceCard
    case .ctaText:
      // The on-gold ink the CTA buttons use. `goldText` is the opposite pairing — gold ink on a
      // dark surface — and reading it as "gold's text colour" put gold on gold.
      Color.MeetPR.ctaText
    case .ctaTextMuted:
      Color.MeetPR.ctaText.opacity(0.72)
    case .textPrimary:
      Color.MeetPR.textPrimary
    case .textTertiary:
      Color.MeetPR.textTertiary
    case .borderDefault:
      Color.MeetPR.borderDefault
    case .gold500:
      Color.MeetPR.gold500
    }
  }
}

struct ChatSetCardAppearance: Equatable, Sendable {
  let background: ChatSetCardColorToken
  let primaryText: ChatSetCardColorToken
  let secondaryText: ChatSetCardColorToken
  let accent: ChatSetCardColorToken
  let border: ChatSetCardColorToken

  static func resolve(isCurrentUser: Bool) -> Self {
    if isCurrentUser {
      // Outgoing: gold fill with the dark on-gold text the CTA buttons use.
      Self(
        background: .goldCTA,
        primaryText: .ctaText,
        secondaryText: .ctaTextMuted,
        accent: .ctaText,
        border: .ctaTextMuted
      )
    } else {
      // Incoming: neutral card, gold only as the accent.
      Self(
        background: .surfaceCard,
        primaryText: .textPrimary,
        secondaryText: .textTertiary,
        accent: .gold500,
        border: .borderDefault
      )
    }
  }
}

public struct ChatSetCardView: View {
  let presentation: ChatSetCardPresentation
  let isCurrentUser: Bool
  let openVideo: @MainActor () -> Void

  public init(
    presentation: ChatSetCardPresentation,
    isCurrentUser: Bool,
    openVideo: @escaping @MainActor () -> Void
  ) {
    self.presentation = presentation
    self.isCurrentUser = isCurrentUser
    self.openVideo = openVideo
  }

  private var appearance: ChatSetCardAppearance {
    .resolve(isCurrentUser: isCurrentUser)
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.md) {
      Label(ChatStrings.trainingShare, systemImage: "dumbbell.fill")
        .font(.caption.bold())
        .foregroundStyle(appearance.accent.color)

      Text(presentation.exerciseName)
        .font(.body.bold())
        .foregroundStyle(appearance.primaryText.color)
        .fixedSize(horizontal: false, vertical: true)

      HStack(alignment: .firstTextBaseline, spacing: MeetPRSpacing.md) {
        ChatSetCardMetric(
          label: ChatStrings.setNumber,
          value: "第 \(presentation.setNumber) 组",
          appearance: appearance
        )
        ChatSetCardMetric(
          label: ChatStrings.load,
          value: presentation.load,
          appearance: appearance
        )
        if let rpe = presentation.rpe {
          ChatSetCardMetric(label: "RPE", value: rpe, appearance: appearance)
        }
      }

      Text(presentation.dayDate)
        .font(.caption)
        .foregroundStyle(appearance.secondaryText.color)

      if presentation.videoURL != nil {
        Button(action: openVideo) {
          Label(ChatStrings.playVideo, systemImage: "play.rectangle.fill")
            .font(.subheadline.bold())
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(appearance.accent.color)
      }

      if let note = presentation.note, !note.isEmpty {
        Text(note)
          .font(.body)
          .foregroundStyle(appearance.primaryText.color)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding(MeetPRSpacing.md)
    .background(appearance.background.color)
    .clipShape(.rect(cornerRadius: MeetPRRadius.lg))
    .overlay {
      RoundedRectangle(cornerRadius: MeetPRRadius.lg)
        .stroke(appearance.border.color, lineWidth: 1)
    }
    .containerRelativeFrame(
      .horizontal,
      count: 4,
      span: 3,
      spacing: MeetPRSpacing.sm
    )
  }
}

private struct ChatSetCardMetric: View {
  let label: String
  let value: String
  let appearance: ChatSetCardAppearance

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.xs) {
      Text(label)
        .font(.caption2)
        .foregroundStyle(appearance.secondaryText.color)
      Text(value)
        .font(.subheadline.bold())
        .foregroundStyle(appearance.primaryText.color)
        .fixedSize(horizontal: true, vertical: false)
    }
  }
}
