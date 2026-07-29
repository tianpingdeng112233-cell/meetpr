// swiftlint:disable file_length
import DesignSystem
import Foundation
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct SessionSummaryView: View {
  let presentation: WorkoutCompletionPresentation
  let studentID: UUID
  let reflectionStore: any SessionReflectionStore
  let onComplete: () -> Void

  init(
    presentation: WorkoutCompletionPresentation,
    studentID: UUID,
    reflectionStore: any SessionReflectionStore = UserDefaultsSessionReflectionStore(),
    onComplete: @escaping () -> Void
  ) {
    self.presentation = presentation
    self.studentID = studentID
    self.reflectionStore = reflectionStore
    self.onComplete = onComplete
  }

  var body: some View {
    VStack(spacing: 0) {
      SessionSummaryHeader(presentation: presentation)

      ScrollView {
        VStack(alignment: .leading, spacing: MeetPRSpacing.point14) {
          SessionVolumeCard(presentation: presentation)

          if presentation.hasPersonalRecord {
            SessionPersonalRecordRow(text: presentation.personalRecordText)
          }

          SessionSectionLabel(title: "动作表现")
          SessionPerformanceList(exercises: presentation.exercises)

          SessionReflectionHeading()
            .padding(.top, MeetPRSpacing.point2)
          SessionReflectionFields(
            studentID: studentID,
            date: presentation.date,
            store: reflectionStore
          )
        }
        .padding(.horizontal, MeetPRSpacing.space5)
        .padding(.top, MeetPRSpacing.space4)
        .padding(.bottom, MeetPRSpacing.space6)
      }
      .scrollIndicators(.hidden)

      VStack {
        GoldCTA(
          "完成 · 回到今日",
          sub: nil,
          icon: .none,
          showsShimmer: true,
          action: onComplete
        )
        .accessibilityRepresentation {
          Button("完成 · 回到今日", action: onComplete)
        }
      }
      .padding(.horizontal, MeetPRSpacing.space5)
      .padding(.top, MeetPRSpacing.space3)
      .padding(.bottom, MeetPRSpacing.space5)
      .background(Color.MeetPR.bgBase)
      .overlay(alignment: .top) {
        Rectangle()
          .fill(Color.MeetPR.borderHairline)
          .frame(height: 1)
      }
    }
    .foregroundStyle(Color.MeetPR.textPrimary)
    .background(Color.MeetPR.bgBase)
  }
}

private struct SessionSummaryHeader: View {
  let presentation: WorkoutCompletionPresentation

  var body: some View {
    HStack(spacing: MeetPRSpacing.point10) {
      VStack(alignment: .leading, spacing: MeetPRSpacing.point2) {
        Text("训练回顾")
          .font(.MeetPR.display(size: MeetPRFontMetrics.size17))
          .foregroundStyle(Color.MeetPR.textPrimary)
        Text(presentation.dateSubtitle)
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size11))
          .foregroundStyle(Color.MeetPR.textMuted)
      }

      Spacer()

      Text("已通知教练")
        .font(.MeetPR.mono(size: MeetPRFontMetrics.size11, weight: .bold))
        .tracking(0.55)
        .foregroundStyle(Color.MeetPR.success)
        .padding(.horizontal, MeetPRSpacing.space3)
        .padding(.vertical, MeetPRSpacing.space1)
        .background(Color.MeetPR.successRGB.opacity(0.16), in: .capsule)
    }
    .padding(.horizontal, MeetPRSpacing.space5)
    .padding(.top, MeetPRSpacing.space1)
    .padding(.bottom, MeetPRSpacing.point13)
    .overlay(alignment: .bottom) {
      Rectangle()
        .fill(Color.MeetPR.borderHairline)
        .frame(height: 1)
    }
  }
}

private struct SessionVolumeCard: View {
  let presentation: WorkoutCompletionPresentation

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text("总容量")
        .font(.MeetPR.mono(size: MeetPRFontMetrics.size11, weight: .semibold))
        .tracking(0.88)
        .foregroundStyle(Color.MeetPR.goldText)

