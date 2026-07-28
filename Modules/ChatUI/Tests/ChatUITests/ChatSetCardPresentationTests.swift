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

      #expect(presentation.exerciseName == setRef.exerciseName)
      #expect(presentation.setNumber == setRef.setNumber)
      #expect(
        presentation.load
          == "\(setRef.weightKg.map { "\($0)kg" } ?? "-kg")×\(setRef.reps.map(String.init) ?? "-")"
      )
      #expect(presentation.rpe == setRef.rpe)
      #expect(presentation.dayDate == setRef.dayDate)
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

  @Test func ownCardUsesOutgoingBrandAndWhiteAppearance() {
    let appearance = ChatSetCardAppearance.resolve(isCurrentUser: true)

    #expect(appearance.background == .brandRed)
    #expect(appearance.primaryText == .white)
    #expect(appearance.secondaryText == .whiteMuted)
    #expect(appearance.accent == .white)
  }

  @Test func otherPartyCardUsesNeutralSurfaceAppearance() {
    let appearance = ChatSetCardAppearance.resolve(isCurrentUser: false)

    #expect(appearance.background == .surface1)
    #expect(appearance.primaryText == .fgPrimary)
    #expect(appearance.secondaryText == .fgTertiary)
    #expect(appearance.accent == .brandRed)
    #expect(appearance.border == .border)
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
      exerciseName: "深蹲",
      setNumber: 1,
      weightKg: "100",
      reps: 5,
      rpe: "8",
      dayDate: "2026-07-27",
      setLogId: testSetLogID
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
}

private let testSetLogID = UUID(
  uuid: (0x70, 0, 0, 0, 0, 0, 0x40, 0, 0x80, 0, 0, 0, 0, 0, 0, 1)
)

private func makeSetRef() throws -> SetRefV1 {
  try SetRefV1(
    exerciseName: "低杠位深蹲",
    setNumber: 3,
    weightKg: "100",
    reps: 5,
    rpe: "8.5",
    dayDate: "2026-07-27",
    setLogId: testSetLogID
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
