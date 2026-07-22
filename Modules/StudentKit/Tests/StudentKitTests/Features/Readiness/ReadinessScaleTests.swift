import Testing

@testable import StudentKit

@Test func readinessScaleCopyMatchesAllTwentyProductLabels() {
  let expected: [ReadinessScale: [String]] = [
    .sleepQuality: ["很差/几乎没睡", "较差", "一般", "较好", "睡得很好"],
    .energy: ["精疲力竭", "疲惫", "一般", "较有精力", "精力充沛"],
    .stress: ["压力很大", "有压力", "一般", "较放松", "很放松"],
    .mood: ["很差", "低落", "一般", "好", "很好"],
  ]

  #expect(ReadinessScale.allCases.count == 4)
  for scale in ReadinessScale.allCases {
    #expect(scale.labels.count == 5)
    #expect(scale.labels == expected[scale])
    for score in 1...5 {
      #expect(scale.label(for: score) == expected[scale]?[score - 1])
    }
  }
}

@Test func muscleSorenessCopyIncludesAllFourStoredSeverities() {
  let expected = ["轻微", "中等", "明显酸痛", "严重酸痛"]

  #expect(ReadinessMuscleSoreness.allCases.map(\.label) == expected)
  #expect(ReadinessMuscleSoreness.label(for: nil) == "完全无酸痛")
}

@Test func muscleSorenessCyclesThroughFourSeveritiesThenClears() {
  var severity: Int?
  let expected: [Int?] = [1, 2, 3, 4, nil]

  for next in expected {
    severity = ReadinessMuscleSoreness.nextSeverity(after: severity)
    #expect(severity == next)
  }
}