      HStack(alignment: .firstTextBaseline, spacing: MeetPRSpacing.point7) {
        Text(presentation.totalVolumeText)
          .font(.MeetPR.display(size: MeetPRFontMetrics.size46))
          .monospacedDigit()
          .foregroundStyle(Color.MeetPR.textPrimary)
          .minimumScaleFactor(0.65)
          .lineLimit(1)
        Text("kg")
          .font(.MeetPR.body(size: MeetPRFontMetrics.size14, weight: .bold))
          .foregroundStyle(Color.MeetPR.textMuted)
        Spacer(minLength: MeetPRSpacing.space1)
        Text(presentation.volumeComparisonText)
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size12))
          .foregroundStyle(Color.MeetPR.success)
      }
      .padding(.top, MeetPRSpacing.point5)

      HStack(spacing: MeetPRSpacing.space2) {
        SessionVolumeStat(value: presentation.exerciseCount.formatted(), label: "动作")
        SessionVolumeStat(value: presentation.completedSetCount.formatted(), label: "组数")
        SessionVolumeStat(value: presentation.totalReps.formatted(), label: "总次数")
        SessionVolumeStat(value: presentation.averageRPEText, label: "平均 RPE")
      }
      .padding(.top, MeetPRSpacing.point15)
    }
    .padding(.horizontal, MeetPRSpacing.space4)
    .padding(.top, MeetPRSpacing.point18)
    .padding(.bottom, MeetPRSpacing.point15)
    .background(
      LinearGradient(
        colors: [.MeetPR.reviewHeroTop, .MeetPR.surfaceCard],
        startPoint: .top,
        endPoint: .bottom
      )
    )
    .overlay {
      RoundedRectangle(cornerRadius: MeetPRRadius.card)
        .stroke(Color.MeetPR.goldRGB.opacity(0.25), lineWidth: 1)
    }
    .clipShape(.rect(cornerRadius: MeetPRRadius.card))
  }
}

private struct SessionVolumeStat: View {
  let value: String
  let label: String

  var body: some View {
    VStack(spacing: MeetPRSpacing.point2) {
      Text(value)
        .font(.MeetPR.display(size: MeetPRFontMetrics.size19))
        .monospacedDigit()
        .foregroundStyle(Color.MeetPR.textPrimary)
        .minimumScaleFactor(0.75)
        .lineLimit(1)
      Text(label)
        .font(.MeetPR.body(size: MeetPRFontMetrics.size10))
        .foregroundStyle(Color.MeetPR.textMuted)
        .lineLimit(1)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, MeetPRSpacing.point9)
    .background(Color.MeetPR.medalStatTile)
    .clipShape(.rect(cornerRadius: MeetPRRadius.control))
  }
}

private struct SessionPersonalRecordRow: View {
  let text: String

  var body: some View {
    HStack(spacing: MeetPRSpacing.point10) {
      CrownIcon()
        .fill(Color.MeetPR.gold500)
        .frame(width: 18, height: 18)
      Text(text)
        .font(.MeetPR.body(size: MeetPRFontMetrics.size13, weight: .bold))
        .foregroundStyle(Color.MeetPR.goldText)
      Spacer(minLength: 0)
    }
    .padding(.horizontal, MeetPRSpacing.point14)
    .padding(.vertical, MeetPRSpacing.point11)
    .background(Color.MeetPR.goldRGB.opacity(0.10))
    .overlay {
      RoundedRectangle(cornerRadius: MeetPRRadius.control)
        .stroke(Color.MeetPR.goldRGB.opacity(0.35), lineWidth: 1)
    }
    .clipShape(.rect(cornerRadius: MeetPRRadius.control))
  }
}

private struct SessionSectionLabel: View {
  let title: String

  var body: some View {
    HStack(spacing: MeetPRSpacing.point9) {
      Text(title)
        .font(.MeetPR.mono(size: MeetPRFontMetrics.size11))
        .foregroundStyle(Color.MeetPR.textMuted)
      Rectangle()
        .fill(Color.MeetPR.borderSubtle)
        .frame(height: 1)
    }
  }
}

private struct SessionPerformanceList: View {
  let exercises: [WorkoutCompletionPresentation.ExercisePerformance]

