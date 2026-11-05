import CoreModels
import DesignSystem
import Foundation
import SwiftUI
import Testing
import ViewInspector

@testable import StudentKit

@Suite @MainActor struct VideoCompletionControlTests {
  @Test func waitingCardShowsGoldProgressAndApprovedCopy() throws {
    let date = Date()
    let video = VideoAttachment(
      id: UUID(), setLogID: UUID(), studentID: UUID(), status: .uploading,
      contentType: "video/mp4", durationSeconds: 1, sizeBytes: 1, recordedAt: date,
      trainingDate: date)
    let presentation = VideoCompletionPresentation(
      attachments: [video], trainingDate: date,
      allSetsDone: false, waiting: true)
    let control = VideoCompletionControl(presentation: presentation, onComplete: {})
    let inspected = try control.inspect()
    #expect(try inspected.find(ViewType.ProgressView.self).tint() == Color.MeetPR.goldCTA)
    #expect(
      try inspected.find(text: StudentStrings.localized(.videoCompletionBody)).string().isEmpty
        == false)
    #expect((try? inspected.find(text: StudentStrings.localized(.videoCompletionHint))) == nil)
  }

  /// Offline completion with no videos waits only for the network.
  @Test func waitingCardWithoutVideosSaysItWaitsForConnection() throws {
    let presentation = VideoCompletionPresentation(
      attachments: [], trainingDate: Date(), allSetsDone: true, waiting: true)
    let inspected = try VideoCompletionControl(presentation: presentation, onComplete: {})
      .inspect()
    #expect((try? inspected.find(ViewType.ProgressView.self)) == nil)
    #expect(
      (try? inspected.find(
        text: StudentStrings.localized(.workoutCompletionWaitingNetworkBody))) != nil)
    #expect((try? inspected.find(text: StudentStrings.localized(.videoCompletionBody))) == nil)
  }

  @Test func uploadingSummaryHasHintAndNoRetry() throws {
    let date = Date()
    let video = VideoAttachment(
      id: UUID(), setLogID: UUID(), studentID: UUID(), status: .uploading,
      contentType: "video/mp4", durationSeconds: 1, sizeBytes: 1, recordedAt: date,
      trainingDate: date)
    let presentation = VideoCompletionPresentation(
      attachments: [video], trainingDate: date,
      allSetsDone: true, waiting: false)
    let control = VideoCompletionControl(presentation: presentation, onComplete: {})
    let inspected = try control.inspect()
    #expect(
      try inspected.find(text: StudentStrings.localized(.videoCompletionHint)).string().isEmpty
        == false)
    #expect((try? inspected.find(text: StudentStrings.localized(.videoRetryNow))) == nil)
  }
}
