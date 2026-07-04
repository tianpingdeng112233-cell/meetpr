import CatalogKit
import CoreModels
import DesignSystem
import SwiftUI

/// Exercise picker for solo sessions (spec 045): search across the shared
/// catalog with 最近/常用 shortcuts derived from the student's own history.
@available(iOS 17.0, macOS 14.0, *)
struct ExercisePickerSheet: View {
  let catalog: [Exercise]
  let suggestions: SoloExerciseSuggestions
  let onPick: (Exercise) -> Void
  @Environment(\.dismiss) private var dismiss
  @State private var query = ""

  private var catalogByID: [UUID: Exercise] {
    Dictionary(catalog.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
  }

  private var searchResults: [Exercise] {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return [] }
    return catalog.filter { ExerciseSearch.matches($0, query: trimmed) }
  }

  private func exercises(for ids: [UUID], limit: Int) -> [Exercise] {
    ids.compactMap { catalogByID[$0] }.prefix(limit).map { $0 }
  }

  var body: some View {
    NavigationStack {
      List {
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          let recent = exercises(for: suggestions.recent, limit: 8)
          if !recent.isEmpty {
            Section("最近练过") {
              ForEach(recent) { exercise in
                row(exercise)
              }
            }
          }
          let frequent = exercises(for: suggestions.frequent, limit: 8)
          if !frequent.isEmpty {
            Section("常用动作") {
              ForEach(frequent) { exercise in
                row(exercise)
              }
            }
          }
          Section("全部动作") {
            ForEach(catalog.sorted { $0.name < $1.name }) { exercise in
              row(exercise)
            }
          }
        } else {
          ForEach(searchResults) { exercise in
            row(exercise)
          }
        }
      }
      .searchable(text: $query, prompt: "搜索动作(中/英文)")
      .navigationTitle("选动作")
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
      #endif
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("取消") { dismiss() }
        }
      }
    }
  }

  private func row(_ exercise: Exercise) -> some View {
    Button {
      onPick(exercise)
      dismiss()
    } label: {
      VStack(alignment: .leading, spacing: 2) {
        Text(exercise.name)
          .foregroundStyle(Color.MeetPR.fgPrimary)
        if let nameEn = exercise.nameEn {
          Text(nameEn)
            .font(.caption)
            .foregroundStyle(Color.MeetPR.fgSecondary)
        }
      }
    }
    .accessibilityIdentifier("solo.picker.\(exercise.id.uuidString)")
  }
}
