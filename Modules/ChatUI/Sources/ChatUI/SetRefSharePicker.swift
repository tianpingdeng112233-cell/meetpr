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

  @State private var presentation = SetRefPickerPresentation()
  @State private var includesVideo = true
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
      Group {
        if isLoading {
          ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if presentation.candidates.isEmpty {
          if let errorMessage {
            ContentUnavailableView(
              ChatStrings.trainingLoadFailed,
              systemImage: "exclamationmark.triangle",
              description: Text(errorMessage)
            )
          } else {
            ContentUnavailableView(
              ChatStrings.noShareableSets,
              systemImage: "dumbbell",
              description: Text(ChatStrings.noShareableSetsDescription)
            )
          }
        } else {
          switch presentation.page {
          case .selection:
            SetRefCandidateList(
              candidates: presentation.candidates,
              selectedCandidateID: presentation.selectedCandidateID,
              select: { candidate in
                presentation.select(candidate.id)
                errorMessage = nil
              },
              proceed: proceedToConfirmation
            )
          case .confirmation:
            if let candidate = presentation.selectedCandidate {
              SetRefConfirmationCard(
                candidate: candidate,
                includesVideo: $includesVideo,
                isConfirming: isConfirming,
                errorMessage: errorMessage,
                confirm: confirm
              )
            }
          }
        }
      }
      .background(Color.MeetPR.bgBase)
      .navigationTitle(ChatStrings.shareTodayTraining)
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
      #endif
      .toolbar {
        if presentation.page == .confirmation {
          ToolbarItem(placement: .cancellationAction) {
            Button(ChatStrings.back) {
              presentation.showSelection()
              errorMessage = nil
            }
          }
        }
      }
    }
    .task {
      await loadCandidates()
    }
  }

  private func loadCandidates() async {
    do {
      let loaded = try await context.candidates()
      presentation.load(
        candidates: loaded,
        initialSetLogID: initialSetLogID
      )
      isLoading = false
    } catch {
      guard !Task.isCancelled else { return }
      presentation.load(candidates: [], initialSetLogID: nil)
      errorMessage = ChatStrings.trainingLoadFailed
      isLoading = false
    }
  }

  private func proceedToConfirmation() {
    guard presentation.proceedToConfirmation(),
      let candidate = presentation.selectedCandidate
    else {
      return
    }
    includesVideo = candidate.video?.state != .failed
    errorMessage = nil
  }

  private func confirm() {
    guard let candidate = presentation.selectedCandidate, !isConfirming else { return }
    isConfirming = true
    errorMessage = nil
    Task {
      let video: SetRefVideoSelection?
      if includesVideo, let shareVideo = candidate.video {
        guard let selection = await shareVideo.selection() else {
          errorMessage = ChatStrings.videoUnavailable
          isConfirming = false
          return
        }
        video = selection
      } else {
        video = nil
      }

      do {
        let intent = try coordinator.makeSetRefIntent(
          in: conversationID,
          source: candidate.source,
          note: nil,
          video: video
        )
        coordinator.stageSetRef(intent)
        onStaged()
      } catch {
        errorMessage = ChatStrings.trainingShareFailed
        isConfirming = false
      }
    }
  }
}

@MainActor
private struct SetRefCandidateList: View {
  let candidates: [SetRefShareCandidate]
  let selectedCandidateID: UUID?
  let select: @MainActor (SetRefShareCandidate) -> Void
  let proceed: @MainActor () -> Void

  var body: some View {
    VStack(spacing: 0) {
      List {
        let loggedCandidates = candidates.filter { $0.source.source == .logged }
        if !loggedCandidates.isEmpty {
          Section(ChatStrings.completedSection) {
            ForEach(loggedCandidates) { candidate in
              SetRefCandidateRow(
                candidate: candidate,
                isSelected: selectedCandidateID == candidate.id,
                select: select
              )
            }
          }
        }

        let plannedCandidates = candidates.filter { $0.source.source == .planned }
        if !plannedCandidates.isEmpty {
          Section(ChatStrings.todayPlanSection) {
            ForEach(plannedCandidates) { candidate in
              SetRefCandidateRow(
                candidate: candidate,
                isSelected: selectedCandidateID == candidate.id,
                select: select
              )
            }
          }
        }
      }
      .scrollContentBackground(.hidden)

      Button(action: proceed) {
        Text(ChatStrings.continueSelection)
          .font(.body.bold())
          .frame(maxWidth: .infinity)
          .frame(height: 48)
          .foregroundStyle(Color.MeetPR.ctaText)
          .background(Color.MeetPR.goldCTA)
          .clipShape(.rect(cornerRadius: MeetPRRadius.lg))
      }
      .buttonStyle(.plain)
      .disabled(selectedCandidateID == nil)
      .accessibilityIdentifier("chat.setRef.proceed")
      .padding(MeetPRSpacing.base)
    }
  }
}

