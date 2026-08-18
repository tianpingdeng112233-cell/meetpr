import CoreModels
import Foundation
import Testing

@testable import CoachKit

@Suite("CoachKit localization")
struct CoachLocalizationTests {
  @Test("every string has complete Chinese and English translations")
  func catalogIsComplete() throws {
    let catalog = try loadCatalog()

    #expect(catalog.strings.count >= 800)
    for (key, entry) in catalog.strings {
      let chinese = entry.localizations["zh-Hans"]?.otherValue
      let englishLocalization = entry.localizations["en"]
      let english = englishLocalization?.otherValue
      #expect(chinese?.isEmpty == false, "Missing zh-Hans value for \(key)")
      #expect(english?.isEmpty == false, "Missing en value for \(key)")
      for englishValue in englishLocalization?.values ?? [] {
        #expect(!englishValue.isEmpty, "Empty English variation for \(key)")
        #expect(!containsHan(englishValue), "English contains Chinese for \(key)")
      }
      if englishLocalization?.substitutions == nil {
        for englishValue in englishLocalization?.values ?? [] {
          #expect(
            placeholders(in: chinese ?? "") == placeholders(in: englishValue),
            "Placeholder mismatch for \(key)")
        }
      } else if let effective = englishLocalization?.effectiveOtherValue {
        #expect(
          placeholders(in: chinese ?? "") == placeholders(in: effective),
          "Placeholder mismatch for substitution key \(key)")
      }
    }
  }

  @Test("count strings provide an English singular variation")
  func countStringsProvideSingularEnglish() throws {
    let strings = try loadCatalog().strings
    let expected = [
      "coach.bind.waiting.minutes %lld": "Waiting %lld minute",
      "coach.invites.status.expiresIn %lld": "Expires in %lld day",
      "coach.bind.card.uploadCount %lld": "%lld file",
      "coach.applicationProfile.weeklyFrequency %lld": "%lld session/week",
    ]

    for (key, singular) in expected {
      #expect(strings[key]?.localizations["en"]?.pluralValue(for: "one") == singular)
    }

    for (key, entry) in strings {
      guard entry.localizations["en"]?.variations?.plural != nil else { continue }
      #expect(
        entry.localizations["en"]?.pluralValue(for: "one") != nil,
        "Missing English .one variation for \(key)"
      )
      #expect(key.contains("%lld"), "Plural key does not receive a numeric argument: \(key)")
      for value in entry.localizations["en"]?.values ?? [] {
        #expect(value.contains("%lld"), "Plural value does not format its count: \(key)")
        #expect(!value.contains("{count}"), "Legacy count placeholder remains: \(key)")
      }
    }
  }

  @Test("every countable English value is plural-aware")
  func countableEnglishValuesArePluralAware() throws {
    let strings = try loadCatalog().strings
    // Caller-branched combo keys pick the singular/plural key explicitly.
    let callerBranched: Set<String> = [
      "coach.planning.step4.setRepIntensity %lld %@ %@",
      "coach.planning.step4.setRepsIntensity %lld %@ %@",
      "coach.planning.step4.setsRepIntensity %lld %@ %@",
      "coach.planning.step4.setsRepsIntensity %lld %@ %@",
    ]
    let nouns = [
      "days", "hours", "sets", "reps", "weeks", "videos", "files", "sessions",
      "minutes", "students", "exercises", "items", "messages", "codes", "plans",
    ]
    let pattern = "%(lld|@|\\d+\\$lld)\\s+(\\S+\\s+)?(" + nouns.joined(separator: "|") + ")\\b"
    let regex = try NSRegularExpression(pattern: pattern)
    for (key, entry) in strings {
      guard let english = entry.localizations["en"], !english.isCountAware,
        !callerBranched.contains(key),
        let value = english.stringUnit?.value
      else { continue }
      let range = NSRange(value.startIndex..., in: value)
      #expect(
        regex.firstMatch(in: value, range: range) == nil,
        "Countable English value lacks plural handling for \(key): \(value)")
    }
  }

  @Test("English catalog does not contain generated placeholder labels")
  func englishCatalogHasRealTranslations() throws {
    let strings = try loadCatalog().strings
    let generatedPlaceholders: Set<String> = [
      "Empty Title",
      "Faq Feedback Question",
      "Label Placeholder",
      "Logout Title",
      "Missing Value",
      "Readiness Reminder Draft",
      "Regenerate Title",
      "Remind To File",
      "Revoke Title",
      "Status Active",
      "Status Expired",
      "Status Revoked",
      "Status Used",
      "Training Reminder Draft",
    ]
    let expected = [
      "coach.applicationProfile.notProvided": "—",
      "coach.inbox.emptyTitle": "All caught up",
      "coach.invites.regenerateTitle": "Regenerate permanent code?",
      "coach.invites.status.active": "Active",
      "coach.profile.faq.feedback.question": "Where does feedback go?",
      "coach.profile.logoutTitle": "Log out?",
      "coach.videoFeedback.missingValue": "—",
    ]

    for (key, entry) in strings {
      for value in entry.localizations["en"]?.values ?? [] {
        #expect(
          !generatedPlaceholders.contains(value),
          "Generated English placeholder remains for \(key)"
        )
        #expect(
          !titleCaseKeyCandidates(key).contains(value),
          "English value is a TitleCase rendering of its key: \(key)"
        )
      }
    }

    for (key, value) in expected {
      #expect(strings[key]?.localizations["en"]?.otherValue == value)
    }
  }

  @Test("critical Chinese source strings stay byte-exact")
  func criticalChineseStringsAreByteExact() throws {
    let strings = try loadCatalog().strings
    let expected = [
      "coach.bind.accept.confirmQuestion": "确认接收 {student} 为学员?",
      "coach.evaluation.remaining %lld %lld": "评估期 · 还剩 %lld 天 %lld 小时",
      "coach.feedback.placeholder": "给 {student} 写反馈...",
      "coach.import.pickFileDescription":
        "把电脑上的 .xlsx 计划表 AirDrop 到手机，选它导入。解析在本机完成，文件不上传。",
      "coach.planning.step4.completionIssues": "以下项目需要补全后才能进入下一步：\n\n{issues}",
      "coach.workspace.empty.body": "所有学员都有在跑计划。需要新建周期时，点上方「排新计划」。",
    ]

    for (key, value) in expected {
      #expect(strings[key]?.localizations["zh-Hans"]?.otherValue == value)
    }
  }

  @Test("exercise display uses catalog English without changing the canonical name")
  func exerciseDisplayNameUsesNameEn() {
    let exercise = InMemoryPlanRepository.syntheticCompetitionLifts()[0]

    #expect(
      CoachLocalization.exerciseName(exercise, locale: Locale(identifier: "zh-Hans"))
        == exercise.name)
    #expect(
      CoachLocalization.exerciseName(exercise, locale: Locale(identifier: "en"))
        == exercise.nameEn)
    #expect(exercise.name == "比赛式深蹲")

    let coachAuthoredExercise = Exercise(
      id: UUID(),
      name: "我的自定义动作",
      exerciseType: .accessory,
      isCompetitionLift: false,
      muscleGroups: [],
      equipment: [],
      createdByCoachID: UUID(),
      createdAt: Date(timeIntervalSince1970: 0)
    )
    #expect(
      CoachLocalization.exerciseName(
        coachAuthoredExercise,
        locale: Locale(identifier: "en")
      ) == "我的自定义动作"
    )
  }

  private func loadCatalog() throws -> Catalog {
    let packageRoot = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    return try JSONDecoder().decode(
      Catalog.self,
      from: Data(
        contentsOf: packageRoot.appending(
          path: "Sources/CoachKit/Resources/Localizable.xcstrings"))
    )
  }

  private func containsHan(_ text: String) -> Bool {
    text.unicodeScalars.contains { scalar in
      (0x3400...0x4DBF).contains(scalar.value)
        || (0x4E00...0x9FFF).contains(scalar.value)
    }
  }

  private func placeholders(in text: String) -> [String] {
    var result: [String] = []
    var openingIndex: String.Index?
    var index = text.startIndex
    while index < text.endIndex {
      if text[index] == "{" {
        openingIndex = index
      } else if text[index] == "}", let opening = openingIndex {
        result.append(String(text[opening...index]))
        openingIndex = nil
      } else if text[index] == "%" {
        let suffix = text[index...]
        if suffix.hasPrefix("%%") {
          index = text.index(after: index)
        } else if suffix.hasPrefix("%1$lld") || suffix.hasPrefix("%2$lld")
          || suffix.hasPrefix("%3$lld")
        {
          result.append("%lld")
          index = text.index(index, offsetBy: 5)
        } else if suffix.hasPrefix("%1$@") || suffix.hasPrefix("%2$@") || suffix.hasPrefix("%3$@") {
          result.append("%@")
          index = text.index(index, offsetBy: 3)
        } else if suffix.hasPrefix("%lld") {
          result.append("%lld")
          index = text.index(index, offsetBy: 3)
        } else if suffix.hasPrefix("%@") {
          result.append("%@")
          index = text.index(after: index)
        }
      }
      index = text.index(after: index)
    }
    return result.sorted()
  }

  private func titleCaseKeyCandidates(_ key: String) -> Set<String> {
    let fragments = key.split(separator: ".").dropFirst()
    var candidates: Set<String> = []
    for start in fragments.indices {
      guard fragments.distance(from: start, to: fragments.endIndex) >= 3 else { continue }
      let candidateWords = fragments[start...].flatMap { words(in: String($0)) }
      candidates.insert(candidateWords.map(titleCased).joined(separator: " "))
    }
    return candidates
  }

  private func words(in fragment: String) -> [String] {
    var result: [String] = []
    var current = ""
    for character in fragment {
      if character == "_" || character == "-" {
        if !current.isEmpty { result.append(current) }
        current = ""
      } else if character.isUppercase, !current.isEmpty {
        result.append(current)
        current = String(character)
      } else {
        current.append(character)
      }
    }
    if !current.isEmpty { result.append(current) }
    return result
  }

  private func titleCased(_ word: String) -> String {
    word.prefix(1).uppercased() + word.dropFirst()
  }
}

