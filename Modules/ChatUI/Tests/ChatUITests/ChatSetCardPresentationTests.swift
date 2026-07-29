import CoreModels
import Foundation
import Testing

@testable import ChatUI

@Suite struct ChatSetCardPresentationTests {
  @Test func goldenFixturesProduceExactCardFieldsAndMissingShapes() throws {
    let fixture = try loadSetRefGoldenFixture()
    let validCases = try #require(fixture["valid"] as? [[String: Any]])

    for validCase in validCases {
      let name = try #require(validCase["name"] as? String)
      let setRefObject = try #require(validCase["set_ref"] as? [String: Any])
      let expectedFirstLine = try #require(validCase["first_line"] as? String)
      let setRef = try decodeSetRef(setRefObject)
      let message = makeMessage(setRef: setRef, body: expectedFirstLine)
      let presentation = try #require(
        ChatSetCardPresentation(message: message),
        "Expected a card for golden fixture: \(name)"
      )

      #expect(presentation.source == setRef.source)
      #expect(presentation.exerciseName == setRef.exerciseName)
      #expect(presentation.setNumber == setRef.setNumber)
      #expect(presentation.setTotal == setRef.setTotal)
      #expect(presentation.weight == setRef.weightKg ?? "-")
      let expectedReps =
        if let lowerBound = setRef.reps, let upperBound = setRef.repsMax {
          "\(lowerBound)-\(upperBound)"
        } else {
          setRef.reps.map(String.init) ?? "-"
        }
      #expect(presentation.reps == expectedReps)
      #expect(presentation.rpe == setRef.rpe)
      #expect(presentation.note == nil)
    }
  }

  @Test func notePreservesEveryCharacterAfterFirstNewline() throws {
    let setRef = try makeSetRef()
    let firstLine = SetRefCanonicalFormatter.firstLine(for: setRef)
    let note = "  膝盖底部有点晃  \n第二行\n"
    let presentation = try #require(
      ChatSetCardPresentation(
        message: makeMessage(setRef: setRef, body: "\(firstLine)\n\(note)")
      )
    )

    #expect(presentation.note == note)
  }

  @Test func missingNewlineHasNoNoteArea() throws {
    let setRef = try makeSetRef()
    let firstLine = SetRefCanonicalFormatter.firstLine(for: setRef)
    let presentation = try #require(
      ChatSetCardPresentation(message: makeMessage(setRef: setRef, body: firstLine))
    )

    #expect(presentation.note == nil)
  }

  @Test func explicitEmptyNoteIsPreservedAsEmptyString() throws {
    // nil = no newline; "" = explicitly empty remark. The model keeps them apart (plan-web
    // parity); only the view suppresses the empty remark area.
    let setRef = try makeSetRef()
    let firstLine = SetRefCanonicalFormatter.firstLine(for: setRef)
    let presentation = try #require(
      ChatSetCardPresentation(
        message: makeMessage(setRef: setRef, body: "\(firstLine)\n")
      )
    )

    #expect(presentation.note == "")
  }

  @Test func footerCopyReusesDeliveredAndReadStates() {
    #expect(
      ChatSetCardDeliveryPresentation.text(for: .delivered)
        == ChatStrings.setCardDelivered
    )
    #expect(
      ChatSetCardDeliveryPresentation.text(for: .read)
        == ChatStrings.setCardRead
    )
  }

  @Test func mismatchedBodyFallsBackToPlainText() throws {
    let setRef = try makeSetRef()

    #expect(
      ChatSetCardPresentation(
        message: makeMessage(setRef: setRef, body: "被篡改的首行\n备注")
      ) == nil
    )
    #expect(
      ChatSetCardPresentation(
        message: makeMessage(
          setRef: setRef,
          body: "\(SetRefCanonicalFormatter.firstLine(for: setRef))尾随内容"
        )
      ) == nil
    )
  }

  @Test func setNumberIsRenderedWithoutOffset() throws {
    let setRef = try SetRefV1(
      source: .logged,
      exerciseName: "深蹲",
      setNumber: 1,
      setTotal: 3,
      weightKg: "100",
      reps: 5,
      repsMax: nil,
      rpe: "8",
      dayDate: "2026-07-27",
      setLogId: testSetLogID,
      planSetId: nil
    )
    let presentation = try #require(
      ChatSetCardPresentation(
        message: makeMessage(
          setRef: setRef,
          body: SetRefCanonicalFormatter.firstLine(for: setRef)
        )
      )
    )

    #expect(presentation.setNumber == 1)
  }

  /// 拍板 3 froze the snapshot semantics carried by 「当前」, not the noun after it.
  /// A planned set has no record, and calling it one would undo the whole point of
  /// keeping performed and prescribed sets distinguishable.
  /// Asserts the branch, not the rendered text: `localized()` falls back to the raw
  /// key in the SPM test host, so string contents are unassertable here.
  @Test func confirmationCopyNeverCallsAPlannedSetARecord() {
    #expect(SetRefConfirmationCopy.prompt(for: .planned) == ChatStrings.sendCurrentSetPlan)
    #expect(SetRefConfirmationCopy.prompt(for: .logged) == ChatStrings.sendCurrentSetRecord)
    #expect(ChatStrings.sendCurrentSetPlan != ChatStrings.sendCurrentSetRecord)
  }
}

private let testSetLogID = UUID(
  uuid: (0x70, 0, 0, 0, 0, 0, 0x40, 0, 0x80, 0, 0, 0, 0, 0, 0, 1)
)

private func makeSetRef() throws -> SetRefV1 {
  try SetRefV1(
    source: .logged,
    exerciseName: "低杠位深蹲",
    setNumber: 3,
    setTotal: 5,
    weightKg: "100",
    reps: 5,
    repsMax: nil,
    rpe: "8.5",
    dayDate: "2026-07-27",
    setLogId: testSetLogID,
    planSetId: nil
  )
}

private func makeMessage(setRef: SetRefV1, body: String) -> ChatMessage {
  ChatMessage(
    id: UUID(),
    conversationID: UUID(),
    seq: 1,
    senderID: UUID(),
    kind: .text,
    text: body,
    attachmentID: nil,
    imageURL: nil,
    imageExpiresIn: nil,
    setRef: setRef,
    videoURL: URL(string: "https://example.test/video.mp4"),
    videoExpiresIn: 900,
    clientID: "set-card",
    createdAt: Date(timeIntervalSince1970: 1_700_000_000)
  )
}

private func loadSetRefGoldenFixture() throws -> [String: Any] {
  let repositoryRoot =
    URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
  let fixtureURL = repositoryRoot.appending(path: "set-ref-golden-fixtures.json")
  let data = try Data(contentsOf: fixtureURL)
  return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
}

private func decodeSetRef(_ object: [String: Any]) throws -> SetRefV1 {
  let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
  return try MeetPRCodec.decoder.decode(SetRefV1.self, from: data)
}
