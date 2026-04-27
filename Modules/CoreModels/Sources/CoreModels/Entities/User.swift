import Foundation

public struct User: Codable, Hashable, Sendable, Identifiable {
  public let id: UUID
  public let phone: String
  public let appleUserID: String?
  public let name: String?
  public let avatarURL: URL?
  public let gender: Gender?
  public let birthDate: Date?
  public let heightCm: Decimal?
  public let weightKg: Decimal?
  public let unitSystem: UnitSystem
  public let role: UserRole
  public let createdAt: Date
  public let updatedAt: Date

  public init(
    id: UUID,
    phone: String,
    appleUserID: String? = nil,
    name: String? = nil,
    avatarURL: URL? = nil,
    gender: Gender? = nil,
    birthDate: Date? = nil,
    heightCm: Decimal? = nil,
    weightKg: Decimal? = nil,
    unitSystem: UnitSystem,
    role: UserRole,
    createdAt: Date,
    updatedAt: Date
  ) {
    self.id = id
    self.phone = phone
    self.appleUserID = appleUserID
    self.name = name
    self.avatarURL = avatarURL
    self.gender = gender
    self.birthDate = birthDate
    self.heightCm = heightCm
    self.weightKg = weightKg
    self.unitSystem = unitSystem
    self.role = role
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    id = try container.decode(UUID.self, forKey: .id)
    phone = try container.decode(String.self, forKey: .phone)
    appleUserID = try container.decodeIfPresent(String.self, forKey: .appleUserID)
    name = try container.decodeIfPresent(String.self, forKey: .name)
    avatarURL = try container.decodeIfPresent(URL.self, forKey: .avatarURL)
    gender = try container.decodeIfPresent(Gender.self, forKey: .gender)
    birthDate = try container.decodeIfPresent(Date.self, forKey: .birthDate)
    heightCm = try container.decodeDecimalIfPresent(forKey: .heightCm)
    weightKg = try container.decodeDecimalIfPresent(forKey: .weightKg)
    unitSystem = try container.decode(UnitSystem.self, forKey: .unitSystem)
    role = try container.decode(UserRole.self, forKey: .role)
    createdAt = try container.decode(Date.self, forKey: .createdAt)
    updatedAt = try container.decode(Date.self, forKey: .updatedAt)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    try container.encode(id, forKey: .id)
    try container.encode(phone, forKey: .phone)
    try container.encodeIfPresent(appleUserID, forKey: .appleUserID)
    try container.encodeIfPresent(name, forKey: .name)
    try container.encodeIfPresent(avatarURL, forKey: .avatarURL)
    try container.encodeIfPresent(gender, forKey: .gender)
    try container.encodeIfPresent(birthDate, forKey: .birthDate)
    try container.encodeDecimalStringIfPresent(heightCm, forKey: .heightCm)
    try container.encodeDecimalStringIfPresent(weightKg, forKey: .weightKg)
    try container.encode(unitSystem, forKey: .unitSystem)
    try container.encode(role, forKey: .role)
    try container.encode(createdAt, forKey: .createdAt)
    try container.encode(updatedAt, forKey: .updatedAt)
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case phone
    case appleUserID = "appleUserId"
    case name
    case avatarURL = "avatarUrl"
    case gender
    case birthDate
    case heightCm
    case weightKg
    case unitSystem
    case role
    case createdAt
    case updatedAt
  }
}
