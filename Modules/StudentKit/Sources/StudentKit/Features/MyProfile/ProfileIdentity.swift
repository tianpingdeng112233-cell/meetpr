import CoreModels
import Foundation

/// Step one uses only the existing login identifier and accepted coach context.
struct ProfileIdentity: Equatable, Sendable {
  let name: String
  let coach: String?

  init(loginIdentifier: String = "", activeCoach: ActiveCoachContext? = nil) {
    name = Self.displayName(phone: loginIdentifier)
    coach = Self.coachName(
      status: activeCoach == nil ? nil : .accepted, name: activeCoach?.coachDisplayName)
  }

  static func displayName(
    name: String? = nil, email: String? = nil, phone: String? = nil
  ) -> String {
    [name, email, phone].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
      .first { !$0.isEmpty } ?? ""
  }

  static func initials(_ identity: String) -> String {
    let text = identity.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let first = text.first else { return "" }
    let isCJK = first.unicodeScalars.contains {
      (0x3400...0x9FFF).contains($0.value) || (0x3040...0x30FF).contains($0.value)
        || (0xAC00...0xD7AF).contains($0.value)
    }
    let letters =
      text.contains("@") || isCJK
      ? String(first)
      : text.split(whereSeparator: \.isWhitespace).prefix(2).compactMap(\.first).map(String.init)
        .joined()
    return letters.allSatisfy(\.isLetter) ? letters.uppercased() : ""
  }

  static func coachName(status: BindRequestStatus?, name: String?) -> String? {
    guard status == .accepted,
      let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty
    else { return nil }
    return trimmed
  }
}
