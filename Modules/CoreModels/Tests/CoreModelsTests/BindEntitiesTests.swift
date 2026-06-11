import CoreModels
import Foundation
import Testing

// MARK: - Vocabulary (verbatim against backend src/db/types.ts)

@Test func inviteCodeTypeVocabularyMatchesBackendVerbatim() {
  #expect(
    InviteCodeType.allCases.map(\.rawValue) == [
      "personal_permanent", "single_use", "time_limited",
    ])
}

@Test func bindRequestStatusVocabularyMatchesBackendVerbatim() {
  #expect(
    BindRequestStatus.allCases.map(\.rawValue) == [
      "pending", "accepted", "rejected", "expired", "cancelled",
    ])
}

// MARK: - Codable round trips

@Test func inviteCodeRoundTripPreservesAllFields() throws {
  let code = InviteCode(
    id: try fixtureUUID("40000000-0000-0000-0000-000000000011"),
    coachId: try fixtureUUID("40000000-0000-0000-0000-000000000012"),
    code: "XK7MPQ2RVT",
    type: .timeLimited,
    maxUses: nil,
    usedCount: 3,
    expiresAt: Date(timeIntervalSince1970: 1_780_000_000),
    revokedAt: nil,
    label: "馆活动周",
    createdAt: Date(timeIntervalSince1970: 1_779_000_000)
  )

  let json = try encodedJSONString(code)
  let decoded = try MeetPRCodec.decoder.decode(InviteCode.self, from: Data(json.utf8))

  #expect(decoded == code)
  #expect(json.contains(#""coach_id":"40000000-0000-0000-0000-000000000012""#))
  #expect(json.contains(#""used_count":3"#))
  #expect(json.contains(#""expires_at":"#))
}

@Test func bindRequestRoundTripPreservesNullableFields() throws {
  let request = BindRequest(
    id: try fixtureUUID("50000000-0000-0000-0000-000000000001"),
    studentId: try fixtureUUID("50000000-0000-0000-0000-000000000002"),
    coachId: try fixtureUUID("50000000-0000-0000-0000-000000000003"),
    coachDisplayName: nil,
    inviteCodeId: nil,
    status: .pending,
    submittedAt: Date(timeIntervalSince1970: 1_779_100_000),
    respondedAt: nil,
    expiredAt: Date(timeIntervalSince1970: 1_779_704_800)
  )

  let json = try encodedJSONString(request)
  let decoded = try MeetPRCodec.decoder.decode(BindRequest.self, from: Data(json.utf8))

  #expect(decoded == request)
  #expect(decoded.coachDisplayName == nil)
  #expect(decoded.inviteCodeId == nil)
  #expect(json.contains(#""skip_evaluation":false"#))
}

// MARK: - InviteCodeFormat (spec 031 D3/D11, coupled to backend spec 005 D4)

@Test func normalizeUppercasesAndStripsSeparators() {
  #expect(InviteCodeFormat.normalize("xk7m pq2-rvt") == "XK7MPQ2RVT")
  #expect(InviteCodeFormat.normalize(" xk7mpq2rvt ") == "XK7MPQ2RVT")
}

@Test func validAcceptsExactlyTenAlphabetChars() {
  #expect(InviteCodeFormat.isValid("XK7MPQ2RVT"))
  #expect(InviteCodeFormat.isValid("ABCDEFGHJK"))
}

@Test func validRejectsWrongLengthAndForeignChars() {
  #expect(!InviteCodeFormat.isValid("XK7MPQ2RV"))  // 9 chars
  #expect(!InviteCodeFormat.isValid("XK7MPQ2RVTZ"))  // 11 chars
  #expect(!InviteCodeFormat.isValid("XK7MPQ2RV0"))  // 0 excluded from alphabet
  #expect(!InviteCodeFormat.isValid("XK7MPQ2RVI"))  // I excluded
  #expect(!InviteCodeFormat.isValid("XK7MPQ2RVO"))  // O excluded
  #expect(!InviteCodeFormat.isValid("XK7MPQ2RV1"))  // 1 excluded
  #expect(!InviteCodeFormat.isValid("xk7mpq2rvt"))  // lowercase must be normalized first
  #expect(!InviteCodeFormat.isValid(""))
}

@Test func groupedRendersFourThreeThree() {
  #expect(InviteCodeFormat.grouped("XK7MPQ2RVT") == "XK7M PQ2 RVT")
  // Non-canonical lengths pass through untouched.
  #expect(InviteCodeFormat.grouped("ABC") == "ABC")
}
