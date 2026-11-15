import CoreModels
import Foundation
import SwiftUI
import Testing
import ViewInspector

@testable import ChatUI

@MainActor
@Test func exerciseNoteCardLabelsStudentMessageAndKeepsWireBody() throws {
  let reference = ExerciseRefV1(
    exerciseName: "暂停卧推", dayDate: "2026-11-10", planDayID: UUID(),
    planExerciseID: UUID(), exerciseID: UUID())
  let body = reference.body(note: "第二组感觉很重", english: false)
  #expect(body == "[动作留言] 暂停卧推 · 11/10\n第二组感觉很重")
  let message = ChatMessage(
    id: UUID(), conversationID: UUID(), seq: 1, senderID: UUID(), kind: .text,
    text: body, attachmentID: nil, imageURL: nil, imageExpiresIn: nil,
    exerciseRef: reference, clientID: "note", createdAt: .now)
  let card = try ExerciseNoteCard(message: message).inspect()
  #expect(try card.find(text: "11/10 · 暂停卧推 · 学员留言").string() == "11/10 · 暂停卧推 · 学员留言")
  #expect(try card.find(text: "第二组感觉很重").string() == "第二组感觉很重")
}

@MainActor
@Test func exerciseNoteCardUsesTheOfferedWidthForShortAndLongNotes() throws {
  let reference = ExerciseRefV1(
    exerciseName: "深蹲", dayDate: "2026-11-15", planDayID: UUID(),
    planExerciseID: UUID(), exerciseID: UUID())
  for note in ["完成", String(repeating: "最后一组想请教练看一下。", count: 8)] {
    let message = ChatMessage(
      id: UUID(), conversationID: UUID(), seq: 1, senderID: UUID(), kind: .text,
      text: reference.body(note: note, english: false), attachmentID: nil,
      imageURL: nil, imageExpiresIn: nil, exerciseRef: reference,
      clientID: "note", createdAt: .now)
    let renderer = ImageRenderer(content: ExerciseNoteCard(message: message))
    renderer.proposedSize = ProposedViewSize(width: 280, height: nil)
    #expect(try #require(renderer.cgImage).width == 280)
  }
}
