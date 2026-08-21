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
        Text(CoachPlanningStrings.matchingExerciseCount(filteredExercises.count))
          .font(Font.MeetPR.headline)
          .foregroundStyle(Color.MeetPR.fgPrimary)

        HStack(spacing: MeetPRSpacing.sm) {
          Image(systemName: "magnifyingglass")
            .font(.footnote)
            .foregroundStyle(Color.MeetPR.fgSecondary)
          TextField(CoachPlanningStrings.search, text: $searchText)
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
            .accessibilityLabel(CoachPlanningStrings.clearSearch)
          }
        }
        .padding(.horizontal, MeetPRSpacing.sm)
        .padding(.vertical, MeetPRSpacing.xs)
        .background(Color.MeetPR.surface2)
        .clipShape(.rect(cornerRadius: MeetPRRadius.sm))

        if isLoading {
          ProgressView(CoachPlanningStrings.loadingExercises)
            .font(Font.MeetPR.body)
        } else if filteredExercises.isEmpty {
          Text(
            searchText.isEmpty
              ? CoachPlanningStrings.noMatchingExercises
              : CoachPlanningStrings.noSearchResults
          )
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
    return exercises.filter { ExerciseSearch.matches($0, query: trimmed) }
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
          Text(CoachLocalization.exerciseName(exercise))
            .font(Font.MeetPR.bodyEmphasis)
            .foregroundStyle(Color.MeetPR.fgPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
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
    .accessibilityLabel(
      isSelected
        ? CoachPlanningStrings.removeExerciseAccessibility(
          CoachLocalization.exerciseName(exercise)
        )
        : CoachPlanningStrings.addExerciseAccessibility(CoachLocalization.exerciseName(exercise))
    )
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
