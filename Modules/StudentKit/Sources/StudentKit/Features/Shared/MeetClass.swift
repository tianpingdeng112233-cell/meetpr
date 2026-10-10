import Foundation

enum MeetSex: String, CaseIterable, Sendable {
  case male, female
}

enum MeetFederation: String, CaseIterable, Sendable {
  case cpa = "CPA"
  case ipf = "IPF"
  case ipl = "IPL"
  case worldPowerlifting = "WP"

  func classes(for sex: MeetSex) -> [String] {
    let values: String
    switch (self, sex) {
    case (.ipf, .male): values = "59 66 74 83 93 105 120 120+"
    case (.ipf, .female): values = "47 52 57 63 69 76 84 84+"
    case (.worldPowerlifting, .male): values = "62 69 77 85 94 105 120 120+"
    case (.worldPowerlifting, .female): values = "48 53 58 64 72 84 100 100+"
    case (.ipl, .male), (.cpa, .male):
      values = "52 56 60 67.5 75 82.5 90 100 110 125 140 140+"
    case (.ipl, .female): values = "44 48 52 56 60 67.5 75 82.5 90 100 110 110+"
    case (.cpa, .female): values = "44 48 52 56 60 67.5 75 82.5 90 100 100+"
    }
    return values.split(separator: " ").map(String.init)
  }
}

struct MeetClass: Equatable, Sendable {
  let federation: MeetFederation
  let weightClass: String

  init?(federation: MeetFederation, weightClass: String) {
    guard MeetSex.allCases.contains(where: { federation.classes(for: $0).contains(weightClass) })
    else { return nil }
    self.federation = federation
    self.weightClass = weightClass
  }

  var formatted: String { "\(federation.rawValue) · \(weightClass) kg" }

  static func parse(_ text: String) -> MeetClass? {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    let parts = trimmed.components(separatedBy: " · ")
    guard parts.count == 2, let federation = MeetFederation(rawValue: parts[0]),
      parts[1].hasSuffix(" kg")
    else { return nil }
    return MeetClass(federation: federation, weightClass: String(parts[1].dropLast(3)))
  }
}
