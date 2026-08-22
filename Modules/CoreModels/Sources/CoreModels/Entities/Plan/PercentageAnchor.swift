import Foundation

/// Reference value used to translate a percentage prescription into kilograms.
public enum PercentageAnchor: String, Codable, Hashable, Sendable {
  case registeredOneRM = "one_rm"
  case e1RM = "e1rm"
  case topSet = "top_set"

  /// Backend values are additive and intentionally decoded leniently. An
  /// unknown future value falls back to the contract's nil = registered 1RM
  /// behavior instead of making the whole plan unreadable.
  public init?(wireValue: String?) {
    guard let wireValue else { return nil }
    self.init(rawValue: wireValue)
  }
}
