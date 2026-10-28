import ChatUI
import CoreModels
import DesignSystem
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct HistorySetRow: View {
  let label: String
  let result: String
  let completed: Bool?
  let setLogID: UUID?
  let setIndex: Int
  let badge: VideoBadgeInfo
  let reservesVideoSpace: Bool
  @Environment(CompletedVideoReplayModel.self) private var replay: CompletedVideoReplayModel?

  init(
    set: PrescribedSet, exerciseName: String = "", log: StudentSetLog?,
    reservesVideoSpace: Bool = false
  ) {
    self.reservesVideoSpace = reservesVideoSpace
    setLogID = log?.id
    setIndex = set.setIndex
    badge = VideoBadgeInfo(
      exerciseName: exerciseName,
      weightKg: log.map { NSDecimalNumber(decimal: $0.weightKg).doubleValue },
      reps: log?.reps, rpe: log?.rpe.map { NSDecimalNumber(decimal: $0).doubleValue },
      setOrdinal: set.setIndex + 1)
    label = HistoryEntriesView.setLabel(forZeroBasedIndex: set.setIndex)
    result =
      log.map {
        StudentFormatting.result(weightKg: $0.weightKg, reps: $0.reps, rpe: $0.rpe)
      } ?? StudentFormatting.prescribed(set)
    completed = log?.completed
  }

  init(
    label: String, result: String, completed: Bool, setLogID: UUID? = nil, setIndex: Int = 0,
    reservesVideoSpace: Bool = false, badge: VideoBadgeInfo = VideoBadgeInfo()
  ) {
    self.reservesVideoSpace = reservesVideoSpace
    self.setLogID = setLogID
    self.setIndex = setIndex
    self.badge = badge
    self.label = label
    self.result = result
    self.completed = completed
  }

  var body: some View {
    HStack(spacing: MeetPRSpacing.space2) {
      Text(label)
        .font(.MeetPR.mono(size: MeetPRFontMetrics.size11, weight: .medium))
        .foregroundStyle(Color.MeetPR.textMuted)
      Spacer()
      Text(result)
        .font(
          .MeetPR.mono(size: MeetPRFontMetrics.size11, weight: completed == nil ? .medium : .bold)
        )
        .foregroundStyle(resultColor)
      let video = TrainingHistoryVideoPresentation(
        setLogID: setLogID, setIndex: setIndex, videos: replay?.videos ?? [],
        local: replay?.local ?? [])
      CompletedSetVideoButton(
        video: video.video, upload: replay?.uploadState(setLogID: setLogID), number: video.number,
        reservesSpace: reservesVideoSpace
      ) { replay?.open($0, badge: badge) }
    }
    .font(.MeetPR.mono(size: MeetPRFontMetrics.size11, weight: .medium))
  }

  private var resultColor: Color {
    guard let completed else { return Color.MeetPR.textMuted }
    return completed ? Color.MeetPR.success : Color.MeetPR.textSecondary
  }
}
