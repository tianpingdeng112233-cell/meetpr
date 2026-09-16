import CoreModels

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
  // The merged chat timeline (2026-07-27) absorbed the feedback/evaluation/
  // coach-message routes; plan is the only notification that still deep-links.
  case plan

  static func route(for intent: PushRouteIntent) -> Self? {
    switch intent {
    case .planShifted, .planShiftUndone, .planUpdated, .planPublished:
      .plan
    case .chatMessage, .missedTraining, .prCongrats, .videoPending, .bindRequest, .planShift:
      nil
    }
  }

  func targetTab(from currentTab: StudentTab) -> StudentTab {
    switch self {
    case .plan: .training
    }
  }
}
