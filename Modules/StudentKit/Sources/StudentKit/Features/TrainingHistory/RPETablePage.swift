import CoreModels
import DesignSystem
import SwiftUI

struct RPETableSnapshot: Sendable {
  let e1RM: [LiftFamily: Double]
  let unit: UnitPreference
  let defaultFamily: LiftFamily
}

struct RPETablePage: View {
  let model: ProgressDataModel
  @State private var snapshot: RPETableSnapshot?
  @State private var family: LiftFamily? = .squat
  @State private var failed = false
  @ScaledMetric(relativeTo: .caption) private var cellWidth = 56.0
  @ScaledMetric(relativeTo: .caption) private var cellHeight = 34.0

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: MeetPRSpacing.space3) {
        Picker(StudentStrings.localized(.rpeTableTitle), selection: $family) {
          ForEach(CycleOutlook.families, id: \.self) { lift in
            Text(lift.studentDisplayName).tag(Optional(lift))
          }
          Text("%").tag(Optional<LiftFamily>.none)
        }
        .pickerStyle(.segmented)
        if let snapshot {
          let value = family.flatMap { snapshot.e1RM[$0] }
          HStack(alignment: .firstTextBaseline, spacing: MeetPRSpacing.space2) {
            Text(RPETable.headerText(e1RM: value, unit: snapshot.unit))
              .font(.MeetPR.display(size: MeetPRFontMetrics.size30, weight: .extraBold))
            Text(value == nil ? "1RM" : "e1RM · \(UnitDisplay.weightUnitSuffix(snapshot.unit))")
              .font(.caption).foregroundStyle(Color.MeetPR.textMuted)
          }
          let values = RPETable.values(e1RM: value, unit: snapshot.unit)
          HStack(spacing: MeetPRSpacing.zero) {
            RPETableColumn(
              values: [StudentStrings.localized(.rpeTableReps)] + (1...12).map(String.init),
              width: cellWidth, height: cellHeight, isIndex: true)
            ScrollView(.horizontal) {
              HStack(spacing: MeetPRSpacing.zero) {
                ForEach(RPETable.efforts.indices, id: \.self) { column in
                  RPETableColumn(
                    values: ["@" + CycleOutlook.number(RPETable.efforts[column])]
                      + values.map { $0[column] }, width: cellWidth, height: cellHeight)
                }
              }
            }
            .scrollIndicators(.hidden)
          }
        } else if failed {
          ProgressRetryRow { Task { await load() } }
        } else {
          ProgressView().frame(maxWidth: .infinity)
        }
      }
      .padding(MeetPRSpacing.pageHorizontal)
    }
    .foregroundStyle(Color.MeetPR.textPrimary)
    .background(Color.MeetPR.bgBase)
    .navigationTitle(StudentStrings.localized(.rpeTableTitle))
    #if os(iOS)
      .toolbar(.visible, for: .navigationBar)
      .navigationBarTitleDisplayMode(.inline)
    #endif
    .task { await load() }
  }

  private func load() async {
    failed = false
    do {
      let result = try await model.rpeTableSnapshot()
      if snapshot == nil { family = result.defaultFamily }
      snapshot = result
    } catch { if !error.isTaskCancellation { failed = true } }
  }
}

private struct RPETableColumn: View {
  let values: [String]
  let width: CGFloat
  let height: CGFloat
  var isIndex = false

  var body: some View {
    VStack(spacing: MeetPRSpacing.zero) {
      ForEach(values.indices, id: \.self) { index in
        Text(values[index])
          .font(.caption.monospacedDigit())
          .foregroundStyle(
            isIndex || index == 0 ? Color.MeetPR.textMuted : Color.MeetPR.textSecondary
          )
          .frame(width: width, height: height)
          .background(
            index > 0 && index.isMultiple(of: 2) ? Color.MeetPR.bgStack : Color.MeetPR.bgBase)
      }
    }
  }
}
