import Testing

@testable import StudentKit

@Test("Recording lifecycle advances through explicit start and stop states")
func recorderLifecycleCompletesNormally() {
  var machine = readyRecorderStateMachine()

  guard let generation = machine.beginRecording() else {
    Issue.record("Expected recording to start from ready")
    return
  }
  #expect(machine.state == .starting(generation: generation))
  let didStart = machine.completeRecordingStart(generation: generation)
  #expect(didStart)
  #expect(machine.state == .recording(generation: generation))
  let stoppingGeneration = machine.beginStopping()
  #expect(stoppingGeneration == generation)
  #expect(machine.state == .stopping(generation: generation))
  let didStop = machine.completeStop(generation: generation)
  #expect(didStop)
  #expect(machine.state == .review)
}

@Test("Interrupting start invalidates its late completion and recording generation")
func recorderStartInterruptionInvalidatesLateCompletion() {
  var machine = readyRecorderStateMachine()
  guard let interruptedGeneration = machine.beginRecording() else {
    Issue.record("Expected recording to start from ready")
    return
  }

  let didInterrupt = machine.interruptActiveOperation()
  #expect(didInterrupt)
  #expect(machine.state == .failed)
  let staleStartCompleted = machine.completeRecordingStart(generation: interruptedGeneration)
  #expect(!staleStartCompleted)

  let didBeginPreparation = machine.beginPreparation()
  #expect(didBeginPreparation)
  let didPrepare = machine.completePreparation()
  #expect(didPrepare)
  guard let nextGeneration = machine.beginRecording() else {
    Issue.record("Expected recording to restart after preparation")
    return
  }
  #expect(nextGeneration > interruptedGeneration)
}

@Test("Writer failure during start enters failed and rejects the late start completion")
func recorderStartingFailureInvalidatesLateCompletion() {
  var machine = readyRecorderStateMachine()
  guard let generation = machine.beginRecording() else {
    Issue.record("Expected recording to start from ready")
    return
  }

  let didFail = machine.failActiveOperation(generation: generation)
  #expect(didFail)
  #expect(machine.state == .failed)

  let lateStartCompleted = machine.completeRecordingStart(generation: generation)
  #expect(!lateStartCompleted)
  #expect(machine.state == .failed)
}

@Test("Writer failure during recording enters failed")
func recorderRecordingFailureEntersFailed() {
  var machine = readyRecorderStateMachine()
  guard let generation = machine.beginRecording() else {
    Issue.record("Expected recording to start from ready")
    return
  }
  let didStart = machine.completeRecordingStart(generation: generation)
  #expect(didStart)

  let didFail = machine.failActiveOperation(generation: generation)
  #expect(didFail)
  #expect(machine.state == .failed)
}

@Test("Interrupting stop prevents its late result from entering review")
func recorderStopInterruptionInvalidatesLateCompletion() {
  var machine = readyRecorderStateMachine()
  guard let generation = machine.beginRecording() else {
    Issue.record("Expected recording to start from ready")
    return
  }
  let didStart = machine.completeRecordingStart(generation: generation)
  #expect(didStart)
  let stoppingGeneration = machine.beginStopping(expectedGeneration: generation)
  #expect(stoppingGeneration == generation)

  let didInterrupt = machine.interruptActiveOperation()
  #expect(didInterrupt)
  #expect(machine.state == .failed)
  let staleStopCompleted = machine.completeStop(generation: generation)
  #expect(!staleStopCompleted)
  #expect(machine.state == .failed)
}

@Test("A stale automatic-stop callback cannot stop a newer recording")
func staleAutomaticStopCannotStopNewRecording() {
  var machine = readyRecorderStateMachine()
  guard let staleGeneration = machine.beginRecording() else {
    Issue.record("Expected recording to start from ready")
    return
  }
  let didInterrupt = machine.interruptActiveOperation()
  #expect(didInterrupt)
  let didBeginPreparation = machine.beginPreparation()
  #expect(didBeginPreparation)
  let didPrepare = machine.completePreparation()
  #expect(didPrepare)
  guard let currentGeneration = machine.beginRecording() else {
    Issue.record("Expected a new recording generation")
    return
  }
  let didStart = machine.completeRecordingStart(generation: currentGeneration)
  #expect(didStart)

  let stoppingGeneration = machine.beginStopping(expectedGeneration: staleGeneration)
  #expect(stoppingGeneration == nil)
  #expect(machine.state == .recording(generation: currentGeneration))
}

@Test("Closing invalidates every in-flight recorder completion")
func closingRecorderInvalidatesCompletions() {
  var machine = readyRecorderStateMachine()
  guard let generation = machine.beginRecording() else {
    Issue.record("Expected recording to start from ready")
    return
  }

  machine.close()

  let staleStartCompleted = machine.completeRecordingStart(generation: generation)
  #expect(!staleStartCompleted)
  let staleFailureAccepted = machine.failActiveOperation(generation: generation)
  #expect(!staleFailureAccepted)
  #expect(machine.state == .closed)
}

@Test("Permission denial can re-enter preparation after Settings authorization")
func permissionDenialCanRecover() {
  var machine = RecorderStateMachine()
  machine.denyPermission()

  #expect(machine.state == .permissionDenied)
  let didBeginPreparation = machine.beginPreparation()
  #expect(didBeginPreparation)
  let didPrepare = machine.completePreparation()
  #expect(didPrepare)
  #expect(machine.state == .ready)
}

private func readyRecorderStateMachine() -> RecorderStateMachine {
  var machine = RecorderStateMachine()
  _ = machine.completePreparation()
  return machine
}
