import DesignSystem
import Foundation
import RepositoryContracts
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
  /// The day code shown as the first hero numeral, e.g. "W1D4".
  let dayLabel: String?
  let studentID: UUID
  let streak: any StudentStreakRepository
  let reflectionStore: any SessionReflectionStore
  let onComplete: (() -> Void)?

  @Environment(\.dismiss) private var dismiss
  @State private var streakCurrent: Int?

  init(
    summary: StudentSessionSummary,
    date: Date,
    dayLabel: String? = nil,
    studentID: UUID,
    streak: any StudentStreakRepository = InMemoryStudentStreakRepository(current: 12),
    reflectionStore: any SessionReflectionStore = UserDefaultsSessionReflectionStore(),
    onComplete: (() -> Void)? = nil
  ) {
    self.summary = summary
    self.date = date
    self.dayLabel = dayLabel
    self.studentID = studentID
    self.streak = streak
    self.reflectionStore = reflectionStore
    self.onComplete = onComplete
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: MeetPRSpacing.space6) {
          CelebrationStage(
            date: date,
            dayLabel: dayLabel,
            totalVolumeKg: summary.totalVolumeKg,
            streakCurrent: streakCurrent
          )
          .frame(maxWidth: .infinity)
          .padding(.top, MeetPRSpacing.space2)
          .meetPRRiseIn(index: 0)
          if !summary.exercises.isEmpty {
            SummarySection(title: "动作表现") {
              SummaryPerformanceList(exercises: summary.exercises)
            }
            .meetPRRiseIn(index: 2)
          }
          SummarySection(title: "训练反思") {
            SummaryReflections(studentID: studentID, date: date, store: reflectionStore)
          }
          .meetPRRiseIn(index: 3)
        }
        .padding()
      }
      .scrollContentBackground(.hidden)
      .background(Color.MeetPR.bgBase)
      .background(alignment: .bottom) {
        // §4.5: a faint gold bloom rising from the bottom — the screen is the
        // stage, not a stack of cards.
        RadialGradient(
          colors: [Color.MeetPR.gold500.opacity(0.16), .clear],
          center: .bottom,
          startRadius: 0,
          endRadius: 420
        )
        .ignoresSafeArea()
        .allowsHitTesting(false)
      }
      .navigationTitle("训练回顾")
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
      #endif
      .toolbar {
        Button("完成") {
          onComplete?()
          dismiss()
        }
        .foregroundStyle(Color.MeetPR.gold500)
      }
      .safeAreaInset(edge: .bottom) {
        BrandPrimaryButton(
          "完成 · 回到今日",
          systemImage: "checkmark",
          showsShimmer: true,
          isFullWidth: true
        ) {
          onComplete?()
          dismiss()
        }
        .padding(.horizontal, MeetPRSpacing.base)
        .padding(.vertical, MeetPRSpacing.sm)
        .background(Color.MeetPR.bgBase)
      }
      .task {
        let loaded = try? await streak.currentStreak()
        streakCurrent = loaded?.current
      }
    }
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct CelebrationStage: View {
  let date: Date
  let dayLabel: String?
  let totalVolumeKg: Decimal
  let streakCurrent: Int?

  /// Drives the volume ticker from 0 to the real total on appear.
  @State private var shownVolume = 0
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  private var volumeTarget: Int {
    (totalVolumeKg as NSDecimalNumber).intValue
  }

  var body: some View {
    VStack(spacing: MeetPRSpacing.space3) {
      CelebrationEffects()
        .frame(width: 128, height: 128)
      Text("今日训练完成")
        .font(.MeetPR.display(size: 27, weight: .extraBold))
        .foregroundStyle(Color.MeetPR.textPrimary)
      Text(StudentFormatting.dayMonthFormatter.string(from: date))
        .font(.MeetPR.mono(size: MeetPRFontMetrics.size12, weight: .medium))
        .foregroundStyle(Color.MeetPR.textTertiary)

      HStack(spacing: MeetPRSpacing.space6) {
        if let dayLabel {
          heroNumeral(dayLabel, caption: "训练日")
        }
        heroNumeral(
          shownVolume.formatted(.number.grouping(.automatic)) + " KG",
          caption: "今日总容量"
        )
        .contentTransition(.numericText(value: Double(shownVolume)))
      }
      .padding(.top, MeetPRSpacing.space1)

      if let streakCurrent {
        Label("连续第 \(streakCurrent) 次训练", systemImage: "flame.fill")
          .font(.MeetPR.system(size: MeetPRFontMetrics.size12, weight: .bold))
          .foregroundStyle(Color.MeetPR.gold500)
          .padding(.horizontal, MeetPRSpacing.point14)
          .padding(.vertical, MeetPRSpacing.point6)
          .background(Color.MeetPR.goldSoft, in: .capsule)
          .overlay {
            Capsule().stroke(Color.MeetPR.gold500.opacity(0.3), lineWidth: 1)
          }
          .transition(.move(edge: .bottom).combined(with: .opacity))
      }

      HStack(spacing: MeetPRSpacing.space2) {
        Image(systemName: "person.crop.circle.badge.checkmark")
          .font(.MeetPR.system(size: MeetPRFontMetrics.size15))
          .foregroundStyle(Color.MeetPR.success)
        Text("教练已收到你的训练日志")
          .font(.MeetPR.system(size: MeetPRFontMetrics.size13))
          .foregroundStyle(Color.MeetPR.textSecondary)
      }
      .padding(.top, MeetPRSpacing.space1)
    }
    .animation(MeetPRMotion.rise, value: streakCurrent)
    .task {
      guard !reduceMotion else {
        shownVolume = volumeTarget
        return
      }
      // Roll the ticker in ~14 steps over ~0.7s.
      let target = volumeTarget
      guard target > 0 else { return }
      for step in 1...14 {
        try? await Task.sleep(for: .milliseconds(50))
        withAnimation(.linear(duration: 0.05)) {
          shownVolume = target * step / 14
        }
      }
      shownVolume = target
    }
  }

  private func heroNumeral(_ value: String, caption: String) -> some View {
    VStack(spacing: MeetPRSpacing.point3) {
      Text(value)
        .font(.MeetPR.mono(size: 30, weight: .bold))
        .foregroundStyle(Color.MeetPR.gold500)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
      Text(caption)
        .font(.MeetPR.mono(size: MeetPRFontMetrics.size11, weight: .medium))
        .foregroundStyle(Color.MeetPR.textFaint)
    }
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct SummarySection<Content: View>: View {
  let title: String
  @ViewBuilder let content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.space3) {
      Text(title)
        .font(.MeetPR.mono(size: 11, weight: .semibold))
        .tracking(0.8)
        .foregroundStyle(Color.MeetPR.textMuted)
      content
    }
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct SummaryOverviewGrid: View {
  let summary: StudentSessionSummary

  private let columns = [
    GridItem(.flexible(), spacing: MeetPRSpacing.space3),
    GridItem(.flexible(), spacing: MeetPRSpacing.space3),
  ]

  var body: some View {
    LazyVGrid(columns: columns, spacing: MeetPRSpacing.space3) {
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
    VStack(alignment: .leading, spacing: MeetPRSpacing.point6) {
      Text(label)
        .font(.caption)
        .foregroundStyle(Color.MeetPR.textSecondary)
      Text(value)
        .font(.MeetPR.display(size: 19, weight: .extraBold).monospacedDigit())
        .foregroundStyle(Color.MeetPR.gold500)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .modifier(SummaryCard())
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct SummaryPerformanceList: View {
  let exercises: [StudentSessionSummary.ExercisePerformance]

  var body: some View {
    VStack(spacing: MeetPRSpacing.space3) {
      ForEach(exercises) { exercise in
        VStack(alignment: .leading, spacing: MeetPRSpacing.space1) {
          Text(exercise.name)
            .font(.headline)
            .foregroundStyle(Color.MeetPR.textPrimary)
          Text("最重组")
            .font(.caption)
            .foregroundStyle(Color.MeetPR.textTertiary)
          Text(
            StudentFormatting.result(
              weightKg: exercise.topSetWeightKg, reps: exercise.topSetReps, rpe: exercise.topSetRPE)
          )
          .font(.subheadline.monospacedDigit().bold())
          .foregroundStyle(Color.MeetPR.success)
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
    VStack(alignment: .leading, spacing: MeetPRSpacing.space3) {
      Label("仅自己可见的训练笔记，保存在本机", systemImage: "lock.fill")
        .font(.caption)
        .foregroundStyle(Color.MeetPR.textTertiary)
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
    VStack(alignment: .leading, spacing: MeetPRSpacing.space2) {
      Label(title, systemImage: "square.and.pencil")
        .font(.subheadline.bold())
        .foregroundStyle(Color.MeetPR.textPrimary)
      TextField(prompt, text: $text, axis: .vertical)
        .font(.subheadline)
        .foregroundStyle(Color.MeetPR.textPrimary)
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
      .padding(MeetPRSpacing.point14)
      .background(Color.MeetPR.surfaceCard)
      .overlay {
        RoundedRectangle(cornerRadius: MeetPRRadius.control)
          .stroke(Color.MeetPR.borderSubtle, lineWidth: 1)
      }
      .clipShape(.rect(cornerRadius: MeetPRRadius.control))
  }
}
