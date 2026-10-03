import CoreModels
import DesignSystem
import Foundation
import SwiftUI

@MainActor
public struct SetRefSharePicker: View {
  private let context: SetRefSharingContext
  private let conversationID: UUID
  private let coordinator: ChatSendCoordinator
  private let initialSetLogID: UUID?
  private let onStaged: @MainActor () -> Void
  @Environment(\.dismiss) private var dismiss
  @State private var presentation = SetRefPickerPresentation()
  @State private var includesVideo = true
  @State private var question = ""
  @State private var isLoading = true
  @State private var isConfirming = false
  @State private var errorMessage: String?

  public init(
    context: SetRefSharingContext,
    conversationID: UUID,
    coordinator: ChatSendCoordinator,
    initialSetLogID: UUID? = nil,
    onStaged: @escaping @MainActor () -> Void
  ) {
    self.context = context
    self.conversationID = conversationID
    self.coordinator = coordinator
    self.initialSetLogID = initialSetLogID
    self.onStaged = onStaged
  }

  public var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: MeetPRSpacing.base) {
          if isLoading {
            ProgressView().frame(maxWidth: .infinity)
          } else if presentation.candidates.isEmpty {
            Text(errorMessage ?? ChatStrings.noShareableSetsDescription)
              .font(.MeetPR.body)
          } else {
            Text(ChatStrings.setRefPrompt)
              .font(.MeetPR.body)
            ForEach(presentation.groups) { group in
              SetRefExerciseCard(group: group, presentation: presentation) { candidate in
                presentation.select(candidate.id)
                includesVideo = candidate.video?.state != .failed
                errorMessage = nil
              }
            }
            Text(ChatStrings.setRefQuestion)
              .font(.MeetPR.bodyEmphasis)
            TextField(ChatStrings.setRefQuestionPlaceholder, text: $question, axis: .vertical)
              .font(.MeetPR.body)
              .lineLimit(3...6)
              .padding(MeetPRSpacing.md)
              .background(Color.MeetPR.surfaceCard, in: .rect(cornerRadius: MeetPRRadius.md))
              .accessibilityIdentifier("chat.setRef.question")
            if let video = presentation.selectedCandidate?.video {
              SetRefVideoToggle(video: video, includesVideo: $includesVideo)
            }
            if let errorMessage {
              Text(errorMessage)
                .font(.MeetPR.footnote)
                .foregroundStyle(Color.MeetPR.danger)
            }
          }
        }
        .padding(MeetPRSpacing.base)
        .disabled(isConfirming)
      }
      .background(Color.MeetPR.bgBase)
      .foregroundStyle(Color.MeetPR.textPrimary)
      .safeAreaInset(edge: .bottom) {
        VStack(spacing: MeetPRSpacing.sm) {
          if let summary = presentation.sendSummary {
            Text(summary)
              .font(.MeetPR.footnote)
              .fixedSize(horizontal: false, vertical: true)
          }
          Button(action: confirm) {
            HStack {
              if isConfirming { ProgressView() }
              Text(ChatStrings.sendToCoach)
                .font(.MeetPR.bodyEmphasis)
            }
            .frame(maxWidth: .infinity, minHeight: MeetPRSpacing.minimumHitTarget)
            .padding(.vertical, MeetPRSpacing.sm)
            .foregroundStyle(Color.MeetPR.ctaText)
            .background(Color.MeetPR.goldCTA, in: .rect(cornerRadius: MeetPRRadius.lg))
          }
          .buttonStyle(PressScaleButtonStyle())
          .disabled(!presentation.canSend || isConfirming)
          .accessibilityIdentifier("chat.setRef.confirm")
        }
        .padding(MeetPRSpacing.base)
        .background(Color.MeetPR.bgBase)
      }
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
      #endif
      .toolbar {
        ToolbarItem(placement: .principal) {
          Text(ChatStrings.askCoach).font(.MeetPR.headline)
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(ChatStrings.close) { dismiss() }
            .font(.MeetPR.body)
            .disabled(isConfirming)
        }
      }
    }
    .interactiveDismissDisabled(isConfirming)
    .task { await loadCandidates() }
  }

  private func loadCandidates() async {
    do {
      presentation.load(
        candidates: try await context.candidates(), initialSetLogID: initialSetLogID)
      includesVideo = presentation.selectedCandidate?.video?.state != .failed
    } catch {
      guard !Task.isCancelled else { return }
      errorMessage = ChatStrings.trainingLoadFailed
    }
    isLoading = false
  }

  private func confirm() {
    guard let candidate = presentation.selectedCandidate, !isConfirming else { return }
    isConfirming = true
    errorMessage = nil
    Task {
      defer { isConfirming = false }
      let video: SetRefVideoSelection?
      if includesVideo, let shareVideo = candidate.video {
        guard let selection = await shareVideo.selection() else {
          errorMessage = ChatStrings.videoUnavailable
          return
        }
        video = selection
      } else {
        video = nil
      }
      do {
        let intent = try coordinator.makeSetRefIntent(
          in: conversationID, source: candidate.source, note: question, video: video)
        coordinator.stageSetRef(intent)
        try coordinator.sendStagedSetRef(in: conversationID, note: question)
        onStaged()
      } catch SetRefSendError.messageTooLong {
        errorMessage = ChatStrings.messageTooLong
      } catch {
        errorMessage = ChatStrings.trainingShareFailed
      }
    }
  }
}

