import Foundation

public struct ChatMessage: Codable, Identifiable, Hashable, Sendable {
  public let id: UUID
  public let conversationID: UUID
  public let seq: Int
  public let senderID: UUID
  public let kind: ChatMessageKind
  public let text: String?
  public let attachmentID: UUID?
  public let imageURL: URL?
  public let imageExpiresIn: Int?
  public let setRef: SetRefV1?
  public let videoURL: URL?
  public let videoExpiresIn: Int?
  public let clientID: String
  public let createdAt: Date

  public init(
    id: UUID,
    conversationID: UUID,
    seq: Int,
    senderID: UUID,
    kind: ChatMessageKind,
    text: String?,
    attachmentID: UUID?,
    imageURL: URL?,
    imageExpiresIn: Int?,
    setRef: SetRefV1? = nil,
    videoURL: URL? = nil,
    videoExpiresIn: Int? = nil,
    clientID: String,
    createdAt: Date
  ) {
    self.id = id
    self.conversationID = conversationID
    self.seq = seq
    self.senderID = senderID
    self.kind = kind
    self.text = text
    self.attachmentID = attachmentID
    self.imageURL = imageURL
    self.imageExpiresIn = imageExpiresIn
    self.setRef = setRef
    self.videoURL = videoURL
    self.videoExpiresIn = videoExpiresIn
    self.clientID = clientID
    self.createdAt = createdAt
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(UUID.self, forKey: .id)
    conversationID = try container.decode(UUID.self, forKey: .conversationID)
    seq = try container.decode(Int.self, forKey: .seq)
    senderID = try container.decode(UUID.self, forKey: .senderID)
    kind = try container.decode(ChatMessageKind.self, forKey: .kind)
    text = try container.decodeIfPresent(String.self, forKey: .text)
    attachmentID = try container.decodeIfPresent(UUID.self, forKey: .attachmentID)
    imageURL = try container.decodeIfPresent(URL.self, forKey: .imageURL)
    imageExpiresIn = try container.decodeIfPresent(Int.self, forKey: .imageExpiresIn)
    setRef = try? container.decode(SetRefV1ReadValue.self, forKey: .setRef).value
    videoURL = try container.decodeIfPresent(URL.self, forKey: .videoURL)
    videoExpiresIn = try container.decodeIfPresent(Int.self, forKey: .videoExpiresIn)
    clientID = try container.decode(String.self, forKey: .clientID)
    createdAt = try container.decode(Date.self, forKey: .createdAt)
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case conversationID = "conversationId"
    case seq
    case senderID = "senderId"
    case kind
    case text
    case attachmentID = "attachmentId"
    case imageURL = "imageUrl"
    case imageExpiresIn
    case setRef
    case videoURL = "videoUrl"
    case videoExpiresIn
    case clientID = "clientId"
    case createdAt
  }
}

/// Tolerant read-only decoder for a v1 set-reference wire value.
///
/// `SetRefV1` remains strict when decoded directly for write-side validation.
/// This wrapper ignores unknown keys, then constructs the same validated domain
/// value so additive v1 server fields do not hide an otherwise valid card.
public struct SetRefV1ReadValue: Decodable, Sendable {
  public let value: SetRefV1

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    for key in CodingKeys.allCases where !container.contains(key) {
      throw SetRefValidationError.missingField(key.stringValue)
    }
    value = try SetRefV1(
      version: container.decode(Int.self, forKey: .version),
      source: container.decode(SetRefSource.self, forKey: .source),
      exerciseName: container.decode(String.self, forKey: .exerciseName),
      setNumber: container.decode(Int.self, forKey: .setNumber),
      setTotal: container.decodeIfPresent(Int.self, forKey: .setTotal),
      weightKg: container.decodeIfPresent(String.self, forKey: .weightKg),
      reps: container.decodeIfPresent(Int.self, forKey: .reps),
      repsMax: container.decodeIfPresent(Int.self, forKey: .repsMax),
      rpe: container.decodeIfPresent(String.self, forKey: .rpe),
      dayDate: container.decode(String.self, forKey: .dayDate),
      setLogId: container.decodeIfPresent(UUID.self, forKey: .setLogID),
      planSetId: container.decodeIfPresent(UUID.self, forKey: .planSetID)
    )
  }

  private enum CodingKeys: String, CodingKey, CaseIterable {
    case version = "v"
    case source
    case exerciseName
    case setNumber
    case setTotal
    case weightKg
    case reps
    case repsMax
    case rpe
    case dayDate
    case setLogID = "setLogId"
    case planSetID = "planSetId"
  }
}
