import DesignSystem
import SwiftUI

public struct ChatSetCardView: View {
  let presentation: ChatSetCardPresentation
  let isCurrentUser: Bool
  let deliveryStatus: ChatDeliveryStatus?
  let outgoingBubbleColor: Color
  let incomingBubbleColor: Color
  let messageFont: Font
  let outgoingTextColor: Color
  let openVideo: @MainActor () -> Void
  @State private var showsDetails = false

  public init(
    presentation: ChatSetCardPresentation,
    isCurrentUser: Bool,
    deliveryStatus: ChatDeliveryStatus? = nil,
    outgoingBubbleColor: Color = Color.MeetPR.goldCTA,
    incomingBubbleColor: Color = Color.MeetPR.surfaceCard,
    outgoingTextColor: Color = .white,
    messageFont: Font = .MeetPR.body(size: MeetPRFontMetrics.size14),
    openVideo: @escaping @MainActor () -> Void
  ) {
    self.presentation = presentation
    self.isCurrentUser = isCurrentUser
    self.deliveryStatus = deliveryStatus
    self.outgoingBubbleColor = outgoingBubbleColor
    self.incomingBubbleColor = incomingBubbleColor
    self.messageFont = messageFont
    self.outgoingTextColor = outgoingTextColor
    self.openVideo = openVideo
  }

  public var body: some View {
    VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: MeetPRSpacing.xs) {
      VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
        if let note = presentation.visibleNote {
          Text(note)
            .font(messageFont)
            .foregroundStyle(isCurrentUser ? outgoingTextColor : Color.MeetPR.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Button {
          if presentation.hasVideo { openVideo() } else { showsDetails = true }
        } label: {
          ChatSetAttachmentRow(presentation: presentation)
        }
        .buttonStyle(.plain)
      }
      .padding(MeetPRSpacing.md)
      .background(isCurrentUser ? outgoingBubbleColor : incomingBubbleColor)
      .clipShape(.rect(cornerRadius: MeetPRRadius.lg))

      Text(footer)
        .font(.MeetPR.caption)
        .foregroundStyle(Color.MeetPR.textTertiary)
    }
    .containerRelativeFrame(.horizontal, count: 4, span: 3, spacing: MeetPRSpacing.sm)
    .sheet(isPresented: $showsDetails) {
      ChatSetAttachmentDetails(presentation: presentation)
    }
  }

  private var footer: String {
    let time = presentation.createdAt.formatted(date: .omitted, time: .shortened)
    guard isCurrentUser, let deliveryStatus else { return time }
    return "\(time) · \(ChatSetCardDeliveryPresentation.text(for: deliveryStatus))"
  }
}

private struct ChatSetAttachmentRow: View {
  let presentation: ChatSetCardPresentation

  var body: some View {
    HStack(spacing: MeetPRSpacing.sm) {
      if presentation.hasVideo {
        Image(systemName: "play.fill")
          .frame(width: MeetPRSpacing.minimumHitTarget, height: MeetPRSpacing.minimumHitTarget)
          .background(Color.MeetPR.surfaceElevated, in: .rect(cornerRadius: MeetPRRadius.sm))
          .accessibilityLabel(ChatStrings.playVideo)
      }
      VStack(alignment: .leading, spacing: MeetPRSpacing.xs) {
        Text(presentation.exerciseName).font(.MeetPR.bodyEmphasis)
        Text(presentation.attachmentSummary)
          .font(.MeetPR.footnote)
          .foregroundStyle(Color.MeetPR.textSecondary)
      }
      .fixedSize(horizontal: false, vertical: true)
      .frame(maxWidth: .infinity, alignment: .leading)
      Image(systemName: "chevron.right")
    }
    .foregroundStyle(Color.MeetPR.textPrimary)
    .padding(MeetPRSpacing.sm)
    .background(Color.MeetPR.surfaceCard, in: .rect(cornerRadius: MeetPRRadius.md))
  }
}

private struct ChatSetAttachmentDetails: View {
  let presentation: ChatSetCardPresentation
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: MeetPRSpacing.md) {
          Text(
            presentation.source == .logged
              ? ChatStrings.loggedSetCardLabel : ChatStrings.plannedSetCardLabel
          )
          .font(.MeetPR.footnote)
          Text(presentation.exerciseName).font(.MeetPR.headline)
          Text(presentation.attachmentSummary).font(.MeetPR.body)
        }
        .padding(MeetPRSpacing.base)
      }
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button(ChatStrings.close) { dismiss() }.font(.MeetPR.body)
        }
      }
    }
    .presentationDetents([.medium, .large])
  }
}
