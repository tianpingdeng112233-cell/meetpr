import CoreModels
import DesignSystem
import PhotosUI
import SwiftUI

@MainActor
public struct ChatComposer: View {
  private let viewModel: ConversationViewModel
  private let downsampler: ChatImageDownsampler
  private let onShareTodayTraining: (@MainActor () -> Void)?
  @State private var text = ""
  @State private var selectedPhoto: PhotosPickerItem?
  @State private var isPreparingImage = false
  @State private var imageErrorMessage: String?

  public init(
    viewModel: ConversationViewModel,
    downsampler: ChatImageDownsampler = ChatImageDownsampler(),
    onShareTodayTraining: (@MainActor () -> Void)? = nil
  ) {
    self.viewModel = viewModel
    self.downsampler = downsampler
    self.onShareTodayTraining = onShareTodayTraining
  }

  public var body: some View {
    let preparingImage = isPreparingImage
    let setRefLength = viewModel.stagedSetRefLength(note: text)
    VStack(alignment: .leading, spacing: MeetPRSpacing.xs) {
      if let stagedSetRef = viewModel.stagedSetRef {
        StagedSetRefComposerCard(
          intent: stagedSetRef,
          discard: viewModel.discardStagedSetRef
        )
      }

      if let imageErrorMessage {
        Text(imageErrorMessage)
          .font(.caption)
          .foregroundStyle(Color.MeetPR.brandRed)
      }

      if let setRefLength {
        HStack(alignment: .firstTextBaseline, spacing: MeetPRSpacing.sm) {
          if setRefLength.isOverLimit {
            Text(ChatStrings.messageTooLong)
              .accessibilityIdentifier("chat.setRef.lengthError")
          } else if let errorMessage = viewModel.setRefSendErrorMessage {
            Text(errorMessage)
          }
          Spacer(minLength: 0)
          Text("\(setRefLength.bodyUTF16Count)/\(setRefLength.maximumUTF16Count)")
            .monospacedDigit()
            .accessibilityIdentifier("chat.setRef.lengthCount")
        }
        .font(.caption)
        .foregroundStyle(
          setRefLength.isOverLimit
            ? Color.MeetPR.brandRed
            : Color.MeetPR.fgSecondary
        )
      }

      HStack(alignment: .bottom, spacing: MeetPRSpacing.sm) {
        if let onShareTodayTraining {
          Menu {
            Button(action: onShareTodayTraining) {
              Label(ChatStrings.shareTodayTraining, systemImage: "dumbbell")
            }
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
              Label(ChatStrings.choosePhoto, systemImage: "photo")
            }
          } label: {
            ComposerAttachmentIcon(
              preparingImage: preparingImage,
              systemImage: "plus"
            )
          }
          .disabled(isPreparingImage)
          .accessibilityLabel(ChatStrings.addAttachment)
        } else {
          PhotosPicker(selection: $selectedPhoto, matching: .images) {
            ComposerAttachmentIcon(
              preparingImage: preparingImage,
              systemImage: "photo"
            )
          }
          .disabled(isPreparingImage)
          .accessibilityLabel(ChatStrings.choosePhoto)
        }

        TextField(composerPlaceholder, text: $text, axis: .vertical)
          .lineLimit(1...5)
          .textFieldStyle(.plain)
          .padding(.horizontal, MeetPRSpacing.md)
          .padding(.vertical, MeetPRSpacing.sm)
          .background(Color.MeetPR.surface2)
          .clipShape(.rect(cornerRadius: MeetPRRadius.xl))
          .onChange(of: text) { _, newValue in
            viewModel.clearSetRefSendError()
            if viewModel.stagedSetRef == nil,
              newValue.count > ConversationViewModel.maximumTextLength
            {
              text = String(newValue.prefix(ConversationViewModel.maximumTextLength))
            }
          }

        Button(action: send) {
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
    if let length = viewModel.stagedSetRefLength(note: text) {
      return !length.isOverLimit
    }
    return
      !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && text.count <= ConversationViewModel.maximumTextLength
  }

  private var composerPlaceholder: String {
    viewModel.stagedSetRef == nil
      ? ChatStrings.composerPlaceholder
      : ChatStrings.setRefNotePlaceholder
  }

  private func send() {
    let clientID: String?
    if viewModel.stagedSetRef != nil {
      clientID = viewModel.sendStagedSetRef(note: text)
    } else {
      clientID = viewModel.sendText(text)
    }
    guard clientID != nil else {
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

private struct ComposerAttachmentIcon: View {
  let preparingImage: Bool
  let systemImage: String

  var body: some View {
    if preparingImage {
      ProgressView()
        .frame(width: 44, height: 44)
        .accessibilityLabel(ChatStrings.preparingImage)
    } else {
      Image(systemName: systemImage)
        .font(.body)
        .foregroundStyle(Color.MeetPR.fgPrimary)
        .frame(width: 44, height: 44)
    }
  }
}

@MainActor
private struct StagedSetRefComposerCard: View {
  let intent: SetRefSendIntent
  let discard: @MainActor () -> Void

  var body: some View {
    HStack(alignment: .top, spacing: MeetPRSpacing.sm) {
      Image(systemName: "dumbbell")
        .foregroundStyle(Color.MeetPR.brandRed)
      VStack(alignment: .leading, spacing: MeetPRSpacing.xs) {
        Text(ChatStrings.sendCurrentSetRecord)
          .font(.caption.bold())
          .foregroundStyle(Color.MeetPR.fgSecondary)
        Text(SetRefCanonicalFormatter.firstLine(for: intent.setRef))
          .font(.footnote)
          .foregroundStyle(Color.MeetPR.fgPrimary)
          .lineLimit(2)
      }
      Spacer(minLength: 0)
      Button(action: discard) {
        Image(systemName: "xmark.circle.fill")
          .foregroundStyle(Color.MeetPR.fgTertiary)
      }
      .buttonStyle(.plain)
      .accessibilityLabel(ChatStrings.removeTrainingShare)
    }
    .padding(MeetPRSpacing.sm)
    .background(Color.MeetPR.surface2)
    .clipShape(.rect(cornerRadius: MeetPRRadius.lg))
    .accessibilityIdentifier("chat.setRef.staged")
  }
}
