import CoreModels
import DesignSystem
import SwiftUI

@MainActor
@available(iOS 17.0, macOS 14.0, *)
public struct AccessoryMatchListSection: View {
  private let exercises: [Exercise]
  private let selectedExerciseIDs: Set<UUID>
  private let isLoading: Bool
  private let onToggle: @MainActor (Exercise) -> Void

  @State private var searchText = ""

  public init(
    exercises: [Exercise],
    selectedExerciseIDs: Set<UUID>,
    isLoading: Bool,
    onToggle: @escaping @MainActor (Exercise) -> Void
  ) {
    self.exercises = exercises
    self.selectedExerciseIDs = selectedExerciseIDs
    self.isLoading = isLoading
    self.onToggle = onToggle
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
                onToggle(exercise)
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
  /// Toggles: adds when unselected, removes when selected (David 2026-06-14
  /// — a wrong pick must be reversible from inside the library).
  let onToggle: @MainActor () -> Void

  var body: some View {
    Button(action: onToggle) {
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

        // Selected → tappable minus so it reads as "added, tap to remove".
        Image(systemName: isSelected ? "minus.circle.fill" : "plus.circle.fill")
          .font(Font.MeetPR.headline)
          .foregroundStyle(isSelected ? Color.MeetPR.fgTertiary : Color.MeetPR.brandRed)
      }
      .padding(MeetPRSpacing.md)
      .background(Color.MeetPR.surface2)
      .clipShape(.rect(cornerRadius: MeetPRRadius.md))
    }
    .buttonStyle(.plain)
    .accessibilityLabel(isSelected ? "移除 \(exercise.name)" : "添加 \(exercise.name)")
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
