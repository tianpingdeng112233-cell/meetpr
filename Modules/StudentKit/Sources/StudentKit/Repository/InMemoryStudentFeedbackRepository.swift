import CoreModels
import Foundation
import RepositoryContracts

public actor InMemoryStudentFeedbackRepository: StudentFeedbackRepository {
  private var feedback: [CoachFeedback]
  private let now: @Sendable () -> Date

  public init(seed: [CoachFeedback] = [], now: @escaping @Sendable () -> Date = { Date() }) {
    self.feedback = seed
    self.now = now
  }

  public func fetchInbox(studentID: UUID) async throws -> [CoachFeedback] {
    feedback
      .filter { $0.studentID == studentID }
      .sorted { $0.postedAt > $1.postedAt }
  }

  public func postFeedback(
    studentID: UUID,
    dayDate: Date?,
    planExerciseID: UUID?,
    text: String
  ) async throws -> CoachFeedback {
    let item = CoachFeedback(
      id: UUID(),
      coachID: StudentDemoSeed.coachID,
      studentID: studentID,
      dayDate: dayDate,
      planExerciseID: planExerciseID,
      text: text,
      postedAt: now(),
      readAt: nil
    )
    feedback.append(item)
    return item
  }

  public func markRead(feedbackID: UUID) async throws {
    guard let index = feedback.firstIndex(where: { $0.id == feedbackID }) else {
      return
    }
    let item = feedback[index]
    guard item.readAt == nil else {
      return
    }
    feedback[index] = CoachFeedback(
      id: item.id,
      coachID: item.coachID,
      studentID: item.studentID,
      dayDate: item.dayDate,
      planExerciseID: item.planExerciseID,
      text: item.text,
      postedAt: item.postedAt,
      readAt: now()
    )
  }
}