@MainActor
private struct SetRefCandidateRow: View {
  let candidate: SetRefShareCandidate
  let isSelected: Bool
  let select: @MainActor (SetRefShareCandidate) -> Void

  var body: some View {
    Button {
      select(candidate)
    } label: {
      HStack(spacing: MeetPRSpacing.sm) {
        VStack(alignment: .leading, spacing: MeetPRSpacing.xs) {
          Text(candidate.source.exerciseName)
            .font(.body.bold())
            .foregroundStyle(Color.MeetPR.textPrimary)
          Text(summary)
            .font(.footnote)
            .foregroundStyle(Color.MeetPR.textSecondary)
        }
        Spacer(minLength: 0)
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
          .foregroundStyle(
            isSelected
              ? Color.MeetPR.gold500
              : Color.MeetPR.textTertiary
          )
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier("chat.setRef.candidate.\(candidate.id.uuidString)")
  }

  private var summary: String {
    guard let setRef = try? SetRefV1.normalizingSource(candidate.source) else {
      return ChatStrings.invalidSetRecord
    }
    return ChatSetRefDisplayFormatter.firstLine(for: setRef)
  }
}

@MainActor
private struct SetRefConfirmationCard: View {
  let candidate: SetRefShareCandidate
  @Binding var includesVideo: Bool
  let isConfirming: Bool
  let errorMessage: String?
  let confirm: @MainActor () -> Void

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: MeetPRSpacing.base) {
        Text(SetRefConfirmationCopy.prompt(for: candidate.source.source))
          .font(.headline)
          .foregroundStyle(Color.MeetPR.textPrimary)

        Text(firstLine)
          .font(.body)
          .foregroundStyle(Color.MeetPR.textPrimary)
          .padding(MeetPRSpacing.base)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(Color.MeetPR.surfaceElevated)
          .clipShape(.rect(cornerRadius: MeetPRRadius.lg))

        if let video = candidate.video {
          Toggle(isOn: $includesVideo) {
            VStack(alignment: .leading, spacing: MeetPRSpacing.xs) {
              Text(ChatStrings.includeVideo)
              Text(videoStatus(video.state))
                .font(.caption)
                .foregroundStyle(Color.MeetPR.textSecondary)
            }
          }
          .disabled(video.state == .failed)
        }

        if let errorMessage {
          Text(errorMessage)
            .font(.footnote)
            .foregroundStyle(Color.MeetPR.gold500)
        }

        Button(action: confirm) {
          Group {
            if isConfirming {
              ProgressView()
                .tint(Color.MeetPR.ctaText)
            } else {
              Text(ChatStrings.continueToChat)
            }
          }
          .font(.body.bold())
          .frame(maxWidth: .infinity)
          .frame(height: 48)
          .foregroundStyle(Color.MeetPR.ctaText)
          .background(Color.MeetPR.goldCTA)
          .clipShape(.rect(cornerRadius: MeetPRRadius.lg))
        }
        .buttonStyle(.plain)
        .disabled(isConfirming)
        .accessibilityIdentifier("chat.setRef.confirm")
      }
      .padding(MeetPRSpacing.base)
    }
  }

  private var firstLine: String {
    guard let setRef = try? SetRefV1.normalizingSource(candidate.source) else {
      return ChatStrings.invalidSetRecord
    }
    return ChatSetRefDisplayFormatter.firstLine(for: setRef)
  }

  private func videoStatus(_ state: SetRefShareVideo.State) -> String {
    switch state {
    case .uploading:
      ChatStrings.videoUploading
    case .ready:
      ChatStrings.videoReady
    case .failed:
      ChatStrings.videoFailed
    }
  }
}
