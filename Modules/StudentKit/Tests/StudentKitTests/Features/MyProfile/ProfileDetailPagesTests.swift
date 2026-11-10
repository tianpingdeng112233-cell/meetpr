import CoreModels
import DesignSystem
import Foundation
import RepositoryContracts
import SwiftUI
import Testing
import ViewInspector

@testable import StudentKit

@MainActor
@Test func profileAboutRowsKeepOrderValuesAndExistingEditors() async throws {
  let profile = StudentDemoSeed.makeOnboardingProfile(studentID: StudentDemoSeed.studentID)
  var opened: [ProfileCardKind] = []
  let view = ProfileDetailRows(
    destination: .about, profile: profile, readiness: nil,
    onEdit: { opened.append($0) }, onReadiness: {})
  let rows = try view.inspect().findAll(MyProfileValueRow.self)
  #expect(
    try rows.map { try $0.actualView().label } == [
      StudentStrings.localized(.profileCardsSection002),
      StudentStrings.localized(.myProfileView011),
    ])
  #expect(try rows[0].actualView().value == "178 cm · 83.00 kg")
  let buttons = try view.inspect().findAll(ViewType.Button.self)
  for button in buttons { try button.tap() }
  #expect(opened == [.basics, .background])
  let repository = InMemoryOnboardingRepository(studentId: profile.userId, seed: profile)
  let model = MyProfileViewModel(studentId: profile.userId, repo: repository)
  await model.loadIfNeeded()
  var patch = OnboardingPatch()
  patch.weightKg = .value(84)
  #expect(await model.save(patch))
  let saved = try #require(model.state.profile)
  #expect(ProfileMenuValues.make(profile: saved).about == "178 cm · 84.00 kg")
  let updated = ProfileDetailRows(
    destination: .about, profile: saved, readiness: nil, onEdit: { _ in }, onReadiness: {})
  #expect(
    try updated.inspect().findAll(MyProfileValueRow.self)[0].actualView().value
      == "178 cm · 84.00 kg")
}

@MainActor
@Test func profileInjuryHistoryTitleMatchesMenuAndDetailInAllLanguages() throws {
  for (language, expected) in [
    ("zh-Hans", "伤病记录"), ("en", "Injury history"), ("zh-Hant", "傷病記錄"),
  ] {
    #expect(
      StudentStrings.localized(.profileHealth, locale: Locale(identifier: language)) == expected)
  }
  #expect(ProfileMenuDestination.health.title == "伤病记录")
  let profile = StudentDemoSeed.makeOnboardingProfile(studentID: StudentDemoSeed.studentID)
  let view = ProfileHomeContent(
    identity: ProfileIdentity(loginIdentifier: "person@example.com"), state: .loaded(profile),
    isFailed: false, onOpen: { _ in }, onRetry: {}, onOneRMInfo: {})
  let rows = try view.inspect().findAll(StudentMenuRow.self)
  #expect(try rows[1].actualView().title == "伤病记录")
}

@MainActor
@Test func profileHealthRowsKeepSummariesAndExistingDestinations() throws {
  let profile = StudentDemoSeed.makeOnboardingProfile(studentID: StudentDemoSeed.studentID)
  var readinessOpened = false
  var editor: ProfileCardKind?
  let view = ProfileDetailRows(
    destination: .health, profile: profile, readiness: nil,
    onEdit: { editor = $0 }, onReadiness: { readinessOpened = true })
  let rows = try view.inspect().findAll(MyProfileValueRow.self)
  #expect(
    try rows.map { try $0.actualView().label } == [
      StudentStrings.localized(.myProfileView005)
    ])
  #expect(try rows[0].actualView().value == "肩部伤病")
  let buttons = try view.inspect().findAll(ViewType.Button.self)
  try buttons[0].tap()
  #expect(!readinessOpened)
  #expect(editor == .injuries)
}

@MainActor
@Test func profileSettingsAppearanceBlocksAndSignOutUseExistingActions() async throws {
  var selection = MeetPRAppearance.light
  let options = ProfileAppearanceOptions(
    selection: Binding(get: { selection }, set: { selection = $0 }))
  let blocks = try options.inspect().findAll(StudentSelectionBlock.self)
  #expect(blocks.count == 3)
  #expect(try blocks.map { try $0.actualView().isSelected } == [false, true, false])
  try blocks[2].find(ViewType.Button.self).tap()
  #expect(selection == .dark)
  let signedOut: Bool = try await withCheckedThrowingContinuation { continuation in
    let button = ProfileSignOutButton { continuation.resume(returning: true) }
    do {
      try button.inspect().find(ViewType.Button.self).tap()
    } catch {
      continuation.resume(throwing: error)
    }
  }
  #expect(signedOut)
}

@MainActor
@Test func profileSettingsContainsPreferencesAndAllAccountRowsInOrder() throws {
  let studentID = UUID()
  let suite = "ProfileSettingsTests.\(UUID().uuidString)"
  let defaults = try #require(UserDefaults(suiteName: suite))
  defer { defaults.removePersistentDomain(forName: suite) }
  let plans = InMemoryStudentPlanRepository(
    store: StudentRootDemoPlanStore(studentID: studentID, plan: StudentDemoSeed.makePlanView()))
  let inspected = try MyProfileFallbackRows(
    studentID: studentID, plans: plans, account: InMemoryAccountRepository(),
    logs: InMemoryStudentTrainingLogRepository(),
    restTimerSettings: UserDefaultsRestTimerSettingsStore(defaults: defaults),
    trainingReminderServices: TrainingReminderServices(
      store: TrainingReminderUserDefaultsStore(defaults: defaults),
      center: FakeTrainingReminderNotificationCenter()), onLogout: {}
  ).inspect()
  let rows = try inspected.findAll(MyProfileValueRow.self)
  #expect(
    try rows.map { try $0.actualView().label } == [
      StudentStrings.localized(.trainingReminderPreferenceRow001)
    ])
  #expect(
    try rows.map { try $0.actualView().value } == [
      TrainingReminderCopy.summary(for: .defaultValue)
    ])
  let account = try inspected.find(AccountSecuritySection.self)
  let buttons = try account.findAll(ViewType.Button.self)
  #expect(
    try buttons.map { try $0.accessibilityIdentifier() } == [
      "account.changePassword", "account.export", "account.delete",
    ])
  #expect(try inspected.findAll(AppearancePreferenceRow.self).count == 1)
  #expect(try inspected.findAll(ProfileSignOutButton.self).count == 1)
}

@MainActor
@Test func spec095ArchiveCardsHideRetiredEditorsForExistingProfiles() throws {
  let profile = StudentDemoSeed.makeOnboardingProfile(studentID: StudentDemoSeed.studentID)
  let repo = InMemoryOnboardingRepository(studentId: profile.userId, seed: profile)
  let model = MyProfileViewModel(studentId: profile.userId, repo: repo)
  let view = ProfileCardsSection(profile: profile, viewModel: model)
  let links = try view.inspect().findAll(ViewType.NavigationLink.self)
  #expect(links.count == 5)
  for key: StudentStrings.Key in [
    .profileCardsSection004, .profileCardsSection005, .profileCardsSection006,
  ] {
    #expect(throws: (any Error).self) {
      try view.inspect().find(text: StudentStrings.localized(key))
    }
  }
}
