import DesignSystem
import Foundation
import SwiftUI

@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct TriageStripSection: View {
  let rows: [StudentRosterRowModel]
  let context: CoachStudentDetailContext
  let onEvaluationCompleted: (UUID) -> Void

  var body: some View {
    Section {
      ForEach(rows) { row in
        NavigationLink(
          destination: {
            StudentDetailView(
              summary: row.student,
              context: context,
              onEvaluationCompleted: {
                onEvaluationCompleted(row.student.id)
              }
            )
          },
          label: {
            TriageStripRow(row: row)
          }
        )
      }
    } header: {
      Text("今天 \(rows.count) 个需要你")
    }
  }
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
private struct TriageStripRow: View {
  let row: StudentRosterRowModel

  var body: some View {
    HStack(spacing: MeetPRSpacing.sm) {
      Circle()
        .fill(Color.MeetPR.amber)
        .frame(width: 8, height: 8)

      VStack(alignment: .leading, spacing: MeetPRSpacing.xs) {
        Text(row.student.displayName)
          .font(Font.MeetPR.bodyEmphasis)
          .foregroundStyle(Color.MeetPR.fgPrimary)
          .lineLimit(1)

        Text(StudentTriageSignalCalculator.summaryText(for: row.triageSignals))
          .font(Font.MeetPR.footnote)
          .foregroundStyle(Color.MeetPR.fgSecondary)
          .lineLimit(1)
      }
    }
    .padding(.vertical, MeetPRSpacing.xs)
    .accessibilityElement(children: .combine)
  }
}

#if DEBUG
  @MainActor
  @available(iOS 17.0, macOS 14.0, *)
  private enum TriageStripPreview {
    static var rows: [StudentRosterRowModel] {
      [
        StudentRosterRowModel(
          student: CoachStudentSummary(
            id: uuid(1),
            displayName: "王五",
            status: .active
          ),
          plannedTrainingDays: 4,
          completedTrainingDays: 1,
          lastActiveAt: nil,
          triageSignals: [.notTrained(daysMissed: 3)]
        ),
        StudentRosterRowModel(
          student: CoachStudentSummary(
            id: uuid(2),
            displayName: "李四",
            status: .active
          ),
          plannedTrainingDays: 3,
          completedTrainingDays: 2,
          lastActiveAt: Date(),
          triageSignals: [.awaitingReply]
        ),
      ]
    }

    static var context: CoachStudentDetailContext {
      let planRepository = InMemoryPlanRepository(students: [], catalog: [])
      let plans = EmptyStudentPlanRepository()
      let logs = EmptyStudentTrainingLogRepository()
      let feedback = EmptyStudentFeedbackRepository()
      return CoachStudentDetailContext(
        plans: plans,
        trainingLogs: logs,
        feedback: feedback,
        evaluations: InMemoryCoachEvaluationRepository(),
        summaries: InMemoryCoachEvaluationSummaryRepository(coachId: uuid(30)),
        profiles: InMemoryCoachStudentProfileReader(),
        videos: InMemoryCoachStudentVideoRepository(),
        readiness: EmptyReadinessRepository(),
        familyMapProvider: nil,
        planning: planRepository,
        draftStore: makeDraftStore()
      )
    }

    static func makeDraftStore() -> DraftStore {
      (try? DraftStore.inMemory()) ?? DraftStore.shared
    }

    static func uuid(_ byte: UInt8) -> UUID {
      UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, byte))
    }
  }

  #Preview("今日分诊条") {
    NavigationStack {
      List {
        TriageStripSection(
          rows: TriageStripPreview.rows,
          context: TriageStripPreview.context,
          onEvaluationCompleted: { _ in }
        )
      }
      .listStyle(.plain)
      .scrollContentBackground(.hidden)
      .background(Color.MeetPR.bg)
    }
  }
#endif
