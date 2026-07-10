import DesignSystem
import Foundation
import SwiftUI

/// Post-session review, modeled on Juggernaut's workout summary: a completion
/// header, an Overview stat grid, a per-exercise Performance breakdown, and
/// free-text reflection prompts. Reflections persist locally per day
/// (`SessionReflectionStore`) and are labeled student-only until the backend
/// carries them to the coach.
@available(iOS 17.0, macOS 14.0, *)
struct SessionSummaryView: View {
  let summary: StudentSessionSummary
  let date: Date
  let studentID: UUID
  let reflectionStore: any SessionReflectionStore
  let onComplete: (() -> Void)?

  @Environment(\.dismiss) private var dismiss

  init(
    summary: StudentSessionSummary,
    date: Date,
    studentID: UUID,
    reflectionStore: any SessionReflectionStore = UserDefaultsSessionReflectionStore(),
    onComplete: (() -> Void)? = nil
  ) {
    self.summary = summary
    self.date = date
    self.studentID = studentID
    self.reflectionStore = reflectionStore
    self.onComplete = onComplete
  }

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
          SummarySection(title: "训练反思") {
            SummaryReflections(studentID: studentID, date: date, store: reflectionStore)
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
        Button("完成") {
          onComplete?()
          dismiss()
        }
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

@available(iOS 17.0, macOS 14.0, *)
private struct SummaryReflections: View {
  let studentID: UUID
  let date: Date
  let store: any SessionReflectionStore

  @State private var mindset = ""
  @State private var achievements = ""
  @State private var improvements = ""

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Label("仅自己可见的训练笔记，保存在本机", systemImage: "lock.fill")
        .font(.caption)
        .foregroundStyle(Color.MeetPR.fgTertiary)
      ReflectionField(title: "本次目标", prompt: "这次训练你想达成什么?", text: $mindset)
      ReflectionField(title: "做到了什么", prompt: "这次训练有哪些收获?", text: $achievements)
      ReflectionField(title: "可以更好", prompt: "哪里还能做得更好?", text: $improvements)
    }
    .onAppear {
      let saved = store.reflection(studentId: studentID, date: date)
      mindset = saved.mindset
      achievements = saved.achievements
      improvements = saved.improvements
    }
    .onChange(of: mindset) { _, _ in persist() }
    .onChange(of: achievements) { _, _ in persist() }
    .onChange(of: improvements) { _, _ in persist() }
  }

  private func persist() {
    store.save(
      SessionReflection(mindset: mindset, achievements: achievements, improvements: improvements),
      studentId: studentID, date: date)
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
