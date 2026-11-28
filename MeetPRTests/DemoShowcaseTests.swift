#if DEMO_MODE && DEMO_USER_STUDENT
  import CoreModels
  import Foundation
  import Testing

  @testable import MeetPR

  struct DemoShowcaseTests {
    // Sunday near the spring DST change. The cursor must follow the supplied day.
    let today = Date(timeIntervalSince1970: 1_774_785_600)

    @Test func twelveWeeksOpenAtWeekSevenDayTwo() throws {
      let scene = DemoShowcase(today: today)
      let weeks = Dictionary(grouping: scene.plan.days, by: \.weekNumber)
      #expect(weeks.count == 12)
      #expect(weeks.values.allSatisfy { $0.count == 4 })
      let cursor = try #require(StudentPlanSequence.cursorDay(in: scene.plan))
      #expect(cursor.weekNumber == 7)
      #expect(weeks[7]?[1].id == cursor.id)
      #expect(cursor.date == DemoShowcase.planDate(today))
      #expect(cursor.exercises.count == 5)
      #expect(cursor.exercises.first?.notes != nil)
      #expect(scene.plan.days.filter { $0.completedAt != nil }.count == 25)
      let logs = Dictionary(grouping: scene.logs, by: \.planExerciseID)
      for day in scene.plan.days {
        for exercise in day.exercises {
          let actual = logs[exercise.id, default: []].map(\.setIndex).sorted()
          #expect(actual == (day.completedAt == nil ? [] : exercise.prescribedSets.map(\.setIndex)))
        }
      }
    }

    @Test func threeLiftsGrowFromImportedHistoryAndLoggedSets() throws {
      let scene = DemoShowcase(today: today)
      let beforeQuarter = DemoShowcase.day(-90, from: today)
      let beforeMonth = DemoShowcase.day(-30, from: today)
      let logs = Dictionary(uniqueKeysWithValues: scene.logs.map { ($0.id, $0) })
      for family in [LiftFamily.squat, .bench, .deadlift] {
        let series = scene.points.filter { $0.family == family }.sorted {
          $0.computedAt < $1.computedAt
        }
        let prior = try #require(series.last(where: { $0.computedAt <= beforeQuarter }))
        let latest = try #require(series.last)
        #expect(prior.origin == .imported)
        #expect(latest.computedAt.timeIntervalSince(prior.computedAt) >= 90 * 86_400)
        #expect(latest.e1RMKg > prior.e1RMKg)
        let recent = series.filter { $0.computedAt >= beforeMonth }
        #expect(Set(recent.map { Calendar.current.startOfDay(for: $0.computedAt) }).count >= 3)
        for point in recent {
          let log = try #require(logs[point.setLogId])
          let kilograms = try #require(log.weightKg)
          let rpe = try #require(log.rpe)
          #expect(
            point.e1RMKg
              == E1RMCalculator.calculate(
                weightKg: NSDecimalNumber(decimal: kilograms).doubleValue, reps: log.reps,
                rpe: NSDecimalNumber(decimal: rpe).doubleValue))
        }
      }
      let record = try #require(scene.records.first)
      #expect(record.family == .squat)
      #expect(
        scene.plan.days.contains { day in
          day.weekNumber == 6 && day.date == DemoShowcase.planDate(record.occurredAt)
        })
    }

    @Test func sevenTrainingWeeksIncludeALighterWeekAndTwiceWeeklyWeighIns() throws {
      let scene = DemoShowcase(today: today)
      let calendar = Calendar.current
      let weeks = Dictionary(grouping: scene.logs) {
        calendar.dateInterval(of: .weekOfYear, for: $0.loggedAt)?.start
      }
      #expect(weeks.count >= 7)
      #expect(weeks.values.allSatisfy { logs in logs.contains { $0.rpe != nil } })
      func volume(_ week: Int) -> Decimal {
        let rows = Set(
          scene.plan.days.filter { $0.weekNumber == week }.flatMap(\.exercises).map(\.id))
        return scene.logs.filter { rows.contains($0.planExerciseID) }.reduce(0) {
          $0 + ($1.weightKg ?? 0) * Decimal($1.reps)
        }
      }
      #expect(volume(4) < volume(3) * 0.7)
      let weights = scene.bodyWeights
      #expect((20...30).contains(weights.count))
      #expect(weights.values.allSatisfy { (82.4...84.2).contains($0) })
      #expect(weights[DemoShowcase.dayString(today)] == 83)
      let chronological = weights.sorted { $0.key < $1.key }
      let earliest = try #require(chronological.first)
      let latest = try #require(chronological.last)
      #expect(earliest.key <= DemoShowcase.dayString(DemoShowcase.day(-84, from: today)))
      #expect(earliest.value > latest.value)
      for (previous, next) in zip(chronological, chronological.dropFirst()) {
        #expect(abs(next.value - previous.value) <= 0.2)
      }
    }

    @Test func conversationLinksFeedbackMarkersAndReplays() async throws {
      let url = URL(filePath: "/tmp/训练.mp4")
      let scene = DemoShowcase(today: today, videoURL: url)
      let thread = DemoShowcaseConversation(scene: scene)
      #expect((6...8).contains(thread.feedback.count))
      #expect(thread.feedback.filter { $0.video != nil }.count == 3)
      #expect((6...8).contains(thread.videos.count))
      let replay = DemoShowcaseReplay(videos: thread.videos, url: scene.videoURL)
      for feedback in thread.feedback {
        guard let video = feedback.video else { continue }
        #expect((2...3).contains(thread.markers.filter { $0.videoID == video.id }.count))
        let item = try #require(thread.videos.first { $0.id == video.id })
        #expect(
          scene.logs.contains {
            $0.id == item.setLogID && $0.planExerciseID == feedback.planExerciseID
          })
        #expect(try await replay.playbackURL(videoID: video.id) == url)
      }
      let chat = try #require(thread.chat.conversations.first)
      let messages = try #require(thread.chat.messagesByConversationID[chat.id])
      #expect(chat.otherPartyName == "周砚")
      #expect((1...2).contains(chat.unreadCount))
      #expect(messages.filter { $0.exerciseRef != nil }.count == 2)
      #expect(messages.contains { $0.isStandaloneVideo && $0.videoURL == url })
      #expect(messages.contains { $0.kind == .image && $0.imageURL?.isFileURL == true })
      for week in 1...7 {
        #expect(messages.contains { $0.text == "W\(week) 计划已发布" })
      }
    }

    @Test func visibleTextAndIdentitiesBelongToTheFictionalStudent() throws {
      let scene = DemoShowcase(today: today)
      let thread = DemoShowcaseConversation(scene: scene)
      #expect(scene.user.name == "陈屿")
      #expect(scene.binding.coachDisplayName == "周砚")
      #expect(
        scene.profile.competitionDate == DemoShowcase.dayString(DemoShowcase.day(38, from: today)))
      func check<T: Encodable>(_ value: T) throws {
        let text = try #require(String(data: try JSONEncoder().encode(value), encoding: .utf8))
        #expect(!text.contains("演示"))
        #expect(!text.localizedCaseInsensitiveContains("Demo"))
      }
      try check(scene.user)
      try check(scene.profile)
      try check(scene.binding)
      try check(scene.plan)
      try check(thread.feedback)
      try check(thread.markers)
      try check(thread.videos)
      try check(thread.chat.conversations)
      // Media URLs are local resource paths. Check every displayed message field independently.
      for message in thread.chat.messagesByConversationID.values.joined() {
        try check(message.text)
        try check(message.exerciseRef)
        try check(message.setRef)
      }
    }

    @Test func launchRequiresOptInAndKeepsMediaLocal() throws {
      #expect(DemoShowcase.launch(arguments: []) == nil)
      #expect(DemoShowcase.launch(arguments: ["-demo-showcase-video", "/tmp/x.mp4"]) == nil)
      let fallback = try #require(DemoShowcase.launch(arguments: ["-demo-showcase"]))
      #expect(fallback.videoURL?.lastPathComponent == "coach-demo-video.mp4")
      let override = try #require(
        DemoShowcase.launch(arguments: ["-demo-showcase", "-demo-showcase-video", "/tmp/x.mp4"]))
      #expect(override.videoURL == URL(filePath: "/tmp/x.mp4"))
      let repeatScene = DemoShowcase(today: fallback.today)
      #expect(repeatScene.plan == fallback.plan)
      #expect(repeatScene.logs == fallback.logs)
      #expect(repeatScene.points == fallback.points)
    }
  }
#endif
