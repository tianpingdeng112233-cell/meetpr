enum StudentTab: CaseIterable, Hashable {
  case today
  case training
  case growth
  case profile
}

enum StudentNotificationRoute: Hashable {
  case plan
  case feedback
  case evaluation
  case coachMessages

  func targetTab(from currentTab: StudentTab) -> StudentTab {
    switch self {
    case .plan: .training
    case .feedback: .growth
    case .evaluation: .today
    case .coachMessages: currentTab
    }
  }
}
