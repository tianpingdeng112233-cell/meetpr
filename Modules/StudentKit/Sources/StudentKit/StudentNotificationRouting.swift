import CoreModels
import Foundation

enum StudentTab: CaseIterable, Hashable {
  case training
  case coach
  case growth
  case profile
}

struct StudentTabShellPresentation: Equatable {
  struct Layer: Equatable, Identifiable {
    let id: StudentTab
    let opacity: Double
    let allowsHitTesting: Bool
    let isAccessibilityHidden: Bool
    let isEnabled: Bool
    let zIndex: Double
  }

  static let defaultTab: StudentTab = .training

  static func initialTrainingDay(in days: [StudentPlanDay], now: Date = Date()) -> UUID? {
    TrainingDayPresentation.completedToday(in: days, now: now)?.id
      ?? StudentPlanSequence(days: days).cursorDay?.id
      ?? StudentPlanSequence(days: days).orderedDays.last?.id
  }
  let selection: StudentTab
  var allowsCoach = true

  var tabs: [StudentTab] {
    StudentTab.allCases.filter { allowsCoach || $0 != .coach }
  }

  var layers: [Layer] {
    tabs.map(layer(for:))
  }

  func layer(for tab: StudentTab) -> Layer {
    let isSelected = selection == tab
    return Layer(
      id: tab,
      opacity: isSelected ? 1 : 0,
      allowsHitTesting: isSelected,
      isAccessibilityHidden: !isSelected,
      isEnabled: isSelected,
      zIndex: isSelected ? 1 : 0
    )
  }
}

enum StudentNotificationRoute: Hashable {
  case plan
  case coach

  static func route(for intent: PushRouteIntent) -> Self? {
    switch intent {
    case .planShifted, .planShiftUndone, .planUpdated, .planPublished:
      .plan
    case .chatMessage:
      .coach
    case .missedTraining, .prCongrats, .videoPending, .bindRequest, .bindAccepted,
      .planShift:
      nil
    }
  }

  func targetTab(from currentTab: StudentTab) -> StudentTab {
    switch self {
    case .plan: .training
    case .coach: .coach
    }
  }
}
