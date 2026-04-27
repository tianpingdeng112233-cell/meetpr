import Foundation

public enum UserRole: String, Codable, Equatable, Sendable {
  case coach
  case student
}

public struct User: Codable, Equatable, Identifiable, Sendable {
  public let id: UUID
  public let role: UserRole
  public let displayName: String

  public init(id: UUID, role: UserRole, displayName: String) {
    self.id = id
    self.role = role
    self.displayName = displayName
  }
}
