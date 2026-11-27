#if DEMO_MODE && DEMO_USER_STUDENT
  import ChatUI
  import CoreModels
  import Foundation
  import StudentKit

  struct DemoShowcaseConversation {
    let chat: ChatDemoSeed
    let feedback: [CoachFeedback]
    let markers: [VideoMarker]
    let videos: [StudentVideo]

    private static let comments = [
      "这组深度够了。下次起身前先把膝盖往外顶。",
      "停胸比上周稳，下一练照原重量做满。",
      "杠贴胫骨起拉，这组背的位置保持得很好。",
      "这周主动收量，拉完还有余力就对了。",
      "脚跟压得很实。推到一半别急着把肩送出去。",
      "深蹲三次都站稳了，比上周多了两公斤半。先把这个重量练熟。",
      "最后一组杠速也不错，明天卧推按计划走。",
    ]
    private static let cues = [
      2: ["起拉前先把杠铃的间隙拉紧", "过膝后站直就够了"],
      4: ["杠铃落在胸骨下段", "推起时脚跟继续踩住"],
      6: ["下蹲时膝盖往外顶", "从底部起来时胸口别先掉"],
    ]

    init(scene: DemoShowcase) {
      let reviewDays = [0, 5, 10, 14, 17, 20, 24]
      let logs = Dictionary(grouping: scene.logs, by: \.planExerciseID)
      var videos: [StudentVideo] = []
      var feedback: [CoachFeedback] = []
      var markers: [VideoMarker] = []
      for (index, dayIndex) in reviewDays.enumerated() {
        let day = scene.plan.days[dayIndex]
        let exercise = day.exercises[0]
        guard let log = logs[exercise.id]?.first else { continue }
        let videoID = DemoShowcase.id(70_000 + index)
        videos.append(
          StudentVideo(
            id: videoID, setLogID: log.id, planExerciseID: exercise.id,
            contentType: "video/mp4", sizeBytes: 1, filename: "训练记录.mp4",
            createdAt: log.loggedAt, loggedAt: log.loggedAt))
        let posted =
          dayIndex == reviewDays.last
          ? DemoShowcase.day(-1, from: scene.today).addingTimeInterval(40_500)
          : log.loggedAt.addingTimeInterval(5400)
        var detail: CoachFeedbackVideo?
        if let cues = Self.cues[index] {
          detail = CoachFeedbackVideo(
            id: videoID, exerciseName: exercise.exercise.name, setIndex: log.setIndex,
            weightKg: log.weightKg.map { NSDecimalNumber(decimal: $0).stringValue },
            reps: log.reps, rpe: log.rpe.map { NSDecimalNumber(decimal: $0).stringValue },
            loggedAt: log.loggedAt)
          for (offset, note) in cues.enumerated() {
            markers.append(
              VideoMarker(
                id: DemoShowcase.id(71_000 + index * 10 + offset), videoID: videoID,
                coachID: DemoShowcase.coachID, timeMilliseconds: (offset + 1) * 3000,
                level: offset == 0 ? .warn : .info, note: note, createdAt: posted))
          }
        }
        feedback.append(
          CoachFeedback(
            id: DemoShowcase.id(72_000 + index), coachID: DemoShowcase.coachID,
            studentID: DemoShowcase.studentID, dayDate: day.date, planExerciseID: exercise.id,
            videoID: detail?.id, video: detail, text: Self.comments[index], postedAt: posted,
            readAt: posted))
      }
      self.videos = videos
      self.feedback = feedback
      self.markers = markers
      self.chat = Self.messages(scene: scene, sharedVideo: videos.last)
    }

    private struct Entry {
      let date: Date
      let sender: UUID
      var text: String?
      var image: URL?
      var reference: ExerciseRefV1?
      var video: StudentVideo?
    }

    private static func messages(scene: DemoShowcase, sharedVideo: StudentVideo?) -> ChatDemoSeed {
      let coach = DemoShowcase.coachID
      let student = DemoShowcase.studentID
      let conversationID = DemoShowcase.id(6)
      var entries = (1...7).map { week in
        Entry(
          date: scene.plan.days[(week - 1) * 4].date.addingTimeInterval(-3600),
          sender: coach, text: "W\(week) 计划已发布")
      }
      for (dayIndex, note) in [(8, "这一组膝盖没有不舒服。"), (21, "今天卧推最后一下有点慢。")] {
        let day = scene.plan.days[dayIndex]
        let row = day.exercises[0]
        let reference = ExerciseRefV1(
          exerciseName: row.exercise.name,
          dayDate: day.date.formatted(Date.ISO8601FormatStyle(timeZone: .gmt).year().month().day()),
          planDayID: day.id, planExerciseID: row.id, exerciseID: row.exercise.id)
        entries.append(
          Entry(
            date: day.date.addingTimeInterval(70_000), sender: student,
            text: reference.body(note: note, english: false), reference: reference))
      }
      let yesterday = DemoShowcase.day(-1, from: scene.today)
      entries += [
        Entry(
          date: scene.plan.days[8].date.addingTimeInterval(71_000), sender: coach,
          text: "好，先保持这个站距。"),
        Entry(
          date: scene.plan.days[21].date.addingTimeInterval(71_000), sender: coach,
          text: "下回组间多歇一分钟再上。"),
        Entry(date: yesterday.addingTimeInterval(38_000), sender: student, text: "周教练，昨天第一组你再看看？"),
        Entry(
          date: yesterday.addingTimeInterval(38_060), sender: student, text: "[视频]",
          video: sharedVideo),
        Entry(date: yesterday.addingTimeInterval(39_000), sender: coach, text: "看到了，第一下起身比之前稳。"),
        Entry(
          date: yesterday.addingTimeInterval(39_060), sender: coach, text: "明天在这个训练应用里记一下组间休息。"),
        Entry(
          date: yesterday.addingTimeInterval(39_120), sender: coach,
          image: Bundle.main.url(forResource: "AppIcon60x60@2x", withExtension: "png")),
        Entry(date: yesterday.addingTimeInterval(40_000), sender: student, text: "收到，我带上护腕。"),
        Entry(date: yesterday.addingTimeInterval(41_000), sender: coach, text: "卧推第一组先找停顿，不着急加重。"),
      ]
      return chatSeed(entries: entries, conversationID: conversationID, scene: scene)
    }

    private static func chatSeed(entries: [Entry], conversationID: UUID, scene: DemoShowcase)
      -> ChatDemoSeed
    {
      let coach = DemoShowcase.coachID
      let messages = entries.sorted { $0.date < $1.date }.enumerated().map { index, entry in
        let id = DemoShowcase.id(73_000 + index)
        return ChatMessage(
          id: id, conversationID: conversationID, seq: index + 1, senderID: entry.sender,
          kind: entry.image == nil ? .text : .image, text: entry.text,
          attachmentID: entry.image == nil ? nil : id, imageURL: entry.image, imageExpiresIn: nil,
          exerciseRef: entry.reference, videoID: entry.video?.id,
          videoURL: entry.video == nil ? nil : scene.videoURL,
          clientID: id.uuidString, createdAt: entry.date)
      }
      let lastRead = messages[messages.count - 2]
      return ChatDemoSeed(
        conversations: [
          ChatConversation(
            id: conversationID, otherPartyID: coach, otherPartyName: DemoShowcase.coachName,
            lastMessagePreview: messages.last?.text, lastMessageAt: messages.last?.createdAt,
            unreadCount: 1, myLastRead: .init(messageID: lastRead.id, seq: lastRead.seq),
            otherLastRead: .init(messageID: lastRead.id, seq: lastRead.seq))
        ],
        messagesByConversationID: [conversationID: messages],
        otherPartyNames: [coach: DemoShowcase.coachName])
    }
  }

  struct DemoShowcaseReplay: StudentReplayVideoRepository {
    let videos: [StudentVideo]
    let url: URL?

    func fetchVideos(studentID: UUID) async throws -> [StudentVideo] {
      studentID == DemoShowcase.studentID ? videos : []
    }

    func playbackURL(videoID: UUID) async throws -> URL {
      guard videos.contains(where: { $0.id == videoID }), let url else {
        throw URLError(.fileDoesNotExist)
      }
      return url
    }
  }
#endif
