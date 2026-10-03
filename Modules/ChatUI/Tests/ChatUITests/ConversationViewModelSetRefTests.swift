import CoreModels
import Foundation
import Testing

@testable import ChatUI

@Suite @MainActor struct ConversationViewModelSetRefTests {
  @Test func pickerRequiresASelectionUnlessTheEntryProvidesOne() {
    let firstID = chatTestUUID(20)
    let secondID = chatTestUUID(21)
    let candidates = [Self.candidate(id: firstID), Self.candidate(id: secondID)]
    var presentation = SetRefPickerPresentation()

    presentation.load(candidates: candidates, initialSetLogID: nil)
    #expect(presentation.selectedCandidateID == nil)
    presentation.select(secondID)
    #expect(presentation.selectedCandidateID == secondID)
    presentation.select(firstID)
    #expect(presentation.selectedCandidate?.id == firstID)
    presentation.select(chatTestUUID(99))
    #expect(presentation.selectedCandidateID == firstID)

    presentation.load(candidates: candidates, initialSetLogID: secondID)
    #expect(presentation.selectedCandidateID == secondID)
    presentation.load(candidates: candidates, initialSetLogID: chatTestUUID(99))
    #expect(presentation.selectedCandidateID == nil)
  }

  @Test func pickerGroupsSetsByExerciseAndShowsTheSelectedSummary() throws {
    let squatID = chatTestUUID(30)
    let pressID = chatTestUUID(31)
    let first = Self.candidate(id: chatTestUUID(20))
    let second = Self.candidate(id: chatTestUUID(21), source: .planned)
    var presentation = SetRefPickerPresentation()
    presentation.load(
      candidates: [
        SetRefShareCandidate(
          id: second.id, source: second.source,
          exerciseID: squatID, exerciseOrder: 0, weekCode: "W2D3"),
        SetRefShareCandidate(
          id: first.id, source: first.source,
          exerciseID: squatID, exerciseOrder: 0, weekCode: "W2D3"),
        SetRefShareCandidate(
          id: chatTestUUID(22), source: first.source,
          exerciseID: pressID, exerciseOrder: 1, weekCode: "W2D3"),
      ], initialSetLogID: nil)

    #expect(presentation.groups.count == 2)
    #expect(presentation.groups.first?.weekCode == "W2D3")
    #expect(presentation.groups.first?.candidates.count == 2)
    #expect(presentation.gridColumnCount == 3)
    #expect(!presentation.canSend)
    #expect(presentation.sendSummary == nil)
    presentation.select(first.id)
    #expect(presentation.canSend)
    #expect(
      presentation.sendSummary
        == ChatStrings.setRefSendSummary(
          setNumber: 3, exerciseName: "低杠位深蹲"))
    let cell = try #require(presentation.cell(for: first))
    #expect(cell.setLabel == ChatStrings.setPosition(3))
    #expect(cell.load == "100kg × 5")
    #expect(cell.status == ChatStrings.setRefLogged + " · RPE 8")
    #expect(presentation.cell(for: second)?.status == ChatStrings.setRefPlanned)
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
