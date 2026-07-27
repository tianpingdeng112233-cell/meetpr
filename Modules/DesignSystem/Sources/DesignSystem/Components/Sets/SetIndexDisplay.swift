/// Converts the execution domain's zero-based set index into a user-facing
/// one-based number.
public enum SetIndexDisplay {
  public static func number(forZeroBasedIndex setIndex: Int) -> Int {
    setIndex + 1
  }
}
