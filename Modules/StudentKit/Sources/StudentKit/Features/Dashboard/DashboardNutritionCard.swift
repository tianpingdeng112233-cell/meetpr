import DesignSystem
import SwiftUI

struct DashboardNutritionCard: View {
  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
      HStack {
        Text(StudentStrings.localized(.nutritionTitle))
          .font(.MeetPR.body(size: MeetPRFontMetrics.size11))
        Spacer()
        Text(StudentStrings.localized(.nutritionSoon))
          .font(.MeetPR.body(size: MeetPRFontMetrics.size11))
          .padding(MeetPRSpacing.xs)
          .background(Color.MeetPR.bgInset, in: .capsule)
      }
      HStack(spacing: MeetPRSpacing.xs) {
        ForEach(0..<4) { index in
          VStack(spacing: MeetPRSpacing.xs) {
            Text(StudentStrings.localized(labels[index]))
            Text("— g")
          }
          .font(.MeetPR.body(size: MeetPRFontMetrics.size11))
          .frame(maxWidth: .infinity)
          .padding(.vertical, MeetPRSpacing.sm)
          .background(Color.MeetPR.bgInset, in: .rect(cornerRadius: MeetPRRadius.sm))
        }
      }
    }
    .foregroundStyle(Color.MeetPR.textSecondary)
    .padding(MeetPRSpacing.base)
    .background(Color.MeetPR.surfaceCard, in: .rect(cornerRadius: MeetPRRadius.card))
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(StudentStrings.localized(.nutritionAccessibility))
  }

  private let labels: [StudentStrings.Key] = [
    .nutritionCarbs, .nutritionProtein, .nutritionFat, .nutritionFiber,
  ]
}
