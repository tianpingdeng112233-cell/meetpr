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

struct SetRefPickerPresentation: Sendable {
  private(set) var candidates: [SetRefShareCandidate] = []
  private(set) var selectedCandidateID: UUID?

  var selectedCandidate: SetRefShareCandidate? {
    guard let selectedCandidateID else { return nil }
    return candidates.first { $0.id == selectedCandidateID }
  }

  mutating func load(
    candidates: [SetRefShareCandidate],
    initialSetLogID: UUID?
  ) {
    self.candidates = candidates
    selectedCandidateID =
      initialSetLogID.flatMap { requestedID in
        candidates.contains { $0.id == requestedID } ? requestedID : nil
      }
  }

  mutating func select(_ setLogID: UUID) {
    guard candidates.contains(where: { $0.id == setLogID }) else { return }
    selectedCandidateID = setLogID
  }

}

struct SetRefPickerGroup: Identifiable, Sendable {
  let id: String
  let exerciseName: String
  let weekCode: String?
  var candidates: [SetRefShareCandidate]
}

struct SetRefPickerCell: Equatable, Sendable {
  let setLabel: String
  let load: String
  let status: String
}

extension SetRefPickerPresentation {
  var gridColumnCount: Int { 3 }
  var canSend: Bool { selectedCandidate != nil }

  var sendSummary: String? {
    selectedCandidate.map {
      ChatStrings.setRefSendSummary(
        setNumber: $0.source.setNumber, exerciseName: $0.source.exerciseName)
    }
  }

  var groups: [SetRefPickerGroup] {
    var result: [SetRefPickerGroup] = []
    for candidate in candidates.sorted(by: { $0.exerciseOrder < $1.exerciseOrder }) {
      let key =
        candidate.exerciseID?.uuidString
        ?? "\(candidate.source.dayDate)|\(candidate.source.exerciseName)"
      if let index = result.firstIndex(where: { $0.id == key }) {
        result[index].candidates.append(candidate)
      } else {
        result.append(
          SetRefPickerGroup(
            id: key, exerciseName: candidate.source.exerciseName,
            weekCode: candidate.weekCode, candidates: [candidate]))
      }
    }
    for index in result.indices {
      result[index].candidates.sort { $0.source.setNumber < $1.source.setNumber }
    }
    return result
  }

  func cell(for candidate: SetRefShareCandidate) -> SetRefPickerCell? {
    guard let setRef = try? SetRefV1.normalizingSource(candidate.source) else { return nil }
    let status: String
    if setRef.source == .planned {
      status = ChatStrings.setRefPlanned
    } else if let rpe = setRef.rpe {
      status = "\(ChatStrings.setRefLogged) · RPE \(rpe)"
    } else if candidate.video != nil {
      status = "\(ChatStrings.setRefLogged) · \(ChatStrings.setRefVideo)"
    } else {
      status = ChatStrings.setRefLogged
    }
    return SetRefPickerCell(
      setLabel: ChatStrings.setPosition(setRef.setNumber),
      load: ChatSetRefDisplayFormatter.load(for: setRef) ?? "—", status: status)
  }
}
