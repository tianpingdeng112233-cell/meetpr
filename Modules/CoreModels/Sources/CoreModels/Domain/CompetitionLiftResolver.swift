import Foundation

/// Mirrors the backend competition-lift resolver. Catalog data decides which
/// lift variants are stance-specific; onboarding decides which variants count
/// for this student.
public func resolveCompetitionFamily(
  exercise: Exercise,
  onboarding: OnboardingProfile?
) -> LiftFamily? {
  guard let family = exercise.mainLiftFamily else { return nil }
  guard let competitionStance = exercise.competitionStance else {
    return exercise.isCompetitionLift ? family : nil
  }

  let stance: String? =
    switch family {
    case .squat: onboarding?.squatStance?.rawValue
    case .deadlift: onboarding?.deadliftStyle?.rawValue
    case .bench: nil
    }
  guard let stance else { return family }
  if family == .deadlift, stance == DeadliftStance.both.rawValue {
    return family
  }
  return competitionStance.rawValue == stance ? family : nil
}
