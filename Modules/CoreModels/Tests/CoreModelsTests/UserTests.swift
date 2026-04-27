import Foundation
import Testing

@testable import CoreModels

@Test func userCodableRoundTripPreservesValues() throws {
  let user = User(
    id: UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID(),
    role: .coach,
    displayName: "Test User"
  )

  let data = try JSONEncoder().encode(user)
  let decodedUser = try JSONDecoder().decode(User.self, from: data)

  #expect(decodedUser == user)
  #expect(decodedUser.role == .coach)
}
