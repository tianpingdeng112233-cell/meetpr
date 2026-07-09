import CoreModels
import DesignSystem
import SwiftUI

/// Editing state of a solo session (spec 045): sets grouped by exercise,
/// rendered through the same SetRecordRow family as coached training so the
/// walkthrough-praised row interactions carry over unchanged.
@available(iOS 17.0, macOS 14.0, *)
struct SoloSessionView: View {
  @Bindable var viewModel: SoloSessionViewModel
  let catalog: [Exercise]
  var makeReviewViewModel: (() -> SessionReviewSubmitViewModel)?
  @State private var pickerPresented = false
  @State private var editingDraftID: UUID?
  @State private var plateMathWeightKg: Double?
  @State private var reviewPresented = false

  private var exerciseOrder: [UUID] {
    var seen: Set<UUID> = []
    return viewModel.drafts.compactMap { draft in
      seen.insert(draft.exerciseID).inserted ? draft.exerciseID : nil
    }
  }

  var body: some View {
    List {
      if viewModel.unsyncedCount > 0 {
        Section {
          Label("\(viewModel.unsyncedCount) 组未同步,恢复网络后自动上传", systemImage: "icloud.slash")
            .font(.footnote)
            .foregroundStyle(Color.MeetPR.fgSecondary)
        }
      }

      if viewModel.drafts.isEmpty, !viewModel.lastSessionDrafts.isEmpty {
        Section {
          Button {
            viewModel.repeatLastSession()
          } label: {
            VStack(alignment: .leading, spacing: 4) {
              Label("重复上次(\(viewModel.lastSessionDate ?? ""))", systemImage: "arrow.clockwise")
                .font(.headline)
              Text(lastSessionSummary)
                .font(.caption)
                .foregroundStyle(Color.MeetPR.fgSecondary)
            }
          }
          .accessibilityIdentifier("solo.repeatLast")
        }
      }

      ForEach(exerciseOrder, id: \.self) { exerciseID in
        exerciseSection(exerciseID)
      }

      Section {
        Button {
          pickerPresented = true
        } label: {
          Label(viewModel.drafts.isEmpty ? "选动作开始" : "加一个动作", systemImage: "plus.circle.fill")
            .font(.headline)
        }
        .accessibilityIdentifier("solo.addExercise")
      }

      if makeReviewViewModel != nil, viewModel.drafts.contains(where: \.completed) {
        Section {
          Button {
            reviewPresented = true
          } label: {
            Label("写一句今天的感受", systemImage: "square.and.pencil")
              .font(.subheadline)
          }
          .accessibilityIdentifier("solo.review")
        }
      }
    }
    .navigationTitle("今天 · \(viewModel.sessionDate)")
    #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
    #endif
    .sheet(isPresented: $pickerPresented) {
      ExercisePickerSheet(
        catalog: catalog,
        suggestions: viewModel.suggestions
      ) { exercise in
        viewModel.addExercise(exercise.id)
      }
    }
    .sheet(item: editingDraft) { draft in
      SoloSetEntrySheet(
        draft: draft,
        onSave: { weight, reps, rpe in
          viewModel.updateDraft(id: draft.id, weightKg: weight, reps: reps, rpe: rpe)
        },
        onCommit: { weight, reps, rpe, failed in
          viewModel.updateDraft(id: draft.id, weightKg: weight, reps: reps, rpe: rpe)
          Task { await viewModel.commit(id: draft.id, failed: failed) }
        }
      )
    }
    .sheet(item: plateMathTarget) { target in
      PlateMathSheet(targetKg: target.weightKg)
        .presentationDetents([.medium])
    }
    .sheet(isPresented: $reviewPresented) {
      if let makeReviewViewModel {
        SoloReviewSheet(viewModel: makeReviewViewModel())
          .presentationDetents([.medium])
      }
    }
    .overlay(alignment: .top) {
      if let banner = viewModel.pendingPRBanner {
        PRBanner(
          event: banner,
          exerciseName: viewModel.exerciseName(for: banner.exerciseId),
          onDismiss: {
            Task { await viewModel.acknowledgePendingPR() }
          }
        )
        .padding(.horizontal)
      }
    }
  }

  private struct PlateMathTarget: Identifiable {
    let weightKg: Double
    var id: Double { weightKg }
  }

  private var plateMathTarget: Binding<PlateMathTarget?> {
    Binding(
      get: { plateMathWeightKg.map(PlateMathTarget.init(weightKg:)) },
      set: { plateMathWeightKg = $0?.weightKg }
    )
  }

  private var lastSessionSummary: String {
    let names = Array(Set(viewModel.lastSessionDrafts.map(\.exerciseName))).sorted()
    return "\(names.joined(separator: " · ")) 共 \(viewModel.lastSessionDrafts.count) 组"
  }

  private var editingDraft: Binding<SoloSetDraft?> {
    Binding(
      get: {
        guard let editingDraftID else { return nil }
        return viewModel.drafts.first { $0.id == editingDraftID }
      },
      set: { newValue in
        editingDraftID = newValue?.id
      }
    )
  }

  @ViewBuilder
  private func exerciseSection(_ exerciseID: UUID) -> some View {
    let rows = viewModel.drafts.enumerated().filter { $0.element.exerciseID == exerciseID }
    Section(rows.first?.element.exerciseName ?? "动作") {
      ForEach(Array(rows.enumerated()), id: \.element.element.id) { position, indexed in
        SetRecordRow(
          draft: rowDraft(for: indexed.element),
          setNumber: position + 1,
          rowIndex: indexed.offset,
          onTap: { _ in
            editingDraftID = indexed.element.id
          },
          onPlateMath: { weight in
            plateMathWeightKg = weight
          }
        )
      }
      Button {
        viewModel.addSet(for: exerciseID)
      } label: {
        Label("加一组", systemImage: "plus")
          .font(.subheadline)
      }
      .accessibilityIdentifier("solo.addSet.\(exerciseID.uuidString)")
    }
  }

  /// Adapter into the coached row renderer: solo has no prescription, so the
  /// synthesized PrescribedSet stays empty (target line hides) and the
  /// exercise id stands in for the plan-slot id — it never leaves this view.
  private func rowDraft(for draft: SoloSetDraft) -> TodayWorkoutSetRowDraft {
    TodayWorkoutSetRowDraft(
      id: draft.id,
      planExerciseID: draft.exerciseID,
      exerciseID: draft.exerciseID,
      exerciseName: draft.exerciseName,
      prescribed: PrescribedSet(
        id: draft.id,
        setIndex: draft.committedSetIndex ?? 0,
        weightKg: nil,
        reps: nil,
        repsMax: nil,
        rpe: nil,
        restSeconds: nil,
        coachNote: nil
      ),
      actualWeight: draft.weightKg,
      actualReps: draft.reps,
      actualRPE: draft.rpe,
      completed: draft.completed,
      failed: draft.failed
    )
  }
}