private struct SetRefExerciseCard: View {
  let group: SetRefPickerGroup
  let presentation: SetRefPickerPresentation
  let select: (SetRefShareCandidate) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.md) {
      HStack(alignment: .firstTextBaseline) {
        Text(group.exerciseName).font(.MeetPR.bodyEmphasis)
        Spacer(minLength: MeetPRSpacing.xs)
        if let weekCode = group.weekCode {
          Text(weekCode).font(.MeetPR.monoLabel)
        }
      }
      LazyVGrid(
        columns: Array(
          repeating: GridItem(.flexible(), spacing: MeetPRSpacing.xs),
          count: presentation.gridColumnCount), spacing: MeetPRSpacing.sm
      ) {
        ForEach(group.candidates) { candidate in
          if let cell = presentation.cell(for: candidate) {
            SetRefCandidateCell(
              cell: cell, isSelected: candidate.id == presentation.selectedCandidateID,
              select: { select(candidate) }
            )
            .accessibilityIdentifier("chat.setRef.candidate.\(candidate.id.uuidString)")
          }
        }
      }
    }
    .padding(MeetPRSpacing.md)
    .background(Color.MeetPR.surfaceElevated, in: .rect(cornerRadius: MeetPRRadius.lg))
  }
}

private struct SetRefCandidateCell: View {
  let cell: SetRefPickerCell
  let isSelected: Bool
  let select: () -> Void

  var body: some View {
    Button(action: select) {
      VStack(alignment: .leading, spacing: MeetPRSpacing.xs) {
        Text(cell.setLabel).font(.MeetPR.footnote)
        Text(cell.load).font(.MeetPR.body(size: MeetPRFontMetrics.size14, weight: .semibold))
        Text(cell.status).font(.MeetPR.caption).foregroundStyle(Color.MeetPR.textSecondary)
      }
      .fixedSize(horizontal: false, vertical: true)
      .frame(maxWidth: .infinity, minHeight: MeetPRSpacing.minimumHitTarget, alignment: .leading)
      .padding(MeetPRSpacing.sm)
      .background(isSelected ? Color.MeetPR.surfaceCard : Color.clear)
      .clipShape(.rect(cornerRadius: MeetPRRadius.md))
      .overlay {
        RoundedRectangle(cornerRadius: MeetPRRadius.md)
          .stroke(
            isSelected ? Color.MeetPR.textPrimary : Color.MeetPR.borderDefault,
            lineWidth: isSelected ? 2 : 1)
      }
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }
}

private struct SetRefVideoToggle: View {
  let video: SetRefShareVideo
  @Binding var includesVideo: Bool

  var body: some View {
    Toggle(isOn: $includesVideo) {
      VStack(alignment: .leading, spacing: MeetPRSpacing.xs) {
        Text(ChatStrings.includeVideo).font(.MeetPR.body)
        Text(status).font(.MeetPR.caption).foregroundStyle(Color.MeetPR.textSecondary)
      }
    }
    .disabled(video.state == .failed)
  }

  private var status: String {
    switch video.state {
    case .uploading: ChatStrings.videoUploading
    case .ready: ChatStrings.videoReady
    case .failed: ChatStrings.videoFailed
    }
  }
}
