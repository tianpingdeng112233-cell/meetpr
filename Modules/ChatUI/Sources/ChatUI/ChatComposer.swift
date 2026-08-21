import CoreModels
import DesignSystem
import PhotosUI
import SwiftUI

@MainActor
public struct ChatComposer: View {
  private let viewModel: ConversationViewModel
  private let downsampler: ChatImageDownsampler
  private let onShareTodayTraining: (@MainActor () -> Void)?
  private let layout: ChatComposerLayout
  @State private var text = ""
  @State private var selectedPhoto: PhotosPickerItem?
  @State private var isPreparingImage = false
  @State private var imageErrorMessage: String?

  public init(
    viewModel: ConversationViewModel,
    downsampler: ChatImageDownsampler = ChatImageDownsampler(),
    initialText: String = "",
    layout: ChatComposerLayout = .standard,
    onShareTodayTraining: (@MainActor () -> Void)? = nil
  ) {
    self.viewModel = viewModel
    self.downsampler = downsampler
    self.onShareTodayTraining = onShareTodayTraining
    self.layout = layout
    _text = State(initialValue: String(initialText.prefix(ConversationViewModel.maximumTextLength)))
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
          .foregroundStyle(Color.MeetPR.gold500)
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
            ? Color.MeetPR.gold500
            : Color.MeetPR.textSecondary
        )
      }

      switch layout {
      case .standard:
        standardComposer(preparingImage: preparingImage)
      case .compactPill:
        compactPillComposer
      }
    }
    .padding(.horizontal, MeetPRSpacing.md)
    .padding(.vertical, MeetPRSpacing.sm)
    .background(Color.MeetPR.surfaceCard)
    .onChange(of: selectedPhoto) { _, newItem in
      guard let newItem else {
        return
      }
      Task {
        await prepareAndSend(newItem)
      }
    }
  }

  private func standardComposer(preparingImage: Bool) -> some View {
    HStack(alignment: .bottom, spacing: MeetPRSpacing.sm) {
      attachmentControl(preparingImage: preparingImage)
      composerTextField
        .padding(.horizontal, MeetPRSpacing.md)
        .padding(.vertical, MeetPRSpacing.sm)
        .background(Color.MeetPR.surfaceElevated)
        .clipShape(.rect(cornerRadius: MeetPRRadius.xl))
      standardSendButton
    }
  }

  private var compactPillComposer: some View {
    HStack(spacing: MeetPRSpacing.point6) {
      composerTextField
        .padding(.leading, MeetPRSpacing.point10)
        .padding(.vertical, MeetPRSpacing.point10)
      Button(action: send) {
        Image(systemName: "arrow.up")
          .font(.MeetPR.system(size: MeetPRFontMetrics.size18, weight: .semibold))
          .foregroundStyle(Color.MeetPR.textPrimary)
          .frame(width: 34, height: 34)
          .background(Color.MeetPR.borderStrong.opacity(canSendText ? 1 : 0.65))
          .clipShape(.circle)
          .overlay {
            if viewModel.hasSendingMessages {
              ProgressView()
                .controlSize(.mini)
            }
          }
      }
      .buttonStyle(.plain)
      .disabled(!canSendText)
      .accessibilityLabel(ChatStrings.send)
    }
    .padding(.trailing, MeetPRSpacing.point5)
    .background(Color.MeetPR.surfaceCard)
    .clipShape(.capsule)
    .overlay {
      Capsule()
        .stroke(Color.MeetPR.borderDefault, lineWidth: MeetPRSpacing.point1)
    }
  }

  @ViewBuilder
  private func attachmentControl(preparingImage: Bool) -> some View {
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
  }

  private var composerTextField: some View {
    TextField(composerPlaceholder, text: $text, axis: .vertical)
      .lineLimit(1...5)
      .textFieldStyle(.plain)
      .onChange(of: text) { _, newValue in
        viewModel.clearSetRefSendError()
        if viewModel.stagedSetRef == nil,
          newValue.count > ConversationViewModel.maximumTextLength
        {
          text = String(newValue.prefix(ConversationViewModel.maximumTextLength))
        }
      }
  }

  private var standardSendButton: some View {
    Button(action: send) {
      Image(systemName: "arrow.up.circle.fill")
        .font(.title)
        .foregroundStyle(canSendText ? Color.MeetPR.gold500 : Color.MeetPR.textDisabled)
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

public enum ChatComposerLayout: Sendable {
  case standard
  case compactPill
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
        .foregroundStyle(Color.MeetPR.textPrimary)
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
        .foregroundStyle(Color.MeetPR.gold500)
      VStack(alignment: .leading, spacing: MeetPRSpacing.xs) {
        Text(ChatStrings.sendCurrentSetRecord)
          .font(.caption.bold())
          .foregroundStyle(Color.MeetPR.textSecondary)
        Text(ChatSetRefDisplayFormatter.firstLine(for: intent.setRef))
          .font(.footnote)
          .foregroundStyle(Color.MeetPR.textPrimary)
          .lineLimit(2)
      }
      Spacer(minLength: 0)
      Button(action: discard) {
        Image(systemName: "xmark.circle.fill")
          .foregroundStyle(Color.MeetPR.textTertiary)
      }
      .buttonStyle(.plain)
      .accessibilityLabel(ChatStrings.removeTrainingShare)
    }
    .padding(MeetPRSpacing.sm)
    .background(Color.MeetPR.surfaceElevated)
    .clipShape(.rect(cornerRadius: MeetPRRadius.lg))
    .accessibilityIdentifier("chat.setRef.staged")
  }
}
