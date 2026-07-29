import CoreModels
import Foundation

/// 拍板 3 froze the snapshot semantics carried by 「当前」, not the noun after it.
/// A planned set has no record, and calling it one would undo the point of keeping
/// performed and prescribed sets tellable apart.
enum SetRefConfirmationCopy {
  static func prompt(for source: SetRefSource) -> String {
    switch source {
    case .logged: ChatStrings.sendCurrentSetRecord
    case .planned: ChatStrings.sendCurrentSetPlan
    }
  }
}

enum SetRefPickerPage: Equatable {
  case selection
  case confirmation
}

struct SetRefPickerPresentation {
  private(set) var candidates: [SetRefShareCandidate] = []
  private(set) var selectedCandidateID: UUID?
  private(set) var page: SetRefPickerPage = .selection

  var selectedCandidate: SetRefShareCandidate? {
    guard let selectedCandidateID else { return nil }
    return candidates.first { $0.id == selectedCandidateID }
  }

  var loggedCandidates: [SetRefShareCandidate] {
    candidates.filter { $0.source.source == .logged }
  }

  var plannedCandidates: [SetRefShareCandidate] {
    candidates.filter { $0.source.source == .planned }
  }

  mutating func load(
    candidates: [SetRefShareCandidate],
    initialSetLogID: UUID?
  ) {
    self.candidates = candidates
    selectedCandidateID =
      initialSetLogID.flatMap { requestedID in
        candidates.contains { $0.id == requestedID } ? requestedID : nil
      } ?? candidates.first?.id
    page = .selection
  }

  mutating func select(_ setLogID: UUID) {
    guard candidates.contains(where: { $0.id == setLogID }) else { return }
    selectedCandidateID = setLogID
  }

  @discardableResult
  mutating func proceedToConfirmation() -> Bool {
    guard selectedCandidate != nil else { return false }
    page = .confirmation
    return true
  }

  mutating func showSelection() {
    page = .selection
  }
}
