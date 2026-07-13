import Analytics
import CoreModels
import Foundation
import Observation
import RepositoryContracts

@Observable
@MainActor
@available(iOS 17.0, macOS 14.0, *)
final class FeedbackComposerViewModel {
  enum SendState: Equatable, Sendable {
    case idle
    case sending
    case sent
    case failed(String)
  }

  let studentID: UUID
  var text = ""
  var selectedDayDate: Date?
  var selectedExerciseID: UUID?
  private(set) var state: SendState = .idle

  var canSend: Bool {
    !trimmedText.isEmpty && state != .sending
  }

  @ObservationIgnored private let repository: any StudentFeedbackRepository

  init(studentID: UUID, repository: any StudentFeedbackRepository) {
    self.studentID = studentID
    self.repository = repository
  }

  func selectDay(_ date: Date?) {
    selectedDayDate = date
    selectedExerciseID = nil
  }

  func selectExercise(_ id: UUID?) {
    selectedExerciseID = id
  }

  func reconcileExerciseSelection(days: [StudentPlanDay]) {
    guard let selectedExerciseID else { return }
    let available = availableExercises(days: days).map(\.id)
    if !available.contains(selectedExerciseID) {
      self.selectedExerciseID = nil
    }
  }

  func availableExercises(days: [StudentPlanDay]) -> [StudentPlanExercise] {
    guard let selectedDayDate else {
      return days.flatMap(\.exercises)
    }
    return
      days
      .first { CoachFeatureCalendar.isSameDay($0.date, selectedDayDate) }?
      .exercises ?? []
  }

  func send() async -> CoachFeedback? {
    guard canSend else {
      state = .failed("反馈不能为空")
      return nil
    }

    state = .sending
    do {
      let item = try await repository.postFeedback(
        studentID: studentID,
        dayDate: selectedDayDate,
        planExerciseID: selectedExerciseID,
        text: trimmedText
      )
      text = ""
      state = .sent
      Analytics.shared.coachFeedbackSent(studentID: studentID, kind: .text)
      return item
    } catch {
      state = .failed("发送失败，请稍后重试")
      return nil
    }
  }

  private var trimmedText: String {
    text.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
