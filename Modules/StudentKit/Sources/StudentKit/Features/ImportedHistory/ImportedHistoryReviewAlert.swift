import CoreModels
import SwiftUI

extension View {
  func importedHistoryReviewAlert(
    review: Binding<PendingImportedHistoryReview?>,
    onAnswer:
      @escaping @MainActor (
        PendingImportedHistoryReview,
        ImportedHistoryReviewDecision
      ) async -> Void
  ) -> some View {
    alert(
      "确认导入历史",
      isPresented: Binding(
        get: { review.wrappedValue != nil },
        set: { if !$0 { review.wrappedValue = nil } }
      ),
      presenting: review.wrappedValue
    ) { pending in
      Button("确实") {
        Task { await onAnswer(pending, .confirmed) }
      }
      Button("没有", role: .destructive) {
        Task { await onAnswer(pending, .rejected) }
      }
    } message: { pending in
      Text(importedHistoryReviewMessage(pending))
    }
  }

  private func importedHistoryReviewMessage(_ review: PendingImportedHistoryReview) -> String {
    "导入的历史记录里有 \(StudentFormatting.kilograms(review.sourceWeightKg))kg×"
      + "\(review.sourceReps)(约 e1RM "
      + "\(StudentFormatting.kilograms(review.sourceE1RMKg))kg),超过你填写的 1RM "
      + "\(StudentFormatting.kilograms(review.baseline1RMKg))kg——当时确实完成了吗?"
  }
}
