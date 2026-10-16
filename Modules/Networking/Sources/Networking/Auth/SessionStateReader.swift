import CoreModels
import Foundation

public enum SessionStateReaderError: Error, Equatable, Sendable {
  case authenticationExpired
  case missingAccessToken
  case missingCurrentUser
}

public protocol SessionStateReader: Sendable {
  func accessToken() async throws -> String
  func currentUser() async throws -> User
}
