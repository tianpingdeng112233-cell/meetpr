import AVFoundation
import AVKit
import ChatUI
import CoreModels
import DesignSystem
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// Owns the picked copy until send transfers ownership to the session outbox.
@MainActor
struct StudentChatVideoPicker: ViewModifier {
  @Binding var isPresented: Bool
  let coachName: String
  let send: @MainActor (ChatVideoFile) -> Bool
  @State private var selection: PhotosPickerItem?
  @State private var preview: ChatVideoFile?
  @State private var isPreparing = false
  @State private var chooseAgain = false
  @State private var errorMessage: String?

  func body(content: Content) -> some View {
    content
      .photosPicker(
        isPresented: $isPresented, selection: $selection,
        matching: .videos, preferredItemEncoding: .current
      )
      .task(id: selection) {
        await loadSelection()
      }
      .overlay {
        if isPreparing {
          ProgressView(ChatVideoStrings.preparing)
            .padding(MeetPRSpacing.lg)
            .background(Color.MeetPR.surfaceCard, in: .rect(cornerRadius: MeetPRRadius.lg))
        }
      }
      .sheet(item: $preview, onDismiss: previewDismissed, content: previewContent)
      .alert(
        ChatVideoStrings.video,
        isPresented: Binding(
          get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
        )
      ) {
        Button(StudentStrings.acknowledge) { errorMessage = nil }
      } message: {
        Text(errorMessage ?? "")
      }
      .onDisappear { discardPreview() }
  }

  private func previewDismissed() {
    if chooseAgain {
      chooseAgain = false
      isPresented = true
    }
  }

  private func previewContent(_ video: ChatVideoFile) -> some View {
    StudentChatVideoPreview(
      video: video, coachName: coachName,
      cancel: { discardPreview() },
      chooseAgain: {
        chooseAgain = true
        discardPreview()
      },
      send: { if send(video) { preview = nil } }
    )
    .interactiveDismissDisabled()
  }

  private func loadSelection() async {
    guard let selection else { return }
    isPreparing = true
    defer {
      isPreparing = false
      self.selection = nil
    }
    do {
      guard let transferred = try await selection.loadTransferable(type: PickedChatVideo.self)
      else { throw ChatVideoPreparationError.invalidVideo }
      do {
        preview = try await prepareVideo(at: transferred.url)
      } catch {
        try? FileManager.default.removeItem(at: transferred.url)
        throw error
      }
    } catch {
      guard !Task.isCancelled else { return }
      errorMessage =
        error as? ChatVideoPreparationError == .tooLarge
        ? ChatVideoStrings.tooLarge : ChatVideoStrings.preparationFailed
    }
  }

  private func discardPreview() {
    if let preview { try? FileManager.default.removeItem(at: preview.fileURL) }
    preview = nil
  }

  private func prepareVideo(at url: URL) async throws -> ChatVideoFile {
    try Task.checkCancellation()
    let values = try url.resourceValues(forKeys: [.fileSizeKey])
    guard let size = values.fileSize, size > 0 else { throw ChatVideoPreparationError.invalidVideo }
    guard Int64(size) <= ChatVideoFile.maximumByteCount else {
      throw ChatVideoPreparationError.tooLarge
    }
    let contentType: String
    switch url.pathExtension.lowercased() {
    case "mp4": contentType = "video/mp4"
    case "mov": contentType = "video/quicktime"
    default: throw ChatVideoPreparationError.invalidVideo
    }
    let asset = AVURLAsset(url: url)
    guard try await asset.load(.isPlayable),
      !(try await asset.loadTracks(withMediaType: .video)).isEmpty
    else { throw ChatVideoPreparationError.invalidVideo }
    let seconds = try await asset.load(.duration).seconds
    guard seconds.isFinite, seconds > 0, seconds < Double(Int.max) else {
      throw ChatVideoPreparationError.invalidVideo
    }
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    generator.maximumSize = CGSize(width: 480, height: 480)
    let poster: Data?
    #if os(iOS)
      if let result = try? await generator.image(at: .zero) {
        poster = UIImage(cgImage: result.image).jpegData(compressionQuality: 0.75)
      } else {
        poster = nil
      }
    #else
      poster = nil
    #endif
    try Task.checkCancellation()
    return ChatVideoFile(
      fileURL: url, contentType: contentType, byteCount: Int64(size),
      durationSeconds: Int(seconds.rounded(.up)), posterData: poster)
  }
}

private enum ChatVideoPreparationError: Error, Equatable { case invalidVideo, tooLarge }

private struct PickedChatVideo: Transferable, Sendable {
  let url: URL
  static var transferRepresentation: some TransferRepresentation {
    FileRepresentation(importedContentType: .movie) { received in
      let extensionName = received.file.pathExtension.lowercased()
      let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("chat-video-\(UUID().uuidString).\(extensionName)")
      try FileManager.default.copyItem(at: received.file, to: url)
      return PickedChatVideo(url: url)
    }
  }
}

@MainActor
private struct StudentChatVideoPreview: View {
  let video: ChatVideoFile
  let coachName: String
  let cancel: @MainActor () -> Void
  let chooseAgain: @MainActor () -> Void
  let send: @MainActor () -> Void
  #if os(iOS)
    @State private var previewAudio: UploadVideoAudio?
  #endif
  @State private var player: AVPlayer

  init(
    video: ChatVideoFile, coachName: String,
    cancel: @escaping @MainActor () -> Void, chooseAgain: @escaping @MainActor () -> Void,
    send: @escaping @MainActor () -> Void
  ) {
    self.video = video
    self.coachName = coachName
    self.cancel = cancel
    self.chooseAgain = chooseAgain
    self.send = send
    _player = State(initialValue: AVPlayer(url: video.fileURL))
  }

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Button(ChatVideoStrings.chooseAgain) {
          player.pause()
          chooseAgain()
        }
        Spacer()
        Text(ChatVideoStrings.preview).font(.headline)
        Spacer()
        Button(ChatVideoStrings.cancel) {
          player.pause()
          cancel()
        }
      }
      .padding(MeetPRSpacing.md)
      #if os(iOS)
        VideoPlayer(player: previewAudio == nil ? nil : player)
          .onAppear { previewAudio = try? UploadVideoAudio(.preview) }
      #else
        VideoPlayer(player: player)
      #endif
      HStack {
        Text(ChatVideoStrings.recipient(coachName)).font(.subheadline)
        Spacer()
        Button(ChatVideoStrings.send) {
          player.pause()
          send()
        }
        .buttonStyle(.borderedProminent)
        .tint(Color.MeetPR.goldCTA)
        .accessibilityIdentifier("chat.video.send")
      }
      .padding(MeetPRSpacing.md)
    }
    .background(Color.MeetPR.bgBase)
    .onDisappear {
      player.pause()
      #if os(iOS)
        previewAudio = nil
      #endif
    }
  }
}
