import Foundation

/// Invite-code format rules shared by both roles (spec 031 D3/D11): the coach
/// side renders grouped codes, the student side pre-validates input before the
/// code reaches the backend (possibly only after the 7-step wizard, so this is
/// the sole early gate against typos).
///
/// Coupled verbatim to backend spec 005 D4 (10 chars, 32-char alphabet without
/// I/O/0/1). Changing the backend generation rule is a breaking change that
/// must update both spec 031 and this file in lockstep.
public enum InviteCodeFormat {
  public static let length = 10
  public static let alphabet = Set("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")

  /// Uppercases and strips spaces / hyphens (paste tolerance, spec 031 D11).
  public static func normalize(_ raw: String) -> String {
    raw.uppercased().filter { $0 != " " && $0 != "-" }
  }

  /// True when `normalized` is exactly 10 chars of the locked alphabet.
  /// Call with already-normalized input.
  public static func isValid(_ normalized: String) -> Bool {
    normalized.count == length && normalized.allSatisfy { alphabet.contains($0) }
  }

  /// 4-3-3 spaced display grouping, e.g. "XK7MPQ2RVT" → "XK7M PQ2 RVT"
  /// (spec 031 D11). Clipboard copies always use the raw ungrouped code.
  public static func grouped(_ code: String) -> String {
    guard code.count == length else { return code }
    let chars = Array(code)
    return "\(String(chars[0..<4])) \(String(chars[4..<7])) \(String(chars[7..<10]))"
  }
}
