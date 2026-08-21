import Foundation

enum TrainingReminderWeekday: Int, CaseIterable, Codable, Hashable, Identifiable, Sendable {
  case monday = 2
  case tuesday = 3
  case wednesday = 4
  case thursday = 5
  case friday = 6
  case saturday = 7
  case sunday = 1

  var id: Self { self }

  func shortName(locale: Locale = .current) -> String {
    let key: StudentStrings.Key
    switch self {
    case .monday:
      key = .trainingReminderWeekday001
    case .tuesday:
      key = .trainingReminderWeekday002
    case .wednesday:
      key = .trainingReminderWeekday003
    case .thursday:
      key = .trainingReminderWeekday004
    case .friday:
      key = .trainingReminderWeekday005
    case .saturday:
      key = .trainingReminderWeekday006
    case .sunday:
      key = .trainingReminderWeekday007
    }
    return StudentStrings.localized(key, locale: locale)
  }
}

struct TrainingReminderSettings: Codable, Equatable, Sendable {
  var isEnabled: Bool
  var weekdays: Set<TrainingReminderWeekday>
  var hour: Int
  var minute: Int

  static let defaultValue = TrainingReminderSettings(
    isEnabled: false,
    weekdays: [.monday, .wednesday, .friday],
    hour: 20,
    minute: 0
  )

  var isValid: Bool {
    (0...23).contains(hour) && (0...59).contains(minute)
  }
}

enum TrainingReminderCopy {
  static func summary(
    for settings: TrainingReminderSettings,
    locale: Locale = .current
  ) -> String {
    guard settings.isEnabled else {
      return StudentStrings.localized(.trainingReminderCopy001, locale: locale)
    }
    guard !settings.weekdays.isEmpty else {
      return StudentStrings.localized(.trainingReminderCopy002, locale: locale)
    }

    let names = TrainingReminderWeekday.allCases
      .filter(settings.weekdays.contains)
      .map { $0.shortName(locale: locale) }
    let days: String
    if locale.language.languageCode?.identifier == "en" {
      days = names.joined(separator: " · ")
    } else {
      days = "周" + names.joined(separator: "·")
    }
    return "\(days) \(timeText(for: settings))"
  }

  static func timeText(for settings: TrainingReminderSettings) -> String {
    "\(twoDigit(settings.hour)):\(twoDigit(settings.minute))"
  }

  private static func twoDigit(_ value: Int) -> String {
    value < 10 ? "0\(value)" : "\(value)"
  }
}

protocol TrainingReminderSettingsStoring: Sendable {
  func settings(for studentID: UUID) -> TrainingReminderSettings
  func setSettings(_ settings: TrainingReminderSettings, for studentID: UUID)
}

struct TrainingReminderUserDefaultsStore: TrainingReminderSettingsStoring {
  nonisolated(unsafe) private let defaults: UserDefaults

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  func settings(for studentID: UUID) -> TrainingReminderSettings {
    guard let data = defaults.data(forKey: key(for: studentID)),
      let settings = try? JSONDecoder().decode(TrainingReminderSettings.self, from: data),
      settings.isValid
    else {
      return .defaultValue
    }
    return settings
  }

  func setSettings(_ settings: TrainingReminderSettings, for studentID: UUID) {
    guard settings.isValid, let data = try? JSONEncoder().encode(settings) else { return }
    defaults.set(data, forKey: key(for: studentID))
  }

  private func key(for studentID: UUID) -> String {
    "meetpr.student.training_reminder.settings.\(studentID.uuidString)"
  }
}
