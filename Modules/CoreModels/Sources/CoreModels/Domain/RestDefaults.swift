import Foundation

public enum RestDefaults {
  public static func seconds(forRPE rpe: Decimal?) -> Int {
    guard let rpe else { return 180 }
    if rpe < 7 { return 120 }
    if rpe < 9 { return 180 }
    return 240
  }
}
