import CoreModels
import DesignSystem
import Foundation
import Networking
import Testing
import ViewInspector

@testable import CoachKit

@MainActor
@Suite("Coach self-added detail")
struct CoachDayDetailPresentationTests {
  @Test func extraSetsStayOutsidePrescribedFractionAndAddedExercisesGroupByOwner() throws {
    let day = fixture()
    let presentation = CoachDayDetailPresentation(day: day)
    let planned = try #require(presentation.planned.first)
    #expect(planned.prescribed.map(\.setIndex) == [0, 2])
    #expect(planned.extra.map(\.setIndex) == [3, 4])
    #expect(planned.prescribed.count == 2)
    #expect(day.completedSetCount == 2)
    #expect(day.plannedSetCount == 3)
    #expect(presentation.added.count == 1)
    #expect(presentation.added.first?.logs.map(\.setIndex) == [0, 1])
  }

  @Test func rendersOneExtraGroupCaptionAndSeparateAddedCard() throws {
    let inspected = try CoachDayDetailView(day: fixture()).inspect()
    let caption = CoachLocalization.localized("coach.execution.addedByStudent")
    #expect(
      try inspected.findAll(ViewType.Text.self).filter { try $0.string() == caption }.count == 1)
    #expect(
      try inspected.find(
        text: CoachLocalization.localized(
          "coach.execution.studentAddedSets \(2)")
      ).string().isEmpty == false)
    #expect(
      try inspected.find(
        text: CoachLocalization.localized(
          "coach.execution.loggedSetsFraction \(2) \(3)")
      ).string().isEmpty == false)
    let rows = inspected.findAll(SetReadOnlyCell.self)
    #expect(rows.count == 6)
    for row in rows {
      #expect(try row.findAll(ViewType.Text.self).allSatisfy { try $0.string() != caption })
    }
  }

  @Test func unchangedPlannedOnlyDetailHasNoAddedCaption() throws {
    let sample = fixture()
    let day = StudentExecutionDay(
      date: sample.date, planDay: sample.planDay,
      allLogs: sample.allLogs.filter { $0.planExerciseID != nil && $0.setIndex < 3 },
      planDays: sample.planDays)
    let inspected = try CoachDayDetailView(day: day).inspect()
    let caption = CoachLocalization.localized("coach.execution.addedByStudent")
    #expect(try inspected.findAll(ViewType.Text.self).allSatisfy { try $0.string() != caption })
    #expect(inspected.findAll(SetReadOnlyCell.self).count == 2)
  }

  @Test func accessibleRowRetainsFullSetMetricsWithoutExtraLabel() throws {
    let log = try #require(fixture().allLogs.first { $0.setIndex == 4 })
    let inspected = try CoachSetReadOnlyRow(log: log, isAccessibilitySize: true).inspect()
    #expect(try inspected.find(text: "100 kg").string() == "100 kg")
    #expect(try inspected.find(text: "3").string() == "3")
    #expect(try inspected.find(text: "#5").string() == "#5")
    let caption = CoachLocalization.localized("coach.execution.addedByStudent")
    #expect(try inspected.findAll(ViewType.Text.self).allSatisfy { try $0.string() != caption })
  }

  func fixture() -> StudentExecutionDay {
    let sample = CoachStudentFeatureFixtures.exercise()
    let exercise = StudentPlanExercise(
      id: sample.id, exercise: sample.exercise, sequenceIndex: 0,
      prescribedSets: (0..<3).map {
        PrescribedSet(id: UUID(), setIndex: $0, weightKg: 100, reps: 3)
      })
    let planDay = StudentPlanDay(
      id: UUID(), weekNumber: 2, dayOfWeek: 4,
      date: CoachStudentFeatureFixtures.startDate, exercises: [exercise])
    let addedExerciseID = UUID()
    let planned = [4, 2, 3, 0].map { index in
      CoachSetLogDTO(
        id: UUID(), studentID: CoachStudentFeatureFixtures.studentID,
        planExerciseID: exercise.id, setIndex: index, weightKg: 100, reps: 3,
        completed: true, loggedAt: planDay.date)
    }
    let added = [1, 0].map { index in
      CoachSetLogDTO(
        id: UUID(), studentID: CoachStudentFeatureFixtures.studentID,
        planExerciseID: nil, planDayID: planDay.id, adhoc: true, exerciseID: addedExerciseID,
        setIndex: index, weightKg: 12.5, reps: 12, completed: true, loggedAt: planDay.date)
    }
    let unrelated = CoachSetLogDTO(
      id: UUID(), studentID: CoachStudentFeatureFixtures.studentID,
      planExerciseID: nil, planDayID: UUID(), adhoc: true, exerciseID: addedExerciseID,
      setIndex: 2, weightKg: 12.5, reps: 12, completed: true, loggedAt: planDay.date)
    return StudentExecutionDay(
      date: planDay.date, planDay: planDay,
      allLogs: planned + added + [unrelated], planDays: [planDay])
  }
}
