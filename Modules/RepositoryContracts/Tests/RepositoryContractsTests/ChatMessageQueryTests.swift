import Testing

@testable import RepositoryContracts

@Test func chatMessageQueryAcceptsLimitBoundaries() throws {
  let lower = try ChatMessageQuery.latest(limit: 1)
  let upper = try ChatMessageQuery.latest(limit: 100)

  #expect(lower.mode == .latest)
  #expect(lower.limit == 1)
  #expect(upper.limit == 100)
}

@Test func chatMessageQueryRejectsLimitOutsideBackendRange() {
  #expect(throws: ChatQueryValidationError.invalidLimit(0)) {
    try ChatMessageQuery.latest(limit: 0)
  }
  #expect(throws: ChatQueryValidationError.invalidLimit(101)) {
    try ChatMessageQuery.latest(limit: 101)
  }
}

@Test func chatMessageQueryAcceptsPositiveSequence() throws {
  let after = try ChatMessageQuery.after(seq: 1, limit: 30)
  let before = try ChatMessageQuery.before(seq: 1, limit: 30)

  #expect(after.mode == .after(seq: 1))
  #expect(before.mode == .before(seq: 1))
}

@Test func chatMessageQueryRejectsZeroSequence() {
  #expect(throws: ChatQueryValidationError.invalidSeq(0)) {
    try ChatMessageQuery.after(seq: 0, limit: 30)
  }
  #expect(throws: ChatQueryValidationError.invalidSeq(0)) {
    try ChatMessageQuery.before(seq: 0, limit: 30)
  }
}
