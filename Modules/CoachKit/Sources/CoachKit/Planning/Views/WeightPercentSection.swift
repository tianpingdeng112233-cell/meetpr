import DesignSystem
import SwiftUI

/// The editable quick-% row inside the weight calculator (David 2026-06-14:
/// "改成可以自己设置"). Display mode = one-tap chips that apply a % of the
/// selected base; edit mode = remove/add the presets, persisted via the
/// injected store. Lives in its own view so the panel stays under the file
/// length limit.
@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct WeightPercentSection: View {
  let onApply: @MainActor (Int) -> Void
  private let store: any WeightPercentPresetStoring

  @State private var percents: [Int]
  @State private var isEditing = false
  @State private var newPercentText = ""

  init(
    store: any WeightPercentPresetStoring = UserDefaultsWeightPercentPresetStore(),
    onApply: @escaping @MainActor (Int) -> Void
  ) {
    self.store = store
    self.onApply = onApply
    _percents = State(initialValue: store.load())
  }

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
      HStack {
        Text(
          isEditing
            ? CoachPlanningStrings.editCommonPercentages
            : CoachPlanningStrings.commonPercentages
        )
        .font(Font.MeetPR.caption)
        .foregroundStyle(Color.MeetPR.fgTertiary)
        Spacer()
        Button(isEditing ? CoachPlanningStrings.done : CoachPlanningStrings.edit) {
          isEditing.toggle()
        }
        .font(Font.MeetPR.footnote)
        .foregroundStyle(Color.MeetPR.brandRed)
      }

      if isEditing {
        editRow
      } else {
        applyRow
      }
    }
  }

  private var applyRow: some View {
    ScrollView(.horizontal) {
      HStack(spacing: MeetPRSpacing.sm) {
        ForEach(percents, id: \.self) { percent in
          Button("\(percent)%") {
            onApply(percent)
          }
          .buttonStyle(.bordered)
          .font(Font.MeetPR.footnote)
          .tint(Color.MeetPR.brandRed)
        }
      }
    }
    .scrollIndicators(.hidden)
  }

  private var editRow: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
      ScrollView(.horizontal) {
        HStack(spacing: MeetPRSpacing.sm) {
          ForEach(percents, id: \.self) { percent in
            Button {
              remove(percent)
            } label: {
              HStack(spacing: MeetPRSpacing.xs) {
                Text("\(percent)%")
                Image(systemName: "xmark.circle.fill")
              }
              .font(Font.MeetPR.footnote)
            }
            .buttonStyle(.bordered)
            .tint(Color.MeetPR.fgSecondary)
            .accessibilityLabel(CoachPlanningStrings.removePercentage(percent))
          }
        }
      }
      .scrollIndicators(.hidden)

      HStack(spacing: MeetPRSpacing.sm) {
        TextField(CoachPlanningStrings.newPercentage, text: $newPercentText)
          .planningPercentKeyboard()
          .font(Font.MeetPR.footnote)
          .frame(width: 64)
          .padding(.horizontal, MeetPRSpacing.sm)
          .padding(.vertical, MeetPRSpacing.xs)
          .background(Color.MeetPR.surface2)
          .clipShape(.rect(cornerRadius: MeetPRRadius.sm))
        Button(CoachPlanningStrings.add) { addNewPercent() }
          .font(Font.MeetPR.footnote)
          .buttonStyle(.bordered)
          .tint(Color.MeetPR.brandRed)
          .disabled(Int(newPercentText) == nil)
        Spacer()
        Button(CoachPlanningStrings.restoreDefaults) {
          update(WeightPercentPresets.fallback)
        }
        .font(Font.MeetPR.footnote)
        .foregroundStyle(Color.MeetPR.fgSecondary)
      }
    }
  }

  private func addNewPercent() {
    guard let value = Int(newPercentText) else { return }
    update(percents + [value])
    newPercentText = ""
  }

  private func remove(_ percent: Int) {
    update(percents.filter { $0 != percent })
  }

  private func update(_ raw: [Int]) {
    percents = WeightPercentPresets.normalized(raw)
    store.save(percents)
  }
}

extension View {
  @ViewBuilder
  fileprivate func planningPercentKeyboard() -> some View {
    #if os(iOS)
      keyboardType(.numberPad)
    #else
      self
    #endif
  }
}
