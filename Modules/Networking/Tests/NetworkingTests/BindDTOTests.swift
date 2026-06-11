import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import Networking

// MARK: - Decode fixtures (wire shapes verbatim from backend spec 005 / handlers)

@Test func inviteCodeDTODecodesBackendWireShape() throws {
  let json = """
    {
      "id": "a1000000-0000-0000-0000-000000000001",
      "coach_id": "a1000000-0000-0000-0000-000000000002",
      "code": "XK7MPQ2RVT",
      "type": "time_limited",
      "max_uses": null,
      "used_count": 2,
      "expires_at": "2026-06-18T08:00:00.000Z",
      "revoked_at": null,
      "label": "馆活动周",
      "created_at": "2026-06-11T08:00:00.000Z"
    }
    """

  let dto = try MeetPRCodec.decoder.decode(InviteCodeDTO.self, from: Data(json.utf8))
  let domain = dto.toDomain()

  #expect(domain.code == "XK7MPQ2RVT")
  #expect(domain.type == .timeLimited)
  #expect(domain.maxUses == nil)
  #expect(domain.usedCount == 2)
  #expect(domain.expiresAt != nil)
  #expect(domain.revokedAt == nil)
  #expect(domain.label == "馆活动周")
}

@Test func inviteCodesResponseDecodesListEnvelope() throws {
  let json = """
    {
      "invite_codes": [
        {
          "id": "a1000000-0000-0000-0000-000000000001",
          "coach_id": "a1000000-0000-0000-0000-000000000002",
          "code": "ABCDEFGHJK",
          "type": "personal_permanent",
          "max_uses": null,
          "used_count": 23,
          "expires_at": null,
          "revoked_at": null,
          "label": null,
          "created_at": "2026-06-11T08:00:00.000Z"
        },
        {
          "id": "a1000000-0000-0000-0000-000000000003",
          "coach_id": "a1000000-0000-0000-0000-000000000002",
          "code": "MNPQRSTUVW",
          "type": "single_use",
          "max_uses": 1,
          "used_count": 1,
          "expires_at": null,
          "revoked_at": "2026-06-12T08:00:00.000Z",
          "label": "给小明",
          "created_at": "2026-06-10T08:00:00.000Z"
        }
      ]
    }
    """

  let dto = try MeetPRCodec.decoder.decode(InviteCodesResponseDTO.self, from: Data(json.utf8))

  #expect(dto.inviteCodes.count == 2)
  #expect(dto.inviteCodes[0].type == .personalPermanent)
  #expect(dto.inviteCodes[1].maxUses == 1)
  #expect(dto.inviteCodes[1].revokedAt != nil)
}

@Test func bindRequestDTODecodesNullableJoinFields() throws {
  let json = """
    {
      "id": "b1000000-0000-0000-0000-000000000001",
      "student_id": "b1000000-0000-0000-0000-000000000002",
      "coach_id": "b1000000-0000-0000-0000-000000000003",
      "coach_display_name": null,
      "invite_code_id": null,
      "status": "pending",
      "submitted_at": "2026-06-11T08:00:00.000Z",
      "responded_at": null,
      "expired_at": "2026-06-18T08:00:00.000Z",
      "skip_evaluation": false,
      "skip_reason": null
    }
    """

  let domain = try MeetPRCodec.decoder.decode(BindRequestDTO.self, from: Data(json.utf8))
    .toDomain()

  #expect(domain.coachDisplayName == nil)
  #expect(domain.inviteCodeId == nil)
  #expect(domain.status == .pending)
  #expect(domain.respondedAt == nil)
}

