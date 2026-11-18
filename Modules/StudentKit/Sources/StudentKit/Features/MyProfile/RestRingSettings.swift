import Foundation

public struct RestRingSettings: Codable, Equatable, Sendable {
  public var mainSeconds = 180
  public var accessorySeconds = 60
  public var vibration = true
  public var sound = true
  public var didSaveFirstSettings = false
  public var didUseRing = false

  public init() {}

  var needsFirstSettings: Bool { !didSaveFirstSettings }
  var showsHint: Bool { didSaveFirstSettings && !didUseRing }

  mutating func finishSetup() { didSaveFirstSettings = true }
  mutating func useRing() { didUseRing = true }

  static func migrate(bands: Data?, fixed: Int?, accessory: Int?) -> Self {
    var result = Self()
    if let bands, let old = try? JSONDecoder().decode(LegacyBands.self, from: bands),
      old.version == 2,
      [old.lowSeconds, old.midSeconds, old.highSeconds].allSatisfy(validDuration)
    {
      result.mainSeconds = old.midSeconds
    } else if let fixed, validDuration(fixed) {
      result.mainSeconds = fixed
    }
    if let accessory, accessory >= 30, accessory.isMultiple(of: 15) {
      result.accessorySeconds = min(600, accessory)
    }
    return result
  }

  static func validDuration(_ seconds: Int) -> Bool {
    (30...600).contains(seconds) && seconds.isMultiple(of: 15)
  }

  private struct LegacyBands: Decodable {
    let version: Int
    let lowSeconds: Int
    let midSeconds: Int
    let highSeconds: Int
  }
}
