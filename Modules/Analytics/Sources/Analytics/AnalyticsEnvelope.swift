import Foundation

struct AnalyticsEnvelope: Codable, Equatable, Identifiable, Sendable {
  let eventID: UUID
  let sessionID: UUID
  let seq: Int
  let name: AnalyticsEvent
  let props: [String: AnalyticsValue]
  let schemaVersion: Int
  let timestamp: Date

  var id: UUID { eventID }

  enum CodingKeys: String, CodingKey {
    case eventID = "event_id"
    case sessionID = "session_id"
    case seq
    case name
    case props
    case schemaVersion = "schema_version"
    case timestamp = "ts_client"
  }
}

struct EventBatch: Encodable, Sendable {
  let anonID: UUID
  let appVersion: String
  let build: String
  let platform = "ios"
  let events: [AnalyticsEnvelope]

  enum CodingKeys: String, CodingKey {
    case anonID = "anon_id"
    case appVersion = "app_version"
    case build
    case platform
    case events
  }
}

struct FrictionFeedbackPayload: Codable, Equatable, Identifiable, Sendable {
  let eventID: UUID
  let anonID: UUID
  let sessionID: UUID
  let flow: AnalyticsFlow
  let fromScreen: AnalyticsScreen
  let trigger: FrictionTrigger
  let text: String
  let timestamp: Date

  var id: UUID { eventID }

  func withText(_ text: String) -> Self {
    Self(
      eventID: eventID,
      anonID: anonID,
      sessionID: sessionID,
      flow: flow,
      fromScreen: fromScreen,
      trigger: trigger,
      text: text,
      timestamp: timestamp)
  }

  enum CodingKeys: String, CodingKey {
    case eventID = "event_id"
    case anonID = "anon_id"
    case sessionID = "session_id"
    case flow
    case fromScreen = "from_screen"
    case trigger
    case text
    case timestamp = "ts_client"
  }
}

struct PersistedAnalyticsQueue: Codable, Equatable, Sendable {
  var events: [AnalyticsEnvelope] = []
  var feedback: [FrictionFeedbackPayload] = []
}

struct AnalyticsConfig: Decodable, Sendable {
  let enabled: Bool
  let sampleRate: Double

  enum CodingKeys: String, CodingKey {
    case enabled
    case sampleRate = "sample_rate"
  }
}
