import Foundation

public enum PushNotificationKind: String, CaseIterable, Sendable {
  case chatMessage = "chat_message"
  case missedTraining = "missed_training"
  case prCongrats = "pr_congrats"
  case videoPending = "video_pending"
  case bindRequest = "bind_request"
  case planShift = "plan_shift"
  case planShifted = "plan_shifted"
  case planShiftUndone = "plan_shift_undone"
  case planUpdated = "plan_updated"
  case planPublished = "plan_published"
}

public enum PushRouteIntent: Equatable, Sendable {
  case chatMessage(conversationID: UUID)
  case missedTraining(studentID: UUID)
  case prCongrats(studentID: UUID)
  case videoPending(studentID: UUID, videoID: UUID)
  case bindRequest(requestID: UUID)
  case planShift(studentID: UUID, planID: UUID)
  case planShifted(studentID: UUID, planID: UUID)
  case planShiftUndone(studentID: UUID, planID: UUID)
  case planUpdated(studentID: UUID, planID: UUID)
  case planPublished(studentID: UUID, planID: UUID)
}

public struct PushPayloadValues: Equatable, Sendable {
  public let kind: String?
  public let conversationID: String?
  public let studentID: String?
  public let videoID: String?
  public let requestID: String?
  public let planID: String?

  public init(
    kind: String?,
    conversationID: String? = nil,
    studentID: String? = nil,
    videoID: String? = nil,
    requestID: String? = nil,
    planID: String? = nil
  ) {
    self.kind = kind
    self.conversationID = conversationID
    self.studentID = studentID
    self.videoID = videoID
    self.requestID = requestID
    self.planID = planID
  }
}

public enum PushPayloadParser {
  public static func route(from payload: PushPayloadValues) -> PushRouteIntent? {
    guard let rawKind = payload.kind, let kind = PushNotificationKind(rawValue: rawKind) else {
      return nil
    }

    switch kind {
    case .chatMessage:
      return chatRoute(from: payload)
    case .missedTraining:
      return studentRoute(from: payload, kind: .missedTraining)
    case .prCongrats:
      return studentRoute(from: payload, kind: .prCongrats)
    case .videoPending:
      return videoRoute(from: payload)
    case .bindRequest:
      return bindRoute(from: payload)
    case .planShift:
      return planRoute(from: payload, kind: kind)
    case .planShifted, .planShiftUndone, .planUpdated, .planPublished:
      return planRoute(from: payload, kind: kind)
    }
  }

  private static func chatRoute(from payload: PushPayloadValues) -> PushRouteIntent? {
    uuid(payload.conversationID).map(PushRouteIntent.chatMessage(conversationID:))
  }

  private static func studentRoute(
    from payload: PushPayloadValues,
    kind: PushNotificationKind
  ) -> PushRouteIntent? {
    guard let studentID = uuid(payload.studentID) else { return nil }
    switch kind {
    case .missedTraining:
      return .missedTraining(studentID: studentID)
    case .prCongrats:
      return .prCongrats(studentID: studentID)
    case .chatMessage, .videoPending, .bindRequest, .planShift, .planShifted,
      .planShiftUndone, .planUpdated, .planPublished:
      return nil
    }
  }

  private static func videoRoute(from payload: PushPayloadValues) -> PushRouteIntent? {
    guard let studentID = uuid(payload.studentID), let videoID = uuid(payload.videoID) else {
      return nil
    }
    return .videoPending(studentID: studentID, videoID: videoID)
  }

  private static func bindRoute(from payload: PushPayloadValues) -> PushRouteIntent? {
    uuid(payload.requestID).map(PushRouteIntent.bindRequest(requestID:))
  }

  private static func planRoute(
    from payload: PushPayloadValues,
    kind: PushNotificationKind
  ) -> PushRouteIntent? {
    guard let studentID = uuid(payload.studentID), let planID = uuid(payload.planID) else {
      return nil
    }
    switch kind {
    case .planShift:
      return .planShift(studentID: studentID, planID: planID)
    case .planShifted:
      return .planShifted(studentID: studentID, planID: planID)
    case .planShiftUndone:
      return .planShiftUndone(studentID: studentID, planID: planID)
    case .planUpdated:
      return .planUpdated(studentID: studentID, planID: planID)
    case .planPublished:
      return .planPublished(studentID: studentID, planID: planID)
    case .chatMessage, .missedTraining, .prCongrats, .videoPending, .bindRequest:
      return nil
    }
  }

  private static func uuid(_ value: String?) -> UUID? {
    value.flatMap(UUID.init(uuidString:))
  }
}

public enum PushForegroundPresentation: Equatable, Sendable {
  case suppress
  case bannerAndSound

  public static func policy(for rawKind: String?) -> Self {
    rawKind == PushNotificationKind.chatMessage.rawValue ? .suppress : .bannerAndSound
  }
}
