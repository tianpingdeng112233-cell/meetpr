import DesignSystem
import SwiftUI

public struct ChatSetCardView: View {
  let presentation: ChatSetCardPresentation
  let isCurrentUser: Bool
  let deliveryStatus: ChatDeliveryStatus?
  let openVideo: @MainActor () -> Void

  public init(
    presentation: ChatSetCardPresentation,
    isCurrentUser: Bool,
    deliveryStatus: ChatDeliveryStatus? = nil,
    openVideo: @escaping @MainActor () -> Void
  ) {
    self.presentation = presentation
    self.isCurrentUser = isCurrentUser
    self.deliveryStatus = deliveryStatus
    self.openVideo = openVideo
  }

  public var body: some View {
    // Spacing 0 at the outer level so the delivery strip can run edge to edge;
    // the body carries its own padding instead.
    VStack(alignment: .leading, spacing: 0) {
      ChatSetCardBody(presentation: presentation, openVideo: openVideo)
      if isCurrentUser, let deliveryStatus {
        Divider()
          .overlay(Color.MeetPR.borderDefault)
        // The presentation string already carries its own ✓; a Label's systemImage
        // would draw a second one.
        Text(ChatSetCardDeliveryPresentation.text(for: deliveryStatus))
          .font(.caption)
          .foregroundStyle(Color.MeetPR.textTertiary)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, MeetPRSpacing.md)
          .padding(.vertical, MeetPRSpacing.sm)
          .background(Color.MeetPR.surfaceElevated)
      }
    }
    .background(Color.MeetPR.surfaceCard)
    .clipShape(.rect(cornerRadius: MeetPRRadius.lg))
    .overlay {
      RoundedRectangle(cornerRadius: MeetPRRadius.lg)
        .stroke(Color.MeetPR.borderDefault, lineWidth: 1)
    }
    .overlay(alignment: isCurrentUser ? .trailing : .leading) {
      Rectangle()
        .fill(Color.MeetPR.gold500)
        .frame(width: MeetPRSpacing.point3)
    }
    .containerRelativeFrame(
      .horizontal,
      count: 4,
      span: 3,
      spacing: MeetPRSpacing.sm
    )
  }
}

private struct ChatSetCardBody: View {
  let presentation: ChatSetCardPresentation
  let openVideo: @MainActor () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.md) {
      ChatSetCardHeader(presentation: presentation)
      ChatSetCardTitle(presentation: presentation)
      ChatSetCardMetrics(presentation: presentation)

      if presentation.videoURL != nil {
        Button(action: openVideo) {
          Label(ChatStrings.playVideo, systemImage: "play.rectangle.fill")
            .font(.subheadline.bold())
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(Color.MeetPR.goldText)
      }

      if let note = presentation.note, !note.isEmpty {
        Text(note)
          .font(.body)
          .foregroundStyle(Color.MeetPR.textPrimary)
          .fixedSize(horizontal: false, vertical: true)
          .padding(MeetPRSpacing.sm)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(Color.MeetPR.surfaceElevated)
          .clipShape(.rect(cornerRadius: MeetPRRadius.md))
      }
    }
    .padding(MeetPRSpacing.md)
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

private struct ChatSetCardHeader: View {
  let presentation: ChatSetCardPresentation

  var body: some View {
    HStack(spacing: MeetPRSpacing.xs) {
      Image(systemName: "dumbbell.fill")
        .foregroundStyle(Color.MeetPR.goldText)
      Text(
        presentation.source == .logged
          ? ChatStrings.loggedSetCardLabel
          : ChatStrings.plannedSetCardLabel
      )
      .foregroundStyle(Color.MeetPR.goldText)
      Spacer(minLength: MeetPRSpacing.sm)
      Text(presentation.createdAt.formatted(date: .omitted, time: .shortened))
        .monospacedDigit()
        .foregroundStyle(Color.MeetPR.textTertiary)
    }
    .font(.caption.bold())
  }
}

private struct ChatSetCardTitle: View {
  let presentation: ChatSetCardPresentation

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: MeetPRSpacing.sm) {
      Text(presentation.exerciseName)
        .font(.title3.bold())
        .foregroundStyle(Color.MeetPR.textPrimary)
        .fixedSize(horizontal: false, vertical: true)
      Spacer(minLength: 0)
      Text(setPosition)
        .font(.caption)
        .monospacedDigit()
        .foregroundStyle(Color.MeetPR.textTertiary)
        .fixedSize(horizontal: true, vertical: false)
    }
  }

  private var setPosition: String {
    if let total = presentation.setTotal {
      return ChatStrings.setPosition(presentation.setNumber, total: total)
    }
    return ChatStrings.setPosition(presentation.setNumber)
  }
}

private struct ChatSetCardMetrics: View {
  let presentation: ChatSetCardPresentation

  var body: some View {
    HStack(spacing: MeetPRSpacing.md) {
      ChatSetCardLoadMetric(
        weight: presentation.weight,
        reps: presentation.reps
      )
      .frame(maxWidth: .infinity, alignment: .leading)

      Rectangle()
        .fill(Color.MeetPR.borderDefault)
        .frame(width: 1, height: 52)

      ChatSetCardMetric(
        label: ChatStrings.rpeMetric,
        value: presentation.rpe ?? "-",
        valueColor: Color.MeetPR.goldText
      )
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

private struct ChatSetCardLoadMetric: View {
  let weight: String
  let reps: String

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.xs) {
      Text(ChatStrings.weightRepsMetric)
        .font(.caption2)
        .tracking(1.1)
        .foregroundStyle(Color.MeetPR.textTertiary)
      (Text(weight)
        .font(.title2.bold())
        + Text("kg")
        .font(.subheadline.bold())
        + Text(" × \(reps)")
        .font(.title2.bold()))
        .foregroundStyle(Color.MeetPR.textPrimary)
        .fixedSize(horizontal: true, vertical: false)
    }
  }
}

private struct ChatSetCardMetric: View {
  let label: String
  let value: String
  let valueColor: Color

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.xs) {
      Text(label)
        .font(.caption2)
        .tracking(1.1)
        .foregroundStyle(Color.MeetPR.textTertiary)
      Text(value)
        .font(.title2.bold())
        .monospacedDigit()
        .foregroundStyle(valueColor)
        .fixedSize(horizontal: true, vertical: false)
    }
  }
}
