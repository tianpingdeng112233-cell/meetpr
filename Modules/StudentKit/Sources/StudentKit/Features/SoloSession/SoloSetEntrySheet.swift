import CoreModels
import DesignSystem
import SwiftUI

/// Compact editor for one solo set: weight / reps / RPE plus the commit
/// action. Mirrors SetEntrySheet's essential controls without the plan/video
/// coupling (spec 045); plate math and rest timing stay with the coached
/// sheet until the shared extraction (U9 polish).
@available(iOS 17.0, macOS 14.0, *)
struct SoloSetEntrySheet: View {
  let draft: SoloSetDraft
  let onSave: (Decimal, Int, Decimal?) -> Void
  let onCommit: (Decimal, Int, Decimal?, Bool) -> Void
  @Environment(\.dismiss) private var dismiss

  @State private var weight: Decimal
  @State private var reps: Int
  @State private var rpe: Decimal

  init(
    draft: SoloSetDraft,
    onSave: @escaping (Decimal, Int, Decimal?) -> Void,
    onCommit: @escaping (Decimal, Int, Decimal?, Bool) -> Void
  ) {
    self.draft = draft
    self.onSave = onSave
    self.onCommit = onCommit
    self._weight = State(initialValue: draft.weightKg ?? 20)
    self._reps = State(initialValue: draft.reps ?? 5)
    self._rpe = State(initialValue: draft.rpe ?? 8)
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("重量 (kg)") {
          HStack {
            Button("-2.5") { weight = max(0, weight - Decimal(2.5)) }
              .buttonStyle(.bordered)
            TextField(
              "重量",
              value: $weight,
              format: .number
            )
            .multilineTextAlignment(.center)
            .font(.title2.monospacedDigit().bold())
            #if os(iOS)
              .keyboardType(.decimalPad)
            #endif
            Button("+2.5") { weight += Decimal(2.5) }
              .buttonStyle(.bordered)
          }
        }
        Section("次数") {
          Stepper(value: $reps, in: 0...99) {
            Text("\(reps) 次")
              .font(.title3.monospacedDigit())
          }
        }
        Section("RPE") {
          Stepper(
            value: $rpe,
            in: 5...10,
            step: 0.5
          ) {
            Text(StudentFormatting.decimal(rpe))
              .font(.title3.monospacedDigit())
          }
        }
        if draft.completed == false {
          Section {
            Button {
              onCommit(weight, reps, rpe, false)
              dismiss()
            } label: {
              Text("记录本组")
                .frame(maxWidth: .infinity)
                .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("solo.entry.commit")

            Button(role: .destructive) {
              onCommit(weight, reps, rpe, true)
              dismiss()
            } label: {
              Text("没做起来(失败)")
                .frame(maxWidth: .infinity)
            }
            .accessibilityIdentifier("solo.entry.fail")
          }
        }
      }
      .navigationTitle(draft.exerciseName)
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
      #endif
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("完成") {
            onSave(weight, reps, rpe)
            dismiss()
          }
        }
      }
    }
    .presentationDetents([.medium])
  }
}
