import CoreModels
import Foundation

@testable import CoachKit

@available(iOS 17.0, macOS 14.0, *)
extension PlanningFixtures {
  static func studentWithoutOneRM() -> CoachStudentSummary {
    CoachStudentSummary(
      id: uuid(14),
      profile: StudentProfile(
        id: uuid(104),
        userID: uuid(14),
        trainingMode: .coached,
        trainingYears: 0,
        squatStance: .highBar,
        deadliftStance: .conventional,
        benchGrip: .standard,
        currentSquat1RM: Decimal(0),
        bench1RM: Decimal(0),
        deadlift1RM: Decimal(0),
        trainingDaysOfWeek: [2, 5],
        gymTier: .commercial,
        dailyIntensityLevel: 2,
        lifeStressLevel: 3,
        recoverySpeed: 3,
        sleepHours: 7,
        competitionTargeting: false,
        notesToCoach: "刚开始评估，暂不使用百分比强度。",
        createdAt: now,
        updatedAt: now
      ),
      displayName: "赵安然",
      status: .inEvaluation(remainingDays: 6, remainingHours: 2)
    )
  }
}
