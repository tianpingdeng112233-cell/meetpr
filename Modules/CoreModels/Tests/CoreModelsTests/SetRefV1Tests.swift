import CoreModels
import Foundation
import Testing

@Suite struct SetRefV1Tests {
  @Test func goldenFixturesMatchCanonicalFormatterByteForByte() throws {
    let fixture = try loadSetRefGoldenFixture()
    let validCases = try #require(fixture["valid"] as? [[String: Any]])

    for validCase in validCases {
      let name = try #require(validCase["name"] as? String)
      let setRefObject = try #require(validCase["set_ref"] as? [String: Any])
      let expected = try #require(validCase["first_line"] as? String)
      let setRef = try decodeSetRef(setRefObject)

      #expect(
        SetRefCanonicalFormatter.firstLine(for: setRef) == expected,
        "Golden fixture mismatch: \(name)"
      )
    }
  }

  @Test func goldenInvalidCasesAreRejectedBeforeFormatting() throws {
    let fixture = try loadSetRefGoldenFixture()
    let validCases = try #require(fixture["valid"] as? [[String: Any]])
    let base = try #require(validCases.first?["set_ref"] as? [String: Any])
    let invalidCases = try #require(fixture["invalid"] as? [[String: Any]])

    for invalidCase in invalidCases {
      let name = try #require(invalidCase["name"] as? String)
      let patch = try #require(invalidCase["patch"] as? [String: Any])
      var candidate = base
      candidate.merge(patch) { _, new in new }

      #expect(throws: (any Error).self, "Expected golden rejection: \(name)") {
        try decodeSetRef(candidate)
      }
    }
  }

  @Test func goldenExerciseNameCodePointBoundariesAreEnforced() throws {
    let fixture = try loadSetRefGoldenFixture()
    let cases = try #require(
      fixture["exercise_name_code_point_boundaries"] as? [[String: Any]]
    )

    for boundaryCase in cases {
      let unit = try #require(boundaryCase["unit"] as? String)
      let repeatCount = try #require(boundaryCase["repeat"] as? Int)
      let isValid = try #require(boundaryCase["valid"] as? Bool)
      let name = String(repeating: unit, count: repeatCount)

      if isValid {
        _ = try makeSetRef(exerciseName: name)
      } else {
        #expect(throws: SetRefValidationError.invalidExerciseName) {
          try makeSetRef(exerciseName: name)
        }
      }
    }
  }

  @Test func sourceWireDecimalsNormalizeThroughIntegerMinorUnits() throws {
    let fixture = try loadSetRefGoldenFixture()
    let normalization = try #require(fixture["normalization"] as? [String: Any])
    let cases = try #require(normalization["cases"] as? [[String: Any]])

    for normalizationCase in cases {
      let field = try #require(normalizationCase["field"] as? String)
      let input = try #require(normalizationCase["input"] as? String)
      let canonical = try #require(normalizationCase["canonical"] as? String)

      switch field {
      case "weight_kg":
        let normalized = try SetRefV1.normalizingSource(sourceSnapshot(weightKg: input))
        #expect(normalized.weightKg == canonical)
      case "rpe":
        let normalized = try SetRefV1.normalizingSource(sourceSnapshot(rpe: input))
        #expect(normalized.rpe == canonical)
      default:
        Issue.record("Unknown normalization field: \(field)")
      }
    }
  }

  @Test func goldenInvalidExerciseNamesAreRejected() throws {
    let fixture = try loadSetRefGoldenFixture()
    let invalidNames = try #require(fixture["invalid_names"] as? [String])

    for name in invalidNames {
      #expect(throws: SetRefValidationError.invalidExerciseName) {
        try makeSetRef(exerciseName: name)
      }
    }
  }

  @Test func invalidSourcePrecisionAndRPEStepAreRejected() {
    #expect(throws: SetRefValidationError.invalidWeight("100.001")) {
      try SetRefV1.normalizingSource(
        sourceSnapshot(
          exerciseName: "深蹲",
          setNumber: 1,
          weightKg: "100.001",
          rpe: "8.5"
        )
      )
    }
    #expect(throws: SetRefValidationError.invalidRPE("8.3")) {
      try SetRefV1.normalizingSource(
        sourceSnapshot(
          exerciseName: "深蹲",
          setNumber: 1,
          weightKg: "100.00",
          rpe: "8.3"
        )
      )
    }
  }

  @Test func canonicalBodyAddsExactlyOneNewlineOnlyForNonemptyNote() throws {
    let setRef = try makeSetRef()
    let firstLine = SetRefCanonicalFormatter.firstLine(for: setRef)

    #expect(SetRefCanonicalFormatter.body(for: setRef, note: nil) == firstLine)
    #expect(SetRefCanonicalFormatter.body(for: setRef, note: "") == firstLine)
    #expect(
      SetRefCanonicalFormatter.body(for: setRef, note: "膝盖底部有点晃")
        == "\(firstLine)\n膝盖底部有点晃"
    )
  }

  @Test func encodingUsesStableCanonicalKeyOrderAndExplicitNulls() throws {
    let setRef = try makeSetRef(weightKg: nil, reps: nil, rpe: nil)
    let first = try encodedJSONString(setRef)
    let second = try encodedJSONString(setRef)

    #expect(first == second)
    let expected =
      #"{"day_date":"2026-07-27","exercise_name":"低杠位深蹲","reps":null,"rpe":null,"#
      + #""set_log_id":"70000000-0000-4000-8000-000000000001","set_number":3,"v":1,"#
      + #""weight_kg":null}"#
    #expect(
      first
        == expected
    )
  }
}

private let setLogID = UUID(
  uuid: (0x70, 0, 0, 0, 0, 0, 0x40, 0, 0x80, 0, 0, 0, 0, 0, 0, 1)
)

private func makeSetRef(
  exerciseName: String = "低杠位深蹲",
  weightKg: String? = "100",
  reps: Int? = 5,
  rpe: String? = "8.5"
) throws -> SetRefV1 {
  try SetRefV1(
    exerciseName: exerciseName,
    setNumber: 3,
    weightKg: weightKg,
    reps: reps,
    rpe: rpe,
    dayDate: "2026-07-27",
    setLogId: setLogID
  )
}

private func sourceSnapshot(
  exerciseName: String = "低杠位深蹲",
  setNumber: Int = 3,
  weightKg: String? = nil,
  reps: Int = 5,
  rpe: String? = nil
) -> SetRefSourceSnapshot {
  SetRefSourceSnapshot(
    exerciseName: exerciseName,
    setNumber: setNumber,
    weightKg: weightKg,
    reps: reps,
    rpe: rpe,
    dayDate: "2026-07-27",
    setLogId: setLogID
  )
}

private func loadSetRefGoldenFixture() throws -> [String: Any] {
  let repositoryRoot =
    URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
  let fixtureURL = repositoryRoot.appending(path: "set-ref-golden-fixtures.json")
  let data = try Data(contentsOf: fixtureURL)
  return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
}

private func decodeSetRef(_ object: [String: Any]) throws -> SetRefV1 {
  let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
  return try MeetPRCodec.decoder.decode(SetRefV1.self, from: data)
}
