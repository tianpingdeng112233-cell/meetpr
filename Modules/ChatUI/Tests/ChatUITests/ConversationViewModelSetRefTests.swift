import CoreModels
import Foundation
import Testing

@testable import ChatUI

@Suite @MainActor struct ConversationViewModelSetRefTests {
  @Test func pickerShowsSelectionWithMostRecentCandidatePrecheckedBeforeConfirmation() {
    let firstID = chatTestUUID(20)
    let secondID = chatTestUUID(21)
    let candidates = [
      Self.candidate(id: firstID),
      Self.candidate(id: secondID),
    ]
    var presentation = SetRefPickerPresentation()

    presentation.load(candidates: candidates, initialSetLogID: nil)

    #expect(presentation.page == .selection)
    #expect(presentation.selectedCandidateID == firstID)
  }

  @Test func pickerFlowRequiresContinueAfterChangingThePrecheckedSelection() {
    let firstID = chatTestUUID(20)
    let secondID = chatTestUUID(21)
    let candidates = [
      Self.candidate(id: firstID),
      Self.candidate(id: secondID),
    ]
    var presentation = SetRefPickerPresentation()

    presentation.load(candidates: candidates, initialSetLogID: nil)
    #expect(presentation.page == .selection)
    #expect(presentation.selectedCandidateID == firstID)

    presentation.select(secondID)
    #expect(presentation.page == .selection)
    #expect(presentation.selectedCandidateID == secondID)

    let didProceed = presentation.proceedToConfirmation()
    #expect(didProceed)
    #expect(presentation.page == .confirmation)
    #expect(presentation.selectedCandidate?.id == secondID)
  }

  @Test func explicitPreselectionStillOpensOnTheSelectionPage() {
    let firstID = chatTestUUID(20)
    let secondID = chatTestUUID(21)
    var presentation = SetRefPickerPresentation()

    presentation.load(
      candidates: [Self.candidate(id: firstID), Self.candidate(id: secondID)],
      initialSetLogID: secondID
    )

    #expect(presentation.page == .selection)
    #expect(presentation.selectedCandidateID == secondID)
  }

  @Test func pickerPartitionsLoggedBeforePlannedWithoutReorderingEitherSection() {
    let loggedOne = Self.candidate(id: chatTestUUID(20))
    let loggedTwo = Self.candidate(id: chatTestUUID(21))
    let plannedOne = Self.candidate(id: chatTestUUID(22), source: .planned)
    let plannedTwo = Self.candidate(id: chatTestUUID(23), source: .planned)
    var presentation = SetRefPickerPresentation()

    presentation.load(
      candidates: [loggedOne, loggedTwo, plannedOne, plannedTwo],
      initialSetLogID: nil
    )

    #expect(presentation.loggedCandidates.map(\.id) == [loggedOne.id, loggedTwo.id])
    #expect(presentation.plannedCandidates.map(\.id) == [plannedOne.id, plannedTwo.id])
  }

  @Test func canonicalBodyAtUTF16LimitSendsIncludingAnEmoji() async throws {
    let fixture = try makeStagedFixture()
    let firstLine = SetRefCanonicalFormatter.firstLine(for: fixture.intent.setRef)
    let noteCapacity =
      ConversationViewModel.maximumTextLength - firstLine.utf16.count - 1
    let note = String(repeating: "a", count: noteCapacity - 2) + "😀"

    let length = try #require(fixture.viewModel.stagedSetRefLength(note: note))
    #expect(length.bodyUTF16Count == ConversationViewModel.maximumTextLength)
    #expect(!length.isOverLimit)
    #expect(fixture.viewModel.sendStagedSetRef(note: note) == fixture.intent.clientID)
    let didSend = await chatEventually {
      await fixture.repository.setRefBodies.first?.utf16.count
        == ConversationViewModel.maximumTextLength
    }
    #expect(didSend)
    #expect(fixture.viewModel.setRefSendErrorMessage == nil)
  }

