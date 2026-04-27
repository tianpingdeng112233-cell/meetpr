import Foundation

public struct Plan: Codable, Equatable, Identifiable, Sendable {
  public let id: UUID
  public let title: String

  public init(id: UUID, title: String) {
    self.id = id
    self.title = title
  }
}