@Test func myBindRequestResponseDecodesNullAndValue() throws {
  let nullJson = #"{ "bind_request": null }"#
  let nullDTO = try MeetPRCodec.decoder.decode(
    MyBindRequestResponseDTO.self, from: Data(nullJson.utf8))
  #expect(nullDTO.bindRequest == nil)

  let valueJson = """
    {
      "bind_request": {
        "id": "b1000000-0000-0000-0000-000000000001",
        "student_id": "b1000000-0000-0000-0000-000000000002",
        "coach_id": "b1000000-0000-0000-0000-000000000003",
        "coach_display_name": "David",
        "invite_code_id": "b1000000-0000-0000-0000-000000000004",
        "status": "accepted",
        "submitted_at": "2026-06-11T08:00:00.000Z",
        "responded_at": "2026-06-12T08:00:00.000Z",
        "expired_at": "2026-06-18T08:00:00.000Z",
        "skip_evaluation": true,
        "skip_reason": "线下老学员",
        "created_at_extra_ignored": null
      }
    }
    """
  let valueDTO = try MeetPRCodec.decoder.decode(
    MyBindRequestResponseDTO.self, from: Data(valueJson.utf8))
  #expect(valueDTO.bindRequest?.coachDisplayName == "David")
  #expect(valueDTO.bindRequest?.status == .accepted)
  #expect(valueDTO.bindRequest?.skipEvaluation == true)
}

// MARK: - Encode fixtures (request bodies, field names verbatim)

@Test func createBindRequestBodyEncodesSnakeCaseFieldNames() throws {
  let body = CreateBindRequestRequestDTO(code: "XK7MPQ2RVT", displayName: "张三")
  let json = try jsonString(body)

  #expect(json.contains(#""code":"XK7MPQ2RVT""#))
  #expect(json.contains(#""display_name":"张三""#))
}

@Test func createInviteCodeBodyOmitsAbsentOptionals() throws {
  let personal = CreateInviteCodeRequestDTO(
    type: .personalPermanent, label: nil, expiresInDays: nil)
  let personalJSON = try jsonString(personal)
  #expect(personalJSON == #"{"type":"personal_permanent"}"#)

  let timeLimited = CreateInviteCodeRequestDTO(
    type: .timeLimited, label: "馆活动周", expiresInDays: 7)
  let timeLimitedJSON = try jsonString(timeLimited)
  #expect(timeLimitedJSON.contains(#""expires_in_days":7"#))
  #expect(timeLimitedJSON.contains(#""label":"馆活动周""#))
  #expect(timeLimitedJSON.contains(#""type":"time_limited""#))
}

// MARK: - Error envelope machine codes (spec 031 §3)

@Test func bindErrorMapsAllFiveMachineCodes() {
  let cases: [(String, BindRequestError)] = [
    ("INVITE_CODE_INVALID", .invalidCode),
    ("BIND_REQUEST_ALREADY_PENDING", .alreadyPending),
    ("BIND_ALREADY_BOUND", .alreadyBound),
    ("BIND_REQUEST_NOT_PENDING", .notPending),
    ("BIND_REQUEST_NOT_FOUND", .notFound),
    ("INVITE_CODE_NOT_FOUND", .notFound),
  ]
  for (code, expected) in cases {
    let error = APIError.httpStatus(400, Data(#"{"error":"\#(code)"}"#.utf8))
    let machineCode = BackendErrorEnvelope.machineCode(from: error)
    #expect(BindRequestError(machineCode: machineCode) == expected)
  }
}

@Test func bindErrorIsNilForUnknownCodeAndTransportErrors() {
  let unknown = APIError.httpStatus(500, Data(#"{"error":"SOMETHING_ELSE"}"#.utf8))
  #expect(BindRequestError(machineCode: BackendErrorEnvelope.machineCode(from: unknown)) == nil)

  let nonEnvelope = APIError.httpStatus(502, Data("Bad Gateway".utf8))
  #expect(BackendErrorEnvelope.machineCode(from: nonEnvelope) == nil)

  #expect(BackendErrorEnvelope.machineCode(from: APIError.invalidResponse) == nil)
}

private func jsonString<Value: Encodable>(_ value: Value) throws -> String {
  String(bytes: try MeetPRCodec.encoder.encode(value), encoding: .utf8) ?? ""
}