  @Test func canonicalBodyOverUTF16LimitShowsErrorAndKeepsStagedSnapshot() throws {
    let fixture = try makeStagedFixture()
    let firstLine = SetRefCanonicalFormatter.firstLine(for: fixture.intent.setRef)
    let noteCapacity =
      ConversationViewModel.maximumTextLength - firstLine.utf16.count - 1
    let note = String(repeating: "a", count: noteCapacity - 1) + "😀"

    let length = try #require(fixture.viewModel.stagedSetRefLength(note: note))
    #expect(length.bodyUTF16Count == ConversationViewModel.maximumTextLength + 1)
    #expect(length.isOverLimit)
    #expect(fixture.viewModel.sendStagedSetRef(note: note) == nil)
    #expect(fixture.viewModel.setRefSendErrorMessage == ChatStrings.messageTooLong)
    #expect(fixture.viewModel.stagedSetRef?.clientID == fixture.intent.clientID)
    #expect(fixture.coordinator.outbox(in: fixture.conversationID).isEmpty)
  }

  @Test func coordinatorRejectsOverLimitCanonicalBodyWithoutDiscardingStage() throws {
    let fixture = try makeStagedFixture()
    let firstLine = SetRefCanonicalFormatter.firstLine(for: fixture.intent.setRef)
    let noteCapacity =
      ConversationViewModel.maximumTextLength - firstLine.utf16.count - 1
    let note = String(repeating: "字", count: noteCapacity + 1)

    #expect(throws: SetRefSendError.messageTooLong) {
      try fixture.coordinator.sendStagedSetRef(
        in: fixture.conversationID,
        note: note
      )
    }
    #expect(
      fixture.coordinator.stagedSetRef(in: fixture.conversationID)?.clientID
        == fixture.intent.clientID
    )
  }

  private func makeStagedFixture() throws -> StagedSetRefFixture {
    let currentUserID = chatTestUUID(1)
    let conversationID = chatTestUUID(10)
    let repository = TestChatRepository()
    let coordinator = ChatSendCoordinator(
      repository: repository,
      currentUserID: currentUserID
    )
    let intent = try coordinator.makeSetRefIntent(
      in: conversationID,
      source: Self.setRefSource,
      note: nil
    )
    coordinator.stageSetRef(intent)
    let viewModel = ConversationViewModel(
      conversationID: conversationID,
      currentUserID: currentUserID,
      repository: repository,
      sendCoordinator: coordinator
    )
    return StagedSetRefFixture(
      conversationID: conversationID,
      repository: repository,
      coordinator: coordinator,
      viewModel: viewModel,
      intent: intent
    )
  }

  private static let setRefSource = SetRefSourceSnapshot(
    source: .logged,
    exerciseName: "低杠位深蹲",
    setNumber: 3,
    setTotal: 5,
    weightKg: "100.00",
    reps: 5,
    repsMax: nil,
    rpe: "8.0",
    dayDate: "2026-07-27",
    setLogId: chatTestUUID(20),
    planSetId: nil
  )

  private static func candidate(
    id: UUID,
    source: SetRefSource = .logged
  ) -> SetRefShareCandidate {
    SetRefShareCandidate(
      id: id,
      source: SetRefSourceSnapshot(
        source: source,
        exerciseName: "低杠位深蹲",
        setNumber: 3,
        setTotal: 5,
        weightKg: "100",
        reps: 5,
        repsMax: nil,
        rpe: "8",
        dayDate: "2026-07-28",
        setLogId: source == .logged ? id : nil,
        planSetId: source == .planned ? id : nil
      )
    )
  }
}

private struct StagedSetRefFixture {
  let conversationID: UUID
  let repository: TestChatRepository
  let coordinator: ChatSendCoordinator
  let viewModel: ConversationViewModel
  let intent: SetRefSendIntent
}
