import Foundation

enum PlanningWorkspaceStrings {
  static func text(_ key: String.LocalizationValue, locale: Locale = .current) -> String {
    CoachLocalization.localized(key, locale: locale)
  }

  static func replacing(
    _ key: String.LocalizationValue,
    _ replacements: [String: CustomStringConvertible],
    locale: Locale = .current
  ) -> String {
    CoachLocalization.replacing(
      key,
      values: replacements.mapValues { String(describing: $0) },
      locale: locale)
  }

  static func displayDraftName(
    _ name: String, studentName: String, locale: Locale = .current
  ) -> String {
    if name == "\(studentName) \u{9002}\u{5E94}\u{5468}" {
      return replacing(
        "coach.workspace.defaultAdaptationName", ["student": studentName], locale: locale)
    }

    let prefix = "\(studentName) "
    let suffix = " \u{5468}\u{8BA1}\u{5212}"
    guard name.hasPrefix(prefix), name.hasSuffix(suffix) else { return name }
    let countStart = name.index(name.startIndex, offsetBy: prefix.count)
    let countEnd = name.index(name.endIndex, offsetBy: -suffix.count)
    guard let count = Int(name[countStart..<countEnd]) else { return name }
    return CoachLocalization.localized(
      "coach.workspace.defaultDraftName \(studentName) \(count)", locale: locale)
  }
}
