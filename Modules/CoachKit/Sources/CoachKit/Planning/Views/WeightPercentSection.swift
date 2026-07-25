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
        Text(isEditing ? "编辑常用百分比" : "常用百分比")
          .font(Font.MeetPR.caption)
          .foregroundStyle(Color.MeetPR.textTertiary)
        Spacer()
        Button(isEditing ? "完成" : "编辑") {
          isEditing.toggle()
        }
        .font(Font.MeetPR.footnote)
        .foregroundStyle(Color.MeetPR.gold500)
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
          .tint(Color.MeetPR.gold500)
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
            .tint(Color.MeetPR.textSecondary)
            .accessibilityLabel("移除 \(percent)%")
          }
        }
      }
      .scrollIndicators(.hidden)

      HStack(spacing: MeetPRSpacing.sm) {
        TextField("新增 %", text: $newPercentText)
          .planningPercentKeyboard()
          .font(Font.MeetPR.footnote)
          .frame(width: 64)
          .padding(.horizontal, MeetPRSpacing.sm)
          .padding(.vertical, MeetPRSpacing.xs)
          .background(Color.MeetPR.surfaceElevated)
          .clipShape(.rect(cornerRadius: MeetPRRadius.sm))
        Button("添加") { addNewPercent() }
          .font(Font.MeetPR.footnote)
          .buttonStyle(.bordered)
          .tint(Color.MeetPR.gold500)
          .disabled(Int(newPercentText) == nil)
        Spacer()
        Button("恢复默认") {
          update(WeightPercentPresets.fallback)
        }
        .font(Font.MeetPR.footnote)
        .foregroundStyle(Color.MeetPR.textSecondary)
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
