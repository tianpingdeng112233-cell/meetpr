import CoreModels
import DesignSystem
import RepositoryContracts
import SwiftUI

/// Read-only 29-field onboarding profile, grouped by the 7 wizard steps
/// (spec 033 §4). Pushed from a queue card; the footer repeats accept /
/// reject so the coach can decide without going back (D11).
@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct StudentOnboardingProfileView: View {
  enum LoadState: Equatable {
    case loading
    case loaded(OnboardingProfile)
    /// 404 (never filled in) or 403 (request lazily expired underneath us).
    case unavailable
  }

  let item: CoachBindRequestItem
  let profiles: any OnboardingProfileReading
  let onAccept: () -> Void
  let onReject: () -> Void

  @State private var state: LoadState = .loading

  var body: some View {
    Group {
      switch state {
      case .loading:
        ProgressView()
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      case .unavailable:
        ContentUnavailableView(
          "学员尚未填写资料",
          systemImage: "doc.text",
          description: Text("可以直接接收或拒绝;请求过期时返回队列会自动刷新")
        )
      case .loaded(let profile):
        ScrollView {
          VStack(alignment: .leading, spacing: MeetPRSpacing.base) {
            OnboardingProfileGroups(profile: profile)
          }
          .padding(MeetPRSpacing.base)
        }
      }
    }
    .safeAreaInset(edge: .bottom) {
      decisionFooter
    }
    .background(Color.MeetPR.bg)
    .navigationTitle(item.displayName)
    .task {
      await load()
    }
  }

  private var decisionFooter: some View {
    HStack(spacing: MeetPRSpacing.sm) {
      SecondaryButton("拒绝", isFullWidth: true) {
        onReject()
      }
      PrimaryButton("接收", isFullWidth: true) {
        onAccept()
      }
    }
    .padding(MeetPRSpacing.base)
    .background(.thinMaterial)
  }

  private func load() async {
    // Any failure (403 expired-pending included) lands on the neutral
    // empty state; the queue refreshes on return (spec 033 §4).
    if let profile = try? await profiles.fetchProfile(studentId: item.studentId) {
      state = .loaded(profile)
    } else {
      state = .unavailable
    }
  }
}

/// The 7 step-group cards. Null fields render as "—".
@MainActor
@available(iOS 17.0, macOS 14.0, *)
private struct OnboardingProfileGroups: View {
  let profile: OnboardingProfile

  var body: some View {
    basicsCard
    backgroundCard
    oneRMCard
    environmentCard
    recoveryCard
    materialsCard
    extrasCard
  }

  private var basicsCard: some View {
    groupCard("基础信息") {
      row("单位偏好", profile.unitPreference.map { $0 == .kg ? "公斤 (kg)" : "磅 (lb)" })
      row("性别", profile.gender.map(CoachOnboardingDisplay.genderText))
      row("生日", birthDateText)
      row("身高", profile.heightCm.map { "\(CoachOnboardingDisplay.decimalText($0)) cm" })
      row("体重", profile.weightKg.map { "\(CoachOnboardingDisplay.decimalText($0)) kg" })
    }
  }

  private var birthDateText: String? {
    guard let birthDate = profile.birthDate else { return nil }
    if let age = CoachOnboardingDisplay.age(birthDate: birthDate, now: Date()) {
      return "\(birthDate)(\(age) 岁)"
    }
    return birthDate
  }

  private var backgroundCard: some View {
    groupCard("训练背景") {
      row(
        "训练年限",
        profile.trainingYears.map { CoachOnboardingDisplay.trainingYearsText($0) })
      row("深蹲站位", profile.squatStance.map(CoachOnboardingDisplay.squatStanceText))
      row("硬拉风格", profile.deadliftStyle.map(CoachOnboardingDisplay.deadliftStyleText))
      row("卧推握距", profile.benchGrip.map(CoachOnboardingDisplay.benchGripText))
    }
  }

