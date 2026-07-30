import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import StudentKit

@MainActor
private struct EnterCodeHarness {
  let viewModel: EnterCodeViewModel
  let repo: ScriptedBindRepository
  let stash: StashSpy
}

@MainActor
private func makeViewModel(
  submit: [ScriptedBindRepository.SubmitResult] = [],
  stash: StashSpy = StashSpy(),
  onboardingComplete: Bool = true,
  prefill: String? = nil
) -> EnterCodeHarness {
  let repo = ScriptedBindRepository(submit: submit)
  let viewModel = EnterCodeViewModel(
    studentId: BindFixtures.studentId,
    bind: repo,
    stash: stash,
    isOnboardingComplete: { onboardingComplete },
    prefillDisplayName: prefill,
    now: { BindFixtures.referenceDate }
  )
  return EnterCodeHarness(viewModel: viewModel, repo: repo, stash: stash)
}

// MARK: - Format validation (spec 031 D3/D11)

@MainActor
@Test func lowercaseAndSeparatorsNormalizeBeforeValidation() {
  let viewModel = makeViewModel().viewModel
  viewModel.codeInput = "xk7m pq2-rvt"
  viewModel.displayName = "张三"
  #expect(viewModel.normalizedCode == "XK7MPQ2RVT")
  #expect(viewModel.isSubmittable)
}

@MainActor
@Test func nineAndElevenCharCodesAreRejected() {
  let viewModel = makeViewModel().viewModel
  viewModel.displayName = "张三"
  viewModel.codeInput = "XK7MPQ2RV"
  #expect(!viewModel.isSubmittable)
  #expect(viewModel.codeFormatHint != nil)
  viewModel.codeInput = "XK7MPQ2RVTZ"
  #expect(!viewModel.isSubmittable)
}

@MainActor
@Test func foreignAlphabetCharsAreRejected() {
  let viewModel = makeViewModel().viewModel
  viewModel.displayName = "张三"
  for code in ["XK7MPQ2RV0", "XK7MPQ2RV1", "XK7MPQ2RVI", "XK7MPQ2RVO"] {
    viewModel.codeInput = code
    #expect(!viewModel.isSubmittable, "expected \(code) rejected")
  }
}

@MainActor
@Test func displayNameMustBeNonEmptyAfterTrim() {
  let viewModel = makeViewModel().viewModel
  viewModel.codeInput = "XK7MPQ2RVT"
  viewModel.displayName = "   "
  #expect(!viewModel.isSubmittable)
  viewModel.displayName = " 张三 "
  #expect(viewModel.isSubmittable)
  #expect(viewModel.trimmedDisplayName == "张三")
}

@MainActor
@Test func displayNameOver100CharsIsRejected() {
  let viewModel = makeViewModel().viewModel
  viewModel.codeInput = "XK7MPQ2RVT"
  viewModel.displayName = String(repeating: "名", count: 101)
  #expect(!viewModel.isSubmittable)
  viewModel.displayName = String(repeating: "名", count: 100)
  #expect(viewModel.isSubmittable)
}

@MainActor
@Test func prefillSeedsDisplayName() {
  let viewModel = makeViewModel(prefill: "张三").viewModel
  #expect(viewModel.displayName == "张三")
}

// MARK: - Submit branches (spec 031 §5)

@MainActor
@Test func incompleteOnboardingStashesInsteadOfPosting() async {
  let harness = makeViewModel(onboardingComplete: false)
  let viewModel = harness.viewModel
  let repo = harness.repo
  let stash = harness.stash
  viewModel.codeInput = "xk7mpq2rvt"
  viewModel.displayName = " 张三 "

  let outcome = await viewModel.submit()

  let expected = BindFixtures.pendingCode()
  #expect(outcome == .stashedForOnboarding(expected))
  #expect(stash.peek(studentId: BindFixtures.studentId) == expected)
  #expect(repo.submitCalls.isEmpty)
}

