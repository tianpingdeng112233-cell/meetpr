import CoreModels
import Networking
import SwiftUI
import Testing
import ViewInspector

@testable import StudentKit

@MainActor
@Suite("Invite code paste button")
struct InviteCodeEntryTests {
  @Test("Global retains the shipped paste button and action")
  func globalRetainsPasteButton() throws {
    var didPaste = false
    let view = InviteCodeEntry(
      code: .constant(""),
      errorMessage: nil,
      pasteError: nil,
      onPaste: { didPaste = true },
      buildTrack: .global
    )

    let button = try view.inspect().find(ViewType.Button.self)
    #expect(
      try button.labelView().find(ViewType.Text.self).string()
        == StudentStrings.localized(.inviteCodeEntry005)
    )
    #expect(
      try button.labelView().find(ViewType.Image.self).actualImage().name() == "doc.on.clipboard")
    #expect(
      try button.accessibilityHint().string()
        == StudentStrings.replacing(.inviteCodeEntry006, values: ["\(InviteCodeFormat.length)"])
    )
    try button.tap()
    #expect(didPaste)
  }

  @Test("CN retains its invitation paste label and action")
  func chinaRetainsPasteButton() throws {
    var didPaste = false
    let view = InviteCodeEntry(
      code: .constant(""),
      errorMessage: nil,
      pasteError: nil,
      onPaste: { didPaste = true },
      buildTrack: .china
    )

    let button = try view.inspect().find(ViewType.Button.self)
    #expect(
      try button.labelView().find(ViewType.Text.self).string()
        == String(localized: "student.inviteCode.paste", bundle: .module)
    )
    try button.tap()
    #expect(didPaste)
  }
}
