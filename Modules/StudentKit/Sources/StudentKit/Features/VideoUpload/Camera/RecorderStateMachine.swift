enum RecorderLifecycleState: Equatable, Sendable {
  case preparing
  case ready
  case starting(generation: Int)
  case recording(generation: Int)
  case stopping(generation: Int)
  case review
  case permissionDenied
  case unavailable
  case failed
  case closed
}

/// Platform-neutral capture lifecycle. Generation checks prevent completions
/// from an interrupted start/finish task from reviving stale UI state.
struct RecorderStateMachine: Equatable, Sendable {
  private(set) var state: RecorderLifecycleState = .preparing
  private var nextGeneration = 0

  mutating func beginPreparation() -> Bool {
    guard state != .closed else { return false }
    state = .preparing
    return true
  }

  mutating func completePreparation() -> Bool {
    guard state == .preparing else { return false }
    state = .ready
    return true
  }

  mutating func denyPermission() {
    guard state != .closed else { return }
    state = .permissionDenied
  }

  mutating func markUnavailable() {
    guard state != .closed else { return }
    state = .unavailable
  }

  mutating func failPreparation() {
    guard state == .preparing else { return }
    state = .failed
  }

  mutating func beginRecording() -> Int? {
    guard state == .ready else { return nil }
    nextGeneration += 1
    state = .starting(generation: nextGeneration)
    return nextGeneration
  }

  mutating func completeRecordingStart(generation: Int) -> Bool {
    guard state == .starting(generation: generation) else { return false }
    state = .recording(generation: generation)
    return true
  }

  mutating func beginStopping(expectedGeneration: Int? = nil) -> Int? {
    guard case .recording(let generation) = state else { return nil }
    guard expectedGeneration == nil || expectedGeneration == generation else { return nil }
    state = .stopping(generation: generation)
    return generation
  }

  mutating func completeStop(generation: Int) -> Bool {
    guard state == .stopping(generation: generation) else { return false }
    state = .review
    return true
  }

  mutating func failActiveOperation(generation: Int) -> Bool {
    guard activeGeneration == generation else { return false }
    state = .failed
    return true
  }

  mutating func interruptActiveOperation() -> Bool {
    guard activeGeneration != nil else { return false }
    state = .failed
    return true
  }

  mutating func close() {
    state = .closed
  }

  var activeGeneration: Int? {
    switch state {
    case .starting(let generation), .recording(let generation), .stopping(let generation):
      generation
    default:
      nil
    }
  }
}
