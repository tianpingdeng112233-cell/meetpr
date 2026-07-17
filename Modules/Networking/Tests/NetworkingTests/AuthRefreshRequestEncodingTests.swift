import CoreModels
import Foundation
import Testing

@testable import Networking

/// Pins the /auth/refresh request wire format. Every shipped client refreshes its
/// token through this exact body; if the encoder strategy or the DTO property name
/// ever changes the key, refresh breaks fleet-wide within one access-token TTL
/// (2026-07-17 incident: a key-name mismatch 400'd every refresh and forced
/// re-login across the beta). The backend canonically accepts `refresh_token`
/// (and tolerates `refreshToken` since backend PR #76).
@Test func authRefreshRequestEncodesSnakeCaseRefreshTokenKey() throws {
  let body = AuthRefreshRequestDTO(refreshToken: "refresh-token-value")

  let data = try MeetPRCodec.encoder.encode(body)
  let json = try #require(String(bytes: data, encoding: .utf8))

  #expect(json == #"{"refresh_token":"refresh-token-value"}"#)
}
