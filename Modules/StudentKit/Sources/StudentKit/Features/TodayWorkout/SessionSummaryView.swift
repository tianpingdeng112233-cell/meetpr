import DesignSystem
import Foundation
import SwiftUI

/// Post-session review, modeled on Juggernaut's workout summary: a completion
/// header, an Overview stat grid, a per-exercise Performance breakdown, and
/// free-text reflection prompts. Reflections are session-local for now (no
/// persistence yet).
@available(iOS 17.0, macOS 14.0, *)
struct SessionSummaryView: View {
  let summary: StudentSessionSummary
  let date: Date
  /// nil hides the review submit (demo/previews keep the old read-only shell).
  var reviewViewModel: SessionReviewSubmitViewModel?
  var isSolo = false

  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          SummaryHeader(date: date)
          SummarySection(title: "总览") {
            SummaryOverviewGrid(summary: summary)
          }
          if !summary.exercises.isEmpty {
            SummarySection(title: "动作表现") {
              SummaryPerformanceList(exercises: summary.exercises)
            }
          }
          SummarySection(title: "训练回顾") {
            if let reviewViewModel {
              SessionReviewSection(viewModel: reviewViewModel, isSolo: isSolo)
            } else {
              SummaryReflections()
            }
          }
        }
        .padding()
      }
      .scrollContentBackground(.hidden)
      .background(Color.MeetPR.bg)
      .navigationTitle("训练回顾")
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
      #endif
      .toolbar {
        Button("完成") { dismiss() }
          .foregroundStyle(Color.MeetPR.brandRed)
      }
    }
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct SummaryHeader: View {
  let date: Date

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: "checkmark.seal.fill")
        .font(.largeTitle)
        .foregroundStyle(Color.MeetPR.green)
      VStack(alignment: .leading, spacing: 2) {
        Text("今日训练完成")
          .font(.title2.bold())
          .foregroundStyle(Color.MeetPR.fgPrimary)
        Text(StudentFormatting.dayMonthFormatter.string(from: date))
          .font(.subheadline)
          .foregroundStyle(Color.MeetPR.fgSecondary)
      }
    }
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct SummarySection<Content: View>: View {
  let title: String
  @ViewBuilder let content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(title)
        .font(.title3.bold())
        .foregroundStyle(Color.MeetPR.fgPrimary)
      content
    }
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct SummaryOverviewGrid: View {
  let summary: StudentSessionSummary

  private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

  var body: some View {
    LazyVGrid(columns: columns, spacing: 12) {
      StatCard(label: "完成组数", value: "\(summary.completedSets)")
      StatCard(label: "总次数", value: "\(summary.totalReps)")
      StatCard(label: "总容量", value: "\(StudentFormatting.decimal(summary.totalVolumeKg)) kg")
      StatCard(label: "平均 RPE", value: summary.averageRPE.map(StudentFormatting.decimal) ?? "—")
    }
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct StatCard: View {
  let label: String
  let value: String

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(label)
        .font(.caption)
        .foregroundStyle(Color.MeetPR.fgSecondary)
      Text(value)
        .font(.title2.monospacedDigit().bold())
        .foregroundStyle(Color.MeetPR.fgPrimary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .modifier(SummaryCard())
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct SummaryPerformanceList: View {
  let exercises: [StudentSessionSummary.ExercisePerformance]

  var body: some View {
    VStack(spacing: 12) {
      ForEach(exercises) { exercise in
        VStack(alignment: .leading, spacing: 4) {
          Text(exercise.name)
            .font(.headline)
            .foregroundStyle(Color.MeetPR.fgPrimary)
          Text("最重组")
            .font(.caption)
            .foregroundStyle(Color.MeetPR.fgTertiary)
          Text(
            StudentFormatting.result(
              weightKg: exercise.topSetWeightKg, reps: exercise.topSetReps, rpe: exercise.topSetRPE)
          )
          .font(.subheadline.monospacedDigit().bold())
          .foregroundStyle(Color.MeetPR.green)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(SummaryCard())
      }
    }
  }
}

/// The one-line review that actually persists (spec 051 §1): the three
/// throwaway prompts collapsed into a single feeling + optional session RPE.
@available(iOS 17.0, macOS 14.0, *)
private struct SessionReviewSection: View {
  @Bindable var viewModel: SessionReviewSubmitViewModel
  let isSolo: Bool
  @State private var wantsRPE = false

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      VStack(alignment: .leading, spacing: 8) {
        Label("一句话感受", systemImage: "square.and.pencil")
          .font(.subheadline.bold())
          .foregroundStyle(Color.MeetPR.fgPrimary)
        TextField("今天练得怎么样?", text: $viewModel.feeling, axis: .vertical)
          .font(.subheadline)
          .foregroundStyle(Color.MeetPR.fgPrimary)
          .lineLimit(2...5)
        Text(isSolo ? "记录你的状态,曲线之外的另一半" : "教练会看到")
          .font(.caption)
          .foregroundStyle(Color.MeetPR.fgTertiary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .modifier(SummaryCard())

      VStack(alignment: .leading, spacing: 8) {
        Toggle("记一下整场 RPE", isOn: $wantsRPE)
          .font(.subheadline)
        if wantsRPE {
          Stepper(value: rpeBinding, in: 5...10, step: 0.5) {
            Text("整场 RPE \(StudentFormatting.decimal(viewModel.sessionRPE ?? 7))")
              .font(.subheadline.monospacedDigit())
          }
        }
      }
      .modifier(SummaryCard())

      switch viewModel.state {
      case .saved:
        Label("已保存", systemImage: "checkmark.circle.fill")
          .font(.subheadline)
          .foregroundStyle(Color.MeetPR.green)
      case .failed(let message):
        Label(message, systemImage: "exclamationmark.triangle")
          .font(.subheadline)
          .foregroundStyle(Color.MeetPR.brandRed)
      case .idle, .submitting:
        EmptyView()
      }

      Button {
        Task { await viewModel.submit() }
      } label: {
        Text(viewModel.state == .submitting ? "保存中…" : "保存回顾")
          .font(.headline)
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      .tint(Color.MeetPR.brandRed)
      .disabled(!viewModel.canSubmit)
      .accessibilityIdentifier("summary.review.submit")
    }
    .task {
      await viewModel.load()
      wantsRPE = viewModel.sessionRPE != nil
    }
    .onChange(of: wantsRPE) { _, wants in
      if !wants { viewModel.sessionRPE = nil }
    }
  }

  private var rpeBinding: Binding<Decimal> {
    Binding(
      get: { viewModel.sessionRPE ?? 7 },
      set: { viewModel.sessionRPE = $0 }
    )
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct SummaryReflections: View {
  @State private var mindset = ""
  @State private var achievements = ""
  @State private var improvements = ""

  var body: some View {
    VStack(spacing: 12) {
      ReflectionField(title: "本次目标", prompt: "这次训练你想达成什么?", text: $mindset)
      ReflectionField(title: "做到了什么", prompt: "这次训练有哪些收获?", text: $achievements)
      ReflectionField(title: "可以更好", prompt: "哪里还能做得更好?", text: $improvements)
    }
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct ReflectionField: View {
  let title: String
  let prompt: String
  @Binding var text: String

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label(title, systemImage: "square.and.pencil")
        .font(.subheadline.bold())
        .foregroundStyle(Color.MeetPR.fgPrimary)
      TextField(prompt, text: $text, axis: .vertical)
        .font(.subheadline)
        .foregroundStyle(Color.MeetPR.fgPrimary)
        .lineLimit(2...5)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .modifier(SummaryCard())
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct SummaryCard: ViewModifier {
  func body(content: Content) -> some View {
    content
      .padding(14)
      .background(Color.MeetPR.surface1)
      .overlay {
        RoundedRectangle(cornerRadius: 12)
          .stroke(Color.MeetPR.border, lineWidth: 1)
      }
      .clipShape(.rect(cornerRadius: 12))
  }
}
