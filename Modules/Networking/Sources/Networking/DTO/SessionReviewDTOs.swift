import Foundation

// Wire shapes for `/students/me/reviews/:date` and `/students/:id/reviews`
// (backend spec 012). Keys are snake_case on the wire; MeetPRCodec converts.

public struct SubmitSessionReviewRequestDTO: Encodable, Equatable, Sendable {
  public let feeling: String
  public let sessionRpe: Decimal?

  public init(feeling: String, sessionRpe: Decimal?) {
    self.feeling = feeling
    self.sessionRpe = sessionRpe
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(feeling, forKey: .feeling)
    try container.encodeDecimalStringIfPresent(sessionRpe, forKey: .sessionRpe)
  }

  private enum CodingKeys: String, CodingKey {
    case feeling
    case sessionRpe
  }
}

public struct SessionReviewDTO: Decodable, Equatable, Sendable {
  public let id: UUID
  public let studentID: UUID
  /// Plain YYYY-MM-DD — not a timestamp, must dodge the ISO8601 strategy.
  public let reviewDate: String
  public let feeling: String
  public let sessionRpe: Decimal?
  public let updatedAt: Date

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(UUID.self, forKey: .id)
    studentID = try container.decode(UUID.self, forKey: .studentID)
    reviewDate = try container.decode(String.self, forKey: .reviewDate)
    feeling = try container.decode(String.self, forKey: .feeling)
    sessionRpe = try container.decodeDecimalIfPresent(forKey: .sessionRpe)
    updatedAt = try container.decode(Date.self, forKey: .updatedAt)
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case studentID = "studentId"
    case reviewDate
    case feeling
    case sessionRpe
    case updatedAt
  }
}

public struct SessionReviewsResponseDTO: Decodable, Equatable, Sendable {
  public let reviews: [SessionReviewDTO]
}