private struct Catalog: Decodable {
  let strings: [String: Entry]

  struct Entry: Decodable {
    let localizations: [String: Localization]
  }

  struct Localization: Decodable {
    let stringUnit: StringUnit?
    let variations: Variations?
    let substitutions: [String: Substitution]?

    var otherValue: String {
      stringUnit?.value ?? pluralValue(for: "other") ?? ""
    }

    var values: [String] {
      var result: [String] = []
      if let stringUnit { result.append(stringUnit.value) }
      if let variations {
        result.append(contentsOf: variations.plural.values.map(\.stringUnit.value))
      }
      for substitution in substitutions?.values ?? [:].values {
        result.append(contentsOf: substitution.variations.plural.values.map(\.stringUnit.value))
      }
      return result
    }

    // The main value of a substitution-based entry embeds %#@name@ markers;
    // resolve each back to its numeric specifier so placeholder parity with
    // the plain zh value can still be asserted.
    var effectiveOtherValue: String {
      var value = otherValue
      for (name, substitution) in substitutions ?? [:] {
        value = value.replacingOccurrences(
          of: "%#@\(name)@", with: "%\(substitution.formatSpecifier)")
      }
      return value
    }

    var isCountAware: Bool {
      variations?.plural != nil || !(substitutions ?? [:]).isEmpty
    }

    func pluralValue(for category: String) -> String? {
      variations?.plural[category]?.stringUnit.value
    }
  }

  struct Substitution: Decodable {
    let argNum: Int
    let formatSpecifier: String
    let variations: Variations
  }

  struct Variations: Decodable {
    let plural: [String: Variation]
  }

  struct Variation: Decodable {
    let stringUnit: StringUnit
  }

  struct StringUnit: Decodable {
    let value: String
  }
}
