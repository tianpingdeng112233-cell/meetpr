import DesignSystem
import SwiftUI

enum ChatSetCardColorToken: Equatable, Sendable {
  case brandRed
  case surface1
  case white
  case whiteMuted
  case fgPrimary
  case fgTertiary
  case border

  var color: Color {
    switch self {
    case .brandRed:
      Color.MeetPR.brandRed
    case .surface1:
      Color.MeetPR.surface1
    case .white:
      Color.white
    case .whiteMuted:
      Color.white.opacity(0.72)
    case .fgPrimary:
      Color.MeetPR.fgPrimary
    case .fgTertiary:
      Color.MeetPR.fgTertiary
    case .border:
      Color.MeetPR.border
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
      Self(
        background: .brandRed,
        primaryText: .white,
        secondaryText: .whiteMuted,
        accent: .white,
        border: .whiteMuted
      )
    } else {
      Self(
        background: .surface1,
        primaryText: .fgPrimary,
        secondaryText: .fgTertiary,
        accent: .brandRed,
        border: .border
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
