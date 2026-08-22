import CoreModels
import Foundation
import RepositoryContracts
import SwiftUI
import Testing
import ViewInspector

@testable import CoachKit

@Suite("Coach video feedback workbench presentation")
struct VideoFeedbackPresentationTests {
  @Test("zero-based set index displays as one-based")
  func zeroBasedSetIndexDisplaysAsOneBased() {
    let info = VideoSetInfo(log: setLog(setIndex: 0, rpe: 8))

    #expect(info.displaySetNumber == 1)
  }

  @Test("missing RPE stays absent instead of becoming zero")
  func missingRPEStaysAbsent() {
    let info = VideoSetInfo(log: setLog(setIndex: 2, rpe: nil))

    #expect(info.rpeText == nil)
    #expect(info.rpeText != "0")
  }

  @Test("RPE formats whole and half values without decimal noise")
  func rpeFormatsWholeAndHalfValues() {
    #expect(VideoSetInfo(log: setLog(setIndex: 0, rpe: 8)).rpeText == "8")
    #expect(VideoSetInfo(log: setLog(setIndex: 0, rpe: 8.5)).rpeText == "8.5")
  }

  @Test("pending video badge reuses resolved set data and display-ready ordinal")
  func pendingVideoBadgeUsesResolvedContext() {
    let info = VideoSetInfo(log: setLog(setIndex: 2, rpe: 8.5))
    let item = VideoInboxFixtures.item(exerciseName: "传统硬拉")

    let badge = CoachVideoBadgeResolver.pendingVideo(
      item,
      setInfo: info,
      coachName: "陈教练"
    )

    #expect(badge.exerciseName == "传统硬拉")
    #expect(badge.weightKg == info.weightKg)
    #expect(badge.reps == info.reps)
    #expect(badge.rpe == 8.5)
    #expect(badge.setOrdinal == 3)
    #expect(badge.coachName == "陈教练")
  }

  @MainActor
  @Test("missing RPE card renders the localized em dash")
  func missingRPECardRendersEmDash() throws {
    let info = VideoSetInfo(log: setLog(setIndex: 0, rpe: nil))
    let inspected = try VideoSetInfoCard(info: info).inspect()
    let renderedText = try inspected.findAll(ViewType.Text.self).map { try $0.string() }
    let catalog = try coachStringCatalog()
    let localizedDash =
      catalog.strings["coach.videoFeedback.missingValue"]?
      .localizations["zh-Hans"]?.stringUnit?.value

    #expect(localizedDash == "—")
    #expect(renderedText.contains(CoachVideoFeedbackStrings.missingValue))
    #expect(!renderedText.contains("0"))
  }

  private func coachStringCatalog() throws -> TestStringCatalog {
    let packageRoot = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let catalogURL = packageRoot.appending(
      path: "Sources/CoachKit/Resources/Localizable.xcstrings"
    )
    return try JSONDecoder().decode(
      TestStringCatalog.self,
      from: Data(contentsOf: catalogURL)
    )
  }

  @Test("unlinked video resolves no set-info card")
  func unlinkedVideoResolvesNoSetInfo() {
    let log = setLog(setIndex: 1, rpe: 8.5)

    #expect(VideoSetInfo.resolve(setLogID: nil, from: [log]) == nil)
  }

  @Test("global queue advances across students and wraps after its final item")
  func globalQueueAdvancesAndWraps() throws {
    let first = VideoInboxFixtures.item(studentID: UUID())
    let second = VideoInboxFixtures.item(
      studentID: UUID(),
      uploadedAt: VideoInboxFixtures.base.addingTimeInterval(-60)
    )
    let items = [first, second]

    let position = try #require(
      VideoFeedbackQueueNavigator.position(of: first.id, in: items)
    )
    #expect(position.displayIndex == 1)
    #expect(position.total == 2)
    #expect(
      VideoFeedbackQueueNavigator.nextItem(after: first.id, in: items)?.id
        == second.id
    )
    #expect(
      VideoFeedbackQueueNavigator.nextItem(after: second.id, in: items)?.id
        == first.id
    )
  }

  @Test("empty queue has no position or post-send next item")
  func emptyQueueHasNoPositionOrNextItem() {
    #expect(VideoFeedbackQueueNavigator.position(of: UUID(), in: []) == nil)
    #expect(VideoFeedbackQueueNavigator.itemAfterSend(preferring: nil, in: []) == nil)
  }

  @Test("post-send navigation resolves from the latest remaining queue")
  func postSendNavigationUsesLatestQueue() {
    let sent = VideoInboxFixtures.item()
    let successor = VideoInboxFixtures.item()
    let prepended = VideoInboxFixtures.item()

    // 发送 A 时队列是 [A, B],期间刷新前插 X 变成 [X, A, B];A 被移除后是 [X, B]。
    // 旧实现拿 A 的旧索引 0 去套,会跳到 X;按身份找 B 才是对的。
    #expect(
      VideoFeedbackQueueNavigator.itemAfterSend(
        preferring: successor.id,
        in: [prepended, successor]
      )?.id == successor.id
    )

    // 后继也被别的设备答掉了 → 落到剩余队列的第一段,与回卷语义一致。
    #expect(
      VideoFeedbackQueueNavigator.itemAfterSend(
        preferring: successor.id,
        in: [prepended]
      )?.id == prepended.id
    )

    // 队列空 → 无处可去,由调用方关闭。
    #expect(
      VideoFeedbackQueueNavigator.itemAfterSend(
        preferring: successor.id,
        in: []
      ) == nil
    )

    _ = sent
  }

  @MainActor
  @Test("empty student list stays alive while the global workbench advances")
  func emptyStudentListStaysAliveWhileWorkbenchIsPresented() {
    #expect(
      !StudentPendingVideosView.shouldDismissStudentList(
        isEmpty: true,
        isDetailPresented: true
      )
    )
    #expect(
      StudentPendingVideosView.shouldDismissStudentList(
        isEmpty: true,
        isDetailPresented: false
      )
    )
  }

  private func setLog(setIndex: Int, rpe: Decimal?) -> StudentSetLog {
    StudentSetLog(
      id: UUID(),
      studentID: UUID(),
      planExerciseID: UUID(),
      setIndex: setIndex,
      loggedAt: VideoInboxFixtures.base,
      weightKg: 182.5,
      reps: 3,
      rpe: rpe,
      completed: true
    )
  }
}

private struct TestStringCatalog: Decodable {
  let strings: [String: Entry]

  struct Entry: Decodable {
    let localizations: [String: Localization]
  }

  struct Localization: Decodable {
    let stringUnit: StringUnit?
  }

  struct StringUnit: Decodable {
    let value: String
  }
}
