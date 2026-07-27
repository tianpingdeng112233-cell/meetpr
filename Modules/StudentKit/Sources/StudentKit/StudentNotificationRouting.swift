enum StudentTab: CaseIterable, Hashable {
  case today
  case training
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

  let selection: StudentTab

  var layers: [Layer] {
    StudentTab.allCases.map(layer(for:))
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
