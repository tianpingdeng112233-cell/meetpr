import ChatUI
import CoreModels
import DesignSystem
import SwiftUI

struct StudentAddedHistoryRows: View {
  let logs: [StudentAddedSetLog]
  let catalog: [Exercise]
  @Environment(CompletedVideoReplayModel.self) private var replay: CompletedVideoReplayModel?

  var body: some View {
    let groups = Dictionary(grouping: logs, by: \.exerciseID)
    ForEach(groups.keys.sorted { $0.uuidString < $1.uuidString }, id: \.self) { id in
      let reservesVideoSpace = TrainingHistoryVideoPresentation.reservesVideoSpace(
        setLogIDs: (groups[id] ?? []).map(\.id),
        videos: replay?.videos ?? [], local: replay?.local ?? [])
      VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
        Divider().overlay(Color.MeetPR.borderDefault)
        HStack {
          Text(catalog.first(where: { $0.id == id }).map { StudentExerciseName.display($0) } ?? "—")
            .font(.MeetPR.body(size: MeetPRFontMetrics.size13, weight: .bold))
            .foregroundStyle(Color.MeetPR.textPrimary)
          Text(StudentStrings.localized(.addedAdded))
            .font(.MeetPR.body(size: MeetPRFontMetrics.size11))
            .foregroundStyle(Color.MeetPR.textMuted)
        }
        ForEach((groups[id] ?? []).sorted { $0.setIndex < $1.setIndex }) { log in
          HistorySetRow(
            label: HistoryEntriesView.setLabel(forZeroBasedIndex: log.setIndex),
            result: StudentFormatting.result(weightKg: log.weightKg, reps: log.reps, rpe: log.rpe),
            completed: log.completed, setLogID: log.id, setIndex: log.setIndex,
            reservesVideoSpace: reservesVideoSpace,
            badge: VideoBadgeInfo(
              exerciseName: catalog.first(where: { $0.id == id }).map {
                StudentExerciseName.display($0)
              },
              weightKg: NSDecimalNumber(decimal: log.weightKg).doubleValue, reps: log.reps,
              rpe: log.rpe.map { NSDecimalNumber(decimal: $0).doubleValue },
              setOrdinal: log.setIndex + 1)
          )
        }
      }
      .modifier(CompletedVideoHitRouting())
    }
  }
}
