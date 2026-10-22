import Foundation

/// Normalizes search/parser input only. Stored names and user-authored copy stay untouched.
public enum ExerciseSearchText {
  public static func searchKey(_ input: String) -> String {
    let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
    let stripped =
      specificationSuffix?.stringByReplacingMatches(
        in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "") ?? text
    return simplified(stripped).replacing("杆", with: "杠").lowercased()
  }

  public static func matches(_ candidate: String, query: String) -> Bool {
    let needle = searchKey(query)
    let name = searchKey(candidate)
    return name.localizedStandardContains(needle)
      || aliasesByCanonical[name]?.contains(where: { $0.localizedStandardContains(needle) }) == true
  }

  public static func simplified(_ input: String) -> String {
    let result = NSMutableString(string: input)
    if let pattern = phrasePattern {
      for match in pattern.matches(in: input, range: NSRange(input.startIndex..., in: input))
        .reversed()
      {
        let phrase = (input as NSString).substring(with: match.range)
        if let replacement = mappings.phrases[phrase] {
          result.replaceCharacters(in: match.range, with: replacement)
        }
      }
    }
    return (result as String).map { mappings.characters[String($0)] ?? String($0) }.joined()
  }

  // Only dimensional suffixes are presentation notes. Preserve variant identities
  // such as 架上(PIN)深蹲 and 单腿罗马尼亚硬拉(纯单腿).
  private static let specificationSuffix = try? NSRegularExpression(
    pattern: #"\s*[\(（]\s*\d+(?:\.\d+)?\s*(?:mm|cm|毫米|厘米|公分)\s*[\)）]\s*$"#,
    options: .caseInsensitive)

  private static let aliasesByCanonical: [String: [String]] = {
    var result: [String: [String]] = [:]
    for (canonical, aliases) in mappings.aliases {
      result[searchKey(canonical), default: []].append(contentsOf: aliases.map(searchKey))
    }
    return result
  }()

  private static let phrasePattern: NSRegularExpression? = {
    let keys = mappings.phrases.keys.sorted {
      $0.count == $1.count ? $0 < $1 : $0.count > $1.count
    }
    return try? NSRegularExpression(
      pattern: keys.map(NSRegularExpression.escapedPattern(for:)).joined(separator: "|"))
  }()

  private struct Mappings: Decodable, Sendable {
    let phrases: [String: String]
    let characters: [String: String]
    let aliases: [String: [String]]
  }

  private static let mappings: Mappings = {
    guard
      let url = Bundle.module.url(forResource: "exercise-search-zh-Hant", withExtension: "json"),
      let data = try? Data(contentsOf: url),
      let decoded = try? JSONDecoder().decode(Mappings.self, from: data)
    else { return Mappings(phrases: [:], characters: [:], aliases: [:]) }
    return decoded
  }()
}