@MainActor
@Test func completeOnboardingPostsDirectly() async {
  let sent = BindFixtures.request(status: .pending)
  let harness = makeViewModel(submit: [.success(sent)])
  let viewModel = harness.viewModel
  viewModel.codeInput = "XK7MPQ2RVT"
  viewModel.displayName = "张三"

  let outcome = await viewModel.submit()

  #expect(outcome == .requestSent(sent))
  #expect(harness.repo.submitCalls.count == 1)
  #expect(harness.stash.peek(studentId: BindFixtures.studentId) == nil)
}

@MainActor
@Test func invalidCodeShowsFieldErrorAndWritesNoStash() async {
  let harness = makeViewModel(submit: [.failure(BindRequestError.invalidCode)])
  let viewModel = harness.viewModel
  viewModel.codeInput = "XK7MPQ2RVT"
  viewModel.displayName = "张三"

  let outcome = await viewModel.submit()

  #expect(outcome == nil)
  #expect(viewModel.fieldError == .invalidCode)
  #expect(
    viewModel.fieldError?.message
      == "这个码不存在或已过期。让教练在「我的」→「我的邀请码」里重新生成一个。"
  )
  #expect(viewModel.codeInput == "XK7MPQ2RVT")
  #expect(harness.stash.peek(studentId: BindFixtures.studentId) == nil)
}

@Test func clipboardPasteNormalizesValidCodeAndRejectsInvalidContent() {
  #expect(InviteCodePaste.validCode(from: "xk7m pq2-rvt") == "XK7MPQ2RVT")
  #expect(InviteCodePaste.validCode(from: "XK7MPQ2RV0") == nil)
  #expect(InviteCodePaste.validCode(from: "") == nil)
  #expect(InviteCodePaste.validCode(from: nil) == nil)
}

@MainActor
@Test func alreadyPendingAndBoundRequestReload() async {
  for error in [BindRequestError.alreadyPending, BindRequestError.alreadyBound] {
    let viewModel = makeViewModel(submit: [.failure(error)]).viewModel
    viewModel.codeInput = "XK7MPQ2RVT"
    viewModel.displayName = "张三"
    let outcome = await viewModel.submit()
    #expect(outcome == .needsReload)
  }
}

@MainActor
@Test func transportFailureShowsBannerAndStays() async {
  let viewModel = makeViewModel(submit: [.failure(TransportFailure())]).viewModel
  viewModel.codeInput = "XK7MPQ2RVT"
  viewModel.displayName = "张三"

  let outcome = await viewModel.submit()

  #expect(outcome == nil)
  #expect(viewModel.showsNetworkBanner)
}

@MainActor
@Test func submitIsNoOpWhileInvalid() async {
  let harness = makeViewModel()
  let viewModel = harness.viewModel
  let repo = harness.repo
  viewModel.codeInput = "BAD"
  viewModel.displayName = "张三"
  let outcome = await viewModel.submit()
  #expect(outcome == nil)
  #expect(repo.submitCalls.isEmpty)
}

// MARK: - Boxed-field input sanitising

/// `EnterCodeView.sanitized` is what stands between the boxed field and a code
/// that can never validate: without the alphabet filter a student could fill
/// all ten boxes with `O`s and get a permanently disabled button and no
/// explanation of why.
@Test func sanitizedUppercasesAndStripsSeparators() {
  #expect(EnterCodeView.sanitized("xk7m-pq2 rvt") == "XK7MPQ2RVT")
}

@Test func sanitizedDropsCharactersOutsideTheLockedAlphabet() {
  // I / O / 0 / 1 are excluded from the invite-code alphabet on purpose.
  #expect(EnterCodeView.sanitized("XKI7O0M1PQ2RVT") == "XK7MPQ2RVT")
  #expect(EnterCodeView.sanitized("!@#$%^") == "")
  #expect(EnterCodeView.sanitized("中文") == "")
}

@Test func sanitizedCapsAtTheCodeLength() {
  let overlong = EnterCodeView.sanitized("XK7MPQ2RVTZZZZ")

  #expect(overlong.count == InviteCodeFormat.length)
  #expect(overlong == "XK7MPQ2RVT")
}

@Test func sanitizedKeepsPartialInputIntact() {
  #expect(EnterCodeView.sanitized("xk7") == "XK7")
  #expect(EnterCodeView.sanitized("") == "")
}