  private var oneRMCard: some View {
    groupCard("三大项 1RM") {
      row("深蹲", profile.squat1RMKg.map { "\(CoachOnboardingDisplay.decimalText($0)) kg" })
      row("卧推", profile.bench1RMKg.map { "\(CoachOnboardingDisplay.decimalText($0)) kg" })
      row("硬拉", profile.deadlift1RMKg.map { "\(CoachOnboardingDisplay.decimalText($0)) kg" })
    }
  }

  private var environmentCard: some View {
    groupCard("训练环境") {
      row("训练日", trainingDaysText)
      row("训练环境", profile.gymTier.map(CoachOnboardingDisplay.gymTierText))
      // Raw iOS-owned tokens (vocab owned by 031's EquipmentCatalog).
      row(
        "器械备注",
        profile.equipmentOverrides.isEmpty
          ? nil : profile.equipmentOverrides.joined(separator: ", "))
    }
  }

  private var trainingDaysText: String? {
    guard !profile.trainingDays.isEmpty else { return nil }
    return profile.trainingDays
      .map(CoachOnboardingDisplay.trainingDayText)
      .joined(separator: "·")
  }

  private var recoveryCard: some View {
    groupCard("恢复能力") {
      scaleRow(
        "日常强度", profile.dailyLifeIntensity,
        labels: CoachOnboardingDisplay.dailyLifeIntensityLabels)
      scaleRow("生活压力", profile.lifeStress, labels: CoachOnboardingDisplay.lifeStressLabels)
      scaleRow(
        "恢复速度", profile.recoverySpeed, labels: CoachOnboardingDisplay.recoverySpeedLabels)
      scaleRow("睡眠", profile.sleepHours, labels: CoachOnboardingDisplay.sleepHoursLabels)
    }
  }

  private var materialsCard: some View {
    groupCard("训练资料") {
      row(
        "想增强肌群",
        profile.muscleGroupsToStrengthen.isEmpty
          ? nil
          : CoachOnboardingDisplay.muscleGroupList(profile.muscleGroupsToStrengthen))
      row(
        "上传资料",
        profile.uploadAttachmentIds.isEmpty
          ? "无上传资料" : "已上传 \(profile.uploadAttachmentIds.count) 份")
    }
  }

  private var extrasCard: some View {
    groupCard("补充信息") {
      row("伤病史", injuryText)
      if let notes = profile.injuryNotes {
        Text(notes)
          .font(Font.MeetPR.footnote)
          .foregroundStyle(Color.MeetPR.fgSecondary)
      }
      row("是否备赛", profile.isCompeting.map { $0 ? "是" : "否" })
      if profile.isCompeting == true {
        row("比赛日期", profile.competitionDate)
        row("目标体重级", profile.targetWeightClass)
      }
      row("想对教练说", profile.noteToCoach)
    }
  }

  private var injuryText: String? {
    guard !profile.injuryAreas.isEmpty else { return nil }
    return profile.injuryAreas
      .map(CoachOnboardingDisplay.injuryAreaText)
      .joined(separator: "·")
  }

  private func groupCard(
    _ title: String,
    @ViewBuilder content: () -> some View
  ) -> some View {
    Card(accessibilityLabel: title) {
      VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
        Eyebrow(title)
        content()
      }
    }
  }

  private func row(_ label: String, _ value: String?) -> some View {
    HStack(alignment: .firstTextBaseline) {
      Text(label)
        .font(Font.MeetPR.footnote)
        .foregroundStyle(Color.MeetPR.fgTertiary)
        .frame(width: 72, alignment: .leading)
      Text(value ?? "—")
        .font(Font.MeetPR.body)
        .foregroundStyle(Color.MeetPR.fgPrimary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private func scaleRow(_ label: String, _ notch: Int?, labels: [String]) -> some View {
    row(
      label,
      notch.map { value in
        let dots = CoachOnboardingDisplay.scaleDots(value)
        return "\(dots) \(CoachOnboardingDisplay.scaleLabel(labels, notch: value))"
      }
    )
  }
}
