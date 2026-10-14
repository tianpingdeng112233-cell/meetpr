import CoreModels
import DesignSystem
import SwiftUI

struct StudentAddedHistoryRows: View {
  let logs: [StudentAddedSetLog]
  let catalog: [Exercise]

  var body: some View {
    let groups = Dictionary(grouping: logs, by: \.exerciseID)
    ForEach(groups.keys.sorted { $0.uuidString < $1.uuidString }, id: \.self) { id in
      VStack(alignment: .leading, spacing: MeetPRSpacing.space2) {
        Divider()
        HStack {
          Text(catalog.first(where: { $0.id == id }).map { StudentExerciseName.display($0) } ?? "—")
            .font(.headline)
          Text(StudentStrings.localized(.addedAdded)).font(.caption)
            .foregroundStyle(Color.MeetPR.textMuted)
        }
        ForEach((groups[id] ?? []).sorted { $0.setIndex < $1.setIndex }) { log in
          HStack {
            Text(String(log.setIndex + 1))
            Text(StudentFormatting.decimal(log.weightKg) + " kg × " + String(log.reps))
            Spacer()
            if let rpe = log.rpe { Text("RPE " + StudentFormatting.decimal(rpe)) }
            if log.completed { Image(systemName: "checkmark") }
          }.font(.callout.monospacedDigit())
        }
      }
    }
  }
}
