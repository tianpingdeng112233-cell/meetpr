import CoreModels
import Foundation
import Testing

@testable import StudentKit

@MainActor
@Test func firstRunNewStudentSeesWelcomeThenContinuesOnce() async throws {
  let defaults = try #require(UserDefaults(suiteName: UUID().uuidString))
  let request = BindFixtures.request(
    status: .accepted, firstRun: .init(bindingPlanCount: 0, hasSettledDay: false))
  let repo = ScriptedBindRepository(mine: [.success(request), .success(request)])
  let gate = BindGateViewModel(
    studentId: BindFixtures.studentId, bind: repo, stash: StashSpy(),
    isOnboardingComplete: { true }, firstRunDefaults: defaults)
  await gate.load()
  #expect(gate.state == .welcome(request))
  gate.continueFromWelcome()
  #expect(gate.state == .bound(request))
  await gate.refresh()
  #expect(gate.state == .bound(request))
}

@MainActor
@Test func firstRunSettledStudentStaysBoundAndPersistsTerminal() async throws {
  let defaults = try #require(UserDefaults(suiteName: UUID().uuidString))
  let old = BindFixtures.request(
    status: .accepted, firstRun: .init(bindingPlanCount: 1, hasSettledDay: true))
  let unsettled = BindFixtures.request(
    status: .accepted, firstRun: .init(bindingPlanCount: 1, hasSettledDay: false))
  let gate = BindGateViewModel(
    studentId: BindFixtures.studentId,
    bind: ScriptedBindRepository(mine: [.success(old), .success(unsettled)]), stash: StashSpy(),
    isOnboardingComplete: { true }, firstRunDefaults: defaults)
  await gate.load()
  #expect(gate.state == .bound(old))
  await gate.refresh()
  #expect(gate.state == .bound(unsettled))
}

@MainActor
@Test func firstRunPendingAcceptanceOpensWelcomeWithPlanAlreadyPublished() async throws {
  let accepted = BindFixtures.request(
    status: .accepted,
    firstRun: .init(
      bindingPlanCount: 1, hasSettledDay: false,
      firstPlan: .init(
        id: UUID(), publishedAt: Date(), planWeeks: 4, dayCount: 12, hasSettledDay: false)))
  let gate = BindGateViewModel(
    studentId: BindFixtures.studentId,
    bind: ScriptedBindRepository(mine: [
      .success(BindFixtures.request(status: .pending)), .success(accepted),
    ]), stash: StashSpy(), isOnboardingComplete: { true },
    firstRunDefaults: try #require(UserDefaults(suiteName: UUID().uuidString)),
    pollingSleep: { _ in })
  await gate.load()
  await gate.pollPendingAcceptance()
  #expect(gate.state == .welcome(accepted))
  #expect(gate.acceptanceRevision == 1)
  gate.continueFromWelcome()
  #expect(DashboardTodayPresentation.firstPlan(in: gate.firstRun) == accepted.firstRun?.firstPlan)
}

@MainActor
@Test(arguments: [false, true])
func firstRunMissingOrNullDoesNotOpenWelcome(explicitNull: Bool) async throws {
  let request = BindFixtures.request(status: .accepted)
  let data = try JSONEncoder().encode(request)
  var json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
  if explicitNull { json["firstRun"] = NSNull() } else { json.removeValue(forKey: "firstRun") }
  let decoded = try JSONDecoder().decode(
    BindRequest.self, from: JSONSerialization.data(withJSONObject: json))
  let gate = BindGateViewModel(
    studentId: BindFixtures.studentId, bind: ScriptedBindRepository(mine: [.success(decoded)]),
    stash: StashSpy(), isOnboardingComplete: { true })
  await gate.load()
  #expect(gate.state == .bound(decoded))
  #expect(DashboardTodayPresentation.firstPlan(in: gate.firstRun) == nil)
}

@MainActor
@Test func firstRunFlagsPersistAndAreIsolatedByStudentAndBinding() throws {
  let defaults = try #require(UserDefaults(suiteName: UUID().uuidString))
  let request = BindFixtures.request(
    status: .accepted, firstRun: .init(bindingPlanCount: 0, hasSettledDay: false))
  let experience = BindFirstRunExperience(studentID: request.studentId, defaults: defaults)
  experience.update(request)
  experience.continueFromWelcome()
  experience.dismissPlan()
  let restored = BindFirstRunExperience(studentID: request.studentId, defaults: defaults)
  restored.update(request)
  #expect(!restored.showsWelcome)
  #expect(restored.planDismissed)
  let otherStudent = BindFirstRunExperience(studentID: UUID(), defaults: defaults)
  otherStudent.update(request)
  #expect(otherStudent.showsWelcome)
  #expect(!otherStudent.planDismissed)
  let rebound = BindRequest(
    id: UUID(), studentId: request.studentId, coachId: UUID(), status: .accepted,
    submittedAt: Date(), expiredAt: Date(), firstRun: request.firstRun)
  restored.update(rebound)
  #expect(restored.showsWelcome)
  #expect(!restored.planDismissed)
}

@Test(arguments: [
  ("王教练", "zh-Hans", "你现在是王教练的学员了"),
  ("王磊", "zh-Hans", "你现在是王磊教练的学员了"),
  ("", "zh-Hans", "你现在是教练的学员了"),
  ("Alex", "en", "You're now training with Alex"),
  ("  ", "en", "You're now training with your coach"),
])
func firstRunWelcomeTitleUsesSpecifiedNameRule(name: String, language: String, expected: String) {
  #expect(BindWelcomePresentation.title(name, locale: Locale(identifier: language)) == expected)
}

@MainActor
@Test func firstRunBackgroundRefreshKeepsBoundScreenOnTransportFailure() async {
  let accepted = BindFixtures.request(status: .accepted)
  let gate = BindGateViewModel(
    studentId: BindFixtures.studentId,
    bind: ScriptedBindRepository(mine: [.success(accepted), .failure(TransportFailure())]),
    stash: StashSpy(), isOnboardingComplete: { true })
  await gate.load()
  await gate.refreshFirstRun()
  #expect(gate.state == .bound(accepted))
  #expect(gate.firstRun.request == accepted)
}
