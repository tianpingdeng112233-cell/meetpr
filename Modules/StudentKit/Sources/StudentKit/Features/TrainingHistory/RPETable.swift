import CoreModels
import Foundation

enum RPETable {
  static let efforts = stride(from: 10.0, through: 6.0, by: -0.5).map { $0 }

  static func headerText(e1RM: Double?, unit: UnitPreference) -> String {
    guard let e1RM else { return "100%" }
    let kilograms = Decimal(e1RM)
    return StudentFormatting.decimal(unit == .kg ? kilograms : kilograms * UnitDisplay.lbPerKg)
  }

  static func values(e1RM: Double?, unit: UnitPreference) -> [[String]] {
    (1...12).map { reps in
      efforts.map { effort in
        guard let factor = CycleOutlook.intensity(reps: reps, rpe: effort) else { return "—" }
        guard let e1RM, e1RM.isFinite, e1RM > 0 else {
          return CycleOutlook.number((factor * 1000).rounded() / 10) + "%"
        }
        let unitFactor = unit == .kg ? 1 : NSDecimalNumber(decimal: UnitDisplay.lbPerKg).doubleValue
        let step = unit == .kg ? CycleOutlook.kgIncrement : CycleOutlook.lbIncrement
        return CycleOutlook.number(CycleOutlook.rounded(e1RM * factor * unitFactor, step: step))
      }
    }
  }

  static func defaultFamily(plan: StudentPlanView?, profile: OnboardingProfile?) -> LiftFamily {
    let families =
      plan?.days.flatMap(\.exercises).compactMap {
        resolveCompetitionFamily(exercise: $0.exercise, onboarding: profile)
      } ?? []
    return CycleOutlook.families.max { lhs, rhs in
      families.filter { $0 == lhs }.count < families.filter { $0 == rhs }.count
    } ?? .squat
  }
}
