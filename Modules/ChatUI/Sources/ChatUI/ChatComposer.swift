import DesignSystem
import PhotosUI
import SwiftUI

@MainActor
public struct ChatComposer: View {
  private let viewModel: ConversationViewModel
  private let downsampler: ChatImageDownsampler
  @State private var text = ""
  @State private var selectedPhoto: PhotosPickerItem?
  @State private var isPreparingImage = false
  @State private var imageErrorMessage: String?

  public init(
    viewModel: ConversationViewModel,
    downsampler: ChatImageDownsampler = ChatImageDownsampler()
  ) {
    self.viewModel = viewModel
    self.downsampler = downsampler
  }

  public var body: some View {
    let preparingImage = isPreparingImage
    VStack(alignment: .leading, spacing: MeetPRSpacing.xs) {
      if let imageErrorMessage {
        Text(imageErrorMessage)
          .font(.caption)
          .foregroundStyle(Color.MeetPR.brandRed)
      }

      HStack(alignment: .bottom, spacing: MeetPRSpacing.sm) {
        PhotosPicker(selection: $selectedPhoto, matching: .images) {
          if preparingImage {
            ProgressView()
              .frame(width: 44, height: 44)
              .accessibilityLabel(ChatStrings.preparingImage)
          } else {
            Image(systemName: "photo")
              .font(.body)
              .foregroundStyle(Color.MeetPR.fgPrimary)
              .frame(width: 44, height: 44)
          }
        }
        .disabled(isPreparingImage)
        .accessibilityLabel(ChatStrings.choosePhoto)

        TextField(ChatStrings.composerPlaceholder, text: $text, axis: .vertical)
          .lineLimit(1...5)
          .textFieldStyle(.plain)
          .padding(.horizontal, MeetPRSpacing.md)
          .padding(.vertical, MeetPRSpacing.sm)
          .background(Color.MeetPR.surface2)
          .clipShape(.rect(cornerRadius: MeetPRRadius.xl))
          .onChange(of: text) { _, newValue in
            if newValue.count > ConversationViewModel.maximumTextLength {
              text = String(newValue.prefix(ConversationViewModel.maximumTextLength))
            }
          }

        Button(action: sendText) {
          Image(systemName: "arrow.up.circle.fill")
            .font(.title)
            .foregroundStyle(canSendText ? Color.MeetPR.brandRed : Color.MeetPR.fgDisabled)
            .frame(width: 44, height: 44)
            .overlay(alignment: .topTrailing) {
              if viewModel.hasSendingMessages {
                ProgressView()
                  .controlSize(.mini)
                  .offset(x: 2, y: -2)
              }
            }
        }
        .buttonStyle(.plain)
        .disabled(!canSendText)
        .accessibilityLabel(ChatStrings.send)
      }
    }
    .padding(.horizontal, MeetPRSpacing.md)
    .padding(.vertical, MeetPRSpacing.sm)
    .background(Color.MeetPR.surface1)
    .onChange(of: selectedPhoto) { _, newItem in
      guard let newItem else {
        return
      }
      Task {
        await prepareAndSend(newItem)
      }
    }
  }

  private var canSendText: Bool {
    !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && text.count <= ConversationViewModel.maximumTextLength
  }

  private func sendText() {
    guard viewModel.sendText(text) != nil else {
      return
    }
    text = ""
  }

  private func prepareAndSend(_ item: PhotosPickerItem) async {
    isPreparingImage = true
    imageErrorMessage = nil
    defer {
      isPreparingImage = false
      selectedPhoto = nil
    }
    do {
      guard let originalData = try await item.loadTransferable(type: Data.self) else {
        imageErrorMessage = ChatStrings.imagePreparationFailed
        return
      }
      let downsampler = downsampler
      let imageData = try await Task.detached(priority: .userInitiated) {
        try downsampler.downsampleJPEG(originalData)
      }.value
      _ = viewModel.sendImage(imageData)
    } catch {
      guard !error.isChatTaskCancellation else {
        return
      }
      imageErrorMessage = ChatStrings.imagePreparationFailed
    }
  }
}
