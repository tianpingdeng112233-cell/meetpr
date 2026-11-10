import DesignSystem
import SwiftUI

struct BodyWeightRecordsList: View {
  let records: [BodyWeightRecord]
  let deletingDate: String?
  let onDelete: (BodyWeightRecord) -> Void

  var body: some View {
    VStack(spacing: 0) {
      ForEach(records) { record in
        BodyWeightRecordRow(
          record: record, isDeleting: deletingDate == record.recordedOn,
          onDelete: { onDelete(record) }
        )
        .disabled(deletingDate != nil)
        if record.id != records.last?.id {
          Divider().overlay(Color.MeetPR.borderSubtle)
            .padding(.horizontal, MeetPRSpacing.space4)
        }
      }
    }
    .background(Color.MeetPR.surfaceCard, in: .rect(cornerRadius: MeetPRRadius.card))
  }
}

private struct BodyWeightRecordRow: View {
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  let record: BodyWeightRecord
  let isDeleting: Bool
  let onDelete: () -> Void

  private var dateLabel: String {
    DateOnly.date(from: record.recordedOn)?.formatted(date: .abbreviated, time: .omitted)
      ?? record.recordedOn
  }

  var body: some View {
    HStack(spacing: MeetPRSpacing.space2) {
      let layout =
        dynamicTypeSize.isAccessibilitySize
        ? AnyLayout(VStackLayout(alignment: .leading, spacing: MeetPRSpacing.space1))
        : AnyLayout(HStackLayout(spacing: MeetPRSpacing.space2))
      layout {
        Text(dateLabel)
          .font(.MeetPR.body(size: MeetPRFontMetrics.size14))
          .frame(maxWidth: .infinity, alignment: .leading)
        Text(BodyWeightInput.text(kg: record.weightKg, unit: .kg) + " kg")
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size14, weight: .semibold))
          .fixedSize(horizontal: true, vertical: false)
      }
      .foregroundStyle(Color.MeetPR.textPrimary)
      Button(action: onDelete) {
        if isDeleting { ProgressView() } else { Image(systemName: "trash") }
      }
      .frame(width: MeetPRSpacing.minimumHitTarget, height: MeetPRSpacing.minimumHitTarget)
      .foregroundStyle(Color.MeetPR.textMuted)
      .accessibilityLabel(StudentStrings.replacing(.bodyWeightDeleteLabel, values: [dateLabel]))
    }
    .padding(.leading, MeetPRSpacing.space4)
    .padding(.trailing, MeetPRSpacing.space2)
    .padding(.vertical, MeetPRSpacing.space1)
    .frame(minHeight: MeetPRSpacing.point52)
  }
}