  var body: some View {
    VStack(spacing: 0) {
      ForEach(exercises) { exercise in
        HStack(spacing: MeetPRSpacing.point10) {
          VStack(alignment: .leading, spacing: MeetPRSpacing.point3) {
            Text(exercise.name)
              .font(.MeetPR.body(size: MeetPRFontMetrics.size14, weight: .bold))
              .foregroundStyle(Color.MeetPR.textPrimary)
            Text("最重组 \(exercise.bestSetText)")
              .font(.MeetPR.mono(size: MeetPRFontMetrics.size11))
              .foregroundStyle(Color.MeetPR.textFaint)
          }
          .frame(maxWidth: .infinity, alignment: .leading)

          if exercise.isPersonalRecord {
            Text("PR")
              .font(.MeetPR.mono(size: MeetPRFontMetrics.size10, weight: .bold))
              .foregroundStyle(Color.MeetPR.goldText)
              .padding(.horizontal, MeetPRSpacing.space2)
              .padding(.vertical, MeetPRSpacing.point2)
              .overlay {
                Capsule().stroke(Color.MeetPR.goldRGB.opacity(0.4), lineWidth: 1)
              }
          }

          Text(exercise.statusText)
            .font(.MeetPR.mono(size: MeetPRFontMetrics.size11))
            .foregroundStyle(
              exercise.failedSetCount > 0
                ? Color.MeetPR.danger
                : Color.MeetPR.success
            )
        }
        .padding(.horizontal, MeetPRSpacing.point15)
        .padding(.vertical, MeetPRSpacing.point13)
        .overlay(alignment: .top) {
          Rectangle()
            .fill(Color.MeetPR.borderSubtle)
            .frame(height: 1)
        }
      }
    }
    .background(Color.MeetPR.surfaceCard)
    .clipShape(.rect(cornerRadius: MeetPRRadius.card))
  }
}

private struct SessionReflectionHeading: View {
  var body: some View {
    HStack(spacing: MeetPRSpacing.point9) {
      Text("训练反思")
        .font(.MeetPR.mono(size: MeetPRFontMetrics.size11))
        .foregroundStyle(Color.MeetPR.textMuted)
      Rectangle()
        .fill(Color.MeetPR.borderSubtle)
        .frame(height: 1)
      Label("仅自己可见 · 保存在本机", systemImage: "lock.fill")
        .font(.MeetPR.body(size: MeetPRFontMetrics.size10))
        .foregroundStyle(Color.MeetPR.textDim)
    }
  }
}

private struct SessionReflectionFields: View {
  let studentID: UUID
  let date: Date
  let store: any SessionReflectionStore

  @State private var mindset = ""
  @State private var achievements = ""
  @State private var improvements = ""

  var body: some View {
    VStack(spacing: 0) {
      SessionReflectionField(
        title: "本次目标",
        prompt: "这次训练你想达成什么？",
        text: $mindset
      )
      SessionReflectionField(
        title: "做到了什么",
        prompt: "这次训练有哪些收获？",
        text: $achievements
      )
      SessionReflectionField(
        title: "可以更好",
        prompt: "哪里还能做得更好？",
        text: $improvements,
        showsDivider: false
      )
    }
    .padding(.horizontal, MeetPRSpacing.point15)
    .padding(.vertical, MeetPRSpacing.space1)
    .background(Color.MeetPR.surfaceCard)
    .clipShape(.rect(cornerRadius: MeetPRRadius.card))
    .task {
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
      SessionReflection(
        mindset: mindset,
        achievements: achievements,
        improvements: improvements
      ),
      studentId: studentID,
      date: date
    )
  }
}

private struct SessionReflectionField: View {
  let title: String
  let prompt: String
  @Binding var text: String
  var showsDivider = true

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.point6) {
      Text(title)
        .font(.MeetPR.body(size: MeetPRFontMetrics.size13, weight: .bold))
        .foregroundStyle(Color.MeetPR.textPrimary)
      TextField(prompt, text: $text, axis: .vertical)
        .font(.MeetPR.body(size: MeetPRFontMetrics.size13))
        .foregroundStyle(Color.MeetPR.textSecondary)
        .lineLimit(1...4)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.vertical, MeetPRSpacing.point11)
    .overlay(alignment: .bottom) {
      if showsDivider {
        Rectangle()
          .fill(Color.MeetPR.borderSubtle)
          .frame(height: 1)
      }
    }
  }
}

private struct CrownIcon: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
      CGPoint(x: rect.minX + (x / 24 * rect.width), y: rect.minY + (y / 24 * rect.height))
    }
    path.move(to: point(5, 16))
    path.addLine(to: point(3, 5))
    path.addLine(to: point(8.5, 9))
    path.addLine(to: point(12, 3))
    path.addLine(to: point(15.5, 9))
    path.addLine(to: point(21, 5))
    path.addLine(to: point(19, 16))
    path.closeSubpath()
    path.addRect(
      CGRect(
        x: point(5, 18).x,
        y: point(5, 18).y,
        width: rect.width * 14 / 24,
        height: rect.height * 2 / 24
      )
    )
    return path
  }
}
