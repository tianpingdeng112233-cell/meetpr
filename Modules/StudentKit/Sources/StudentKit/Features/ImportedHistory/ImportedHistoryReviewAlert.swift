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
      StudentStrings.localized(.importedHistoryReviewAlert001),
      isPresented: Binding(
        get: { review.wrappedValue != nil },
        set: { if !$0 { review.wrappedValue = nil } }
      ),
      presenting: review.wrappedValue
    ) { pending in
      Button(StudentStrings.localized(.importedHistoryReviewAlert002)) {
        Task { await onAnswer(pending, .confirmed) }
      }
      Button(StudentStrings.localized(.importedHistoryReviewAlert003), role: .destructive) {
        Task { await onAnswer(pending, .rejected) }
      }
    } message: { pending in
      Text(importedHistoryReviewMessage(pending))
    }
  }

  private func importedHistoryReviewMessage(_ review: PendingImportedHistoryReview) -> String {
    StudentStrings.replacing(
      .importedHistoryReviewAlert004,
      values: ["\(StudentFormatting.kilograms(review.sourceWeightKg))"])
      + StudentStrings.replacing(.importedHistoryReviewAlert005, values: ["\(review.sourceReps)"])
      + StudentStrings.replacing(
        .importedHistoryReviewAlert006,
        values: ["\(StudentFormatting.kilograms(review.sourceE1RMKg))"])
      + StudentStrings.replacing(
        .importedHistoryReviewAlert007,
        values: ["\(StudentFormatting.kilograms(review.baseline1RMKg))"])
  }
}
