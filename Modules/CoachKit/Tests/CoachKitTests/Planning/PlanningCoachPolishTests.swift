import CoreModels
import Foundation
import Testing

@testable import CoachKit

// MARK: - #1 editable percent presets

@available(iOS 17.0, macOS 14.0, *)
@Test func percentPresetsNormalizeClampDedupeSortCap() {
  #expect(WeightPercentPresets.normalized([80, 60, 80, 70]) == [60, 70, 80])
  #expect(WeightPercentPresets.normalized([0, 100, 50, 150, -3]) == [50])
  // > maxCount keeps the lowest 8 after sort.
  let many = Array(1...20)
  #expect(WeightPercentPresets.normalized(many).count == WeightPercentPresets.maxCount)
  // All-invalid falls back so the row is never empty.
  #expect(WeightPercentPresets.normalized([0, 200]) == WeightPercentPresets.fallback)
}

@available(iOS 17.0, macOS 14.0, *)
@Test func percentPresetStoreRoundTripsNormalized() {
  let suite = UserDefaults(suiteName: "test.percent.\(UUID().uuidString)")!
  let store = UserDefaultsWeightPercentPresetStore(defaults: suite)
  #expect(store.load() == WeightPercentPresets.fallback)
  store.save([82, 77, 82, 0])
  #expect(store.load() == [77, 82])
}

// MARK: - #2 已填 semantics

@available(iOS 17.0, macOS 14.0, *)
@Test func coachCompleteRequiresRealLoad() {
  func spec(mode: IntensityMode, value: Decimal, sets: Int = 4, reps: Int = 5) -> DraftSetSpec {
    DraftSetSpec(setCount: sets, targetReps: reps, intensityMode: mode, targetValue: value)
  }
  #expect(!spec(mode: .weight, value: 0).isCoachComplete)
  #expect(spec(mode: .weight, value: 100).isCoachComplete)
  #expect(spec(mode: .rpe, value: 8).isCoachComplete)
  #expect(!spec(mode: .rpe, value: 0).isCoachComplete)
  #expect(!spec(mode: .weight, value: 100, sets: 0).isCoachComplete)
  var inverted = spec(mode: .weight, value: 100)
  inverted.targetRepsMax = 3
  #expect(!inverted.isCoachComplete)
}

// MARK: - #5 student profile summary

@available(iOS 17.0, macOS 14.0, *)
private func profileFixture(
  squat: Decimal? = 180,
  competing: Bool? = true,
  injuryAreas: [InjuryArea] = [.lowerBack],
  note: String? = "右肩旧伤，卧推注意"
) -> OnboardingProfile {
  OnboardingProfile(
    userId: UUID(),
    gender: .male,
    heightCm: 178,
    weightKg: 84,
    squat1RMKg: squat,
    bench1RMKg: 120,
    deadlift1RMKg: 220,
    trainingDays: [.mon, .wed, .fri, .sat],
    gymTier: .commercial,
    equipmentOverrides: ["kettlebell"],
    injuryNotes: "右肩",
    injuryAreas: injuryAreas,
    isCompeting: competing,
    competitionDate: "2026-09-01",
    targetWeightClass: "IPF 83kg",
    noteToCoach: note,
    createdAt: Date(timeIntervalSince1970: 1_780_000_000),
    updatedAt: Date(timeIntervalSince1970: 1_780_000_000)
  )
}

@available(iOS 17.0, macOS 14.0, *)
@Test func profileSummaryFormatsKeyFields() {
  let profile = profileFixture()
  #expect(StudentProfileSummary.basics(profile) == "男 · 84kg · 178cm")
  #expect(StudentProfileSummary.oneRMs(profile) == "蹲 180 / 推 120 / 拉 220")
  #expect(StudentProfileSummary.trainingDays(profile) == "每周 4 天 (一·三·五·六)")
  #expect(StudentProfileSummary.gym(profile) == "商业健身房 · 额外器械 1 项")
  #expect(StudentProfileSummary.competition(profile) == "2026-09-01 · IPF 83kg")
  #expect(StudentProfileSummary.noteToCoach(profile) == "右肩旧伤，卧推注意")
}

@available(iOS 17.0, macOS 14.0, *)
@Test func profileSummaryReturnsNilForEmptyFields() {
  let profile = profileFixture(squat: nil, competing: false, injuryAreas: [], note: "   ")
  #expect(StudentProfileSummary.competition(profile) == nil)
  #expect(StudentProfileSummary.noteToCoach(profile) == nil)
  // oneRMs still has bench/deadlift, so it's non-nil but drops squat.
  #expect(StudentProfileSummary.oneRMs(profile) == "推 120 / 拉 220")
}

// MARK: - #4 completion issues

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func completionIssuesFlagsZeroWeightThenClearsWhenFilled() async throws {
  let viewModel = try await configuredViewModelForStep4()

  // Default specs carry weight 0 → every exercise reports 未设重量.
  let issues = viewModel.planCompletionIssues()
  #expect(!issues.isEmpty)
  #expect(issues.allSatisfy { $0.contains("未设重量") })

  // Fill every exercise with a real weight → no issues.
  for exercise in viewModel.sortedDraftExercises {
    var spec = viewModel.setSpec(for: exercise.id) ?? viewModel.defaultSetSpec(for: exercise)
    spec.intensityMode = .weight
    spec.targetValue = 100
    try await viewModel.updateW1SetSpec(spec, for: exercise.id)
  }
  #expect(viewModel.planCompletionIssues().isEmpty)
}
