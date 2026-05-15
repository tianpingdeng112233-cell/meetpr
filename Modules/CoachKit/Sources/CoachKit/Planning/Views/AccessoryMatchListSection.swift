import CoreModels
import DesignSystem
import SwiftUI

@MainActor
@available(iOS 17.0, macOS 14.0, *)
public struct AccessoryMatchListSection: View {
  private let exercises: [Exercise]
  private let selectedExerciseIDs: Set<UUID>
  private let isLoading: Bool
  private let onAdd: @MainActor (Exercise) -> Void

  @State private var searchText = ""

  public init(
    exercises: [Exercise],
    selectedExerciseIDs: Set<UUID>,
    isLoading: Bool,
    onAdd: @escaping @MainActor (Exercise) -> Void
  ) {
    self.exercises = exercises
    self.selectedExerciseIDs = selectedExerciseIDs
    self.isLoading = isLoading
    self.onAdd = onAdd
  }

  public var body: some View {
    Card(accessibilityLabel: "Accessory matches") {
      VStack(alignment: .leading, spacing: MeetPRSpacing.md) {
        Text("匹配 \(filteredExercises.count) 个")
          .font(Font.MeetPR.headline)
          .foregroundStyle(Color.MeetPR.fgPrimary)

        HStack(spacing: MeetPRSpacing.sm) {
          Image(systemName: "magnifyingglass")
            .font(.footnote)
            .foregroundStyle(Color.MeetPR.fgSecondary)
          TextField("搜索 / Search", text: $searchText)
            .font(Font.MeetPR.body)
            .planningNoAutocapitalization()
            .autocorrectionDisabled(true)
          if !searchText.isEmpty {
            Button {
              searchText = ""
            } label: {
              Image(systemName: "xmark.circle.fill")
                .font(.footnote)
                .foregroundStyle(Color.MeetPR.fgSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("清空搜索")
          }
        }
        .padding(.horizontal, MeetPRSpacing.sm)
        .padding(.vertical, MeetPRSpacing.xs)
        .background(Color.MeetPR.surface2)
        .clipShape(.rect(cornerRadius: MeetPRRadius.sm))

        if isLoading {
          ProgressView("加载动作中")
            .font(Font.MeetPR.body)
        } else if filteredExercises.isEmpty {
          Text(searchText.isEmpty ? "没有匹配动作" : "没有符合搜索的动作")
            .font(Font.MeetPR.body)
            .foregroundStyle(Color.MeetPR.fgSecondary)
        } else {
          LazyVStack(spacing: MeetPRSpacing.sm) {
            ForEach(filteredExercises) { exercise in
              AccessoryMatchRow(
                exercise: exercise,
                isSelected: selectedExerciseIDs.contains(exercise.id)
              ) {
                onAdd(exercise)
              }
            }
          }
        }
      }
    }
  }

  private var filteredExercises: [Exercise] {
    let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty { return exercises }
    return exercises.filter { exercise in
      exercise.name.localizedStandardContains(trimmed)
        || (exercise.nameEn?.localizedStandardContains(trimmed) ?? false)
    }
  }
}

@MainActor
private struct AccessoryMatchRow: View {
  let exercise: Exercise
  let isSelected: Bool
  let onAdd: @MainActor () -> Void

  var body: some View {
    Button(action: onAdd) {
      HStack(alignment: .center, spacing: MeetPRSpacing.md) {
        VStack(alignment: .leading, spacing: MeetPRSpacing.xs) {
          Text(exercise.name)
            .font(Font.MeetPR.bodyEmphasis)
            .foregroundStyle(Color.MeetPR.fgPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)

          if let nameEn = exercise.nameEn, !nameEn.isEmpty {
            Text(nameEn)
              .font(Font.MeetPR.footnote)
              .foregroundStyle(Color.MeetPR.fgSecondary)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
        }

        Image(systemName: isSelected ? "checkmark.circle.fill" : "plus.circle.fill")
          .font(Font.MeetPR.headline)
          .foregroundStyle(isSelected ? Color.MeetPR.fgTertiary : Color.MeetPR.brandRed)
      }
      .padding(MeetPRSpacing.md)
      .background(Color.MeetPR.surface2)
      .clipShape(.rect(cornerRadius: MeetPRRadius.md))
    }
    .buttonStyle(.plain)
    .disabled(isSelected)
    .accessibilityLabel(isSelected ? "已添加 \(exercise.name)" : "添加 \(exercise.name)")
  }
}

extension View {
  @ViewBuilder
  fileprivate func planningNoAutocapitalization() -> some View {
    #if os(iOS)
      textInputAutocapitalization(.never)
    #else
      self
    #endif
  }
}
