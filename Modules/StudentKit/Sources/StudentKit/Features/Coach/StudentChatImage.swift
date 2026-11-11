import ChatUI
import CoreModels
import DesignSystem
import SwiftUI

struct StudentChatImage: View {
  let message: ChatMessage
  let model: ConversationViewModel
  let fullScreen: Bool
  let onOpen: () -> Void

  var body: some View {
    Button(action: onOpen) {
      AsyncImage(url: message.imageURL) { phase in
        switch phase {
        case .success(let image):
          image.resizable().scaledToFit()
            .onAppear { model.imageLoaded(messageID: message.id) }
        case .failure:
          Image(systemName: "photo.badge.exclamationmark")
            .frame(width: 120, height: 120)
            .task { await model.imageLoadingFailed(messageID: message.id) }
        case .empty:
          ProgressView().frame(width: 120, height: 120)
        @unknown default:
          EmptyView()
        }
      }
      .frame(maxWidth: fullScreen ? .infinity : 240, maxHeight: fullScreen ? .infinity : 240)
      .clipShape(.rect(cornerRadius: 16))
    }
    .buttonStyle(.plain)
    .accessibilityLabel(StudentStrings.localized(.studentBlackGoldChatView018))
    .task { await model.refreshImageIfNeeded(messageID: message.id) }
  }
}

struct StudentChatFullScreenImage: View {
  let messageID: UUID
  let model: ConversationViewModel
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    ZStack(alignment: .topTrailing) {
      Color.black.ignoresSafeArea()
      if let message = model.message(withID: messageID) {
        StudentChatImage(message: message, model: model, fullScreen: true, onOpen: {})
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
      Button {
        dismiss()
      } label: {
        Image(systemName: "xmark.circle.fill").font(.title).foregroundStyle(.white)
          .padding(MeetPRSpacing.space4)
      }
      .accessibilityLabel(StudentStrings.localized(.weightDismiss))
    }
  }
}

struct StudentChatImageSelection: Identifiable {
  let id: UUID
}
