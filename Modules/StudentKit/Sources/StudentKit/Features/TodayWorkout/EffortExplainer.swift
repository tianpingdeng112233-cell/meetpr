import Foundation

struct EffortExplainerContent: Sendable {
  struct Row: Sendable {
    let value: String
    let description: String
  }

  let title: String
  let subtitle: String
  let rows: [Row]
  let example: String?
  let closing: String
  let helpLabel: String
}

/// Shared presentation copy for all three effort-help entry points.
enum EffortExplainer {
  static func content(for kind: ActualEffortMode, locale: Locale = .current)
    -> EffortExplainerContent
  {
    switch kind {
    case .rpe:
      let rows: [(String, StudentStrings.Key)] = [
        ("10", .setEntryRpe011), ("9.5", .setEntryRpe010), ("9", .setEntryRpe009),
        ("8.5", .setEntryRpe008), ("8", .setEntryRpe007), ("7.5", .setEntryRpe006),
        ("7", .setEntryRpe005), ("5–6", .setEntryRpe001),
      ]
      return EffortExplainerContent(
        title: StudentStrings.localized(.effortExplainerRpeTitle, locale: locale),
        subtitle: StudentStrings.localized(.effortExplainerRpeSubtitle, locale: locale),
        rows: rows.map {
          .init(value: $0.0, description: StudentStrings.localized($0.1, locale: locale))
        },
        example: nil,
        closing: StudentStrings.localized(.effortExplainerRpeClosing, locale: locale),
        helpLabel: StudentStrings.localized(.effortExplainerRpeHelp, locale: locale))
    case .rir:
      return EffortExplainerContent(
        title: StudentStrings.localized(.effortExplainerRirTitle, locale: locale),
        subtitle: StudentStrings.localized(.effortExplainerRirSubtitle, locale: locale),
        rows: [],
        example: StudentStrings.localized(.effortExplainerRirExample, locale: locale),
        closing: StudentStrings.localized(.effortExplainerRirClosing, locale: locale),
        helpLabel: StudentStrings.localized(.effortExplainerRirHelp, locale: locale))
    }
  }

  static func rirStepperCopy(_ value: String, locale: Locale = .current) -> String? {
    guard let count = Int(value), (0...9).contains(count) else { return nil }
    if count == 0 { return StudentStrings.localized(.setEntryRpe011, locale: locale) }
    return StudentStrings.replacing(
      .effortExplainerRirRemaining, values: [String(count)], locale: locale)
  }

}
