import Foundation

public struct RegisterDeviceTokenRequestDTO: Encodable, Equatable, Sendable {
  public let token: String
  public let platform: String

  public init(token: String, platform: String = "ios") {
    self.token = token
    self.platform = platform
  }
}

private struct RegisterDeviceTokenResponseDTO: Decodable, Sendable {
  let id: UUID
}

extension APIClient {
  public func registerDeviceToken(
    _ hexToken: String,
    accessToken: String
  ) async throws {
    let _: RegisterDeviceTokenResponseDTO = try await post(
      path: "/devices/token",
      body: RegisterDeviceTokenRequestDTO(token: hexToken),
      accessToken: accessToken
    )
  }
}
