import Foundation

public struct DeviceTokenRequestDTO: Codable, Equatable, Sendable {
  public let token: String
  public let platform: String

  public init(token: String, platform: String = "ios") {
    self.token = token
    self.platform = platform
  }
}

public struct DeviceTokenResponseDTO: Codable, Equatable, Sendable {
  public let id: UUID

  public init(id: UUID) {
    self.id = id
  }
}

extension APIClient {
  @discardableResult
  public func registerDeviceToken(
    _ token: String,
    accessToken: String
  ) async throws -> DeviceTokenResponseDTO {
    try await post(
      path: "/devices/token",
      body: DeviceTokenRequestDTO(token: token),
      accessToken: accessToken
    )
  }
}
