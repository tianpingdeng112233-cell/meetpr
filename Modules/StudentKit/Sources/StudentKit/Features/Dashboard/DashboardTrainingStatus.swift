import CoreModels
import DesignSystem
import Foundation
import Observation
import RepositoryContracts
import SwiftUI

enum DashboardTodayTrainingStatus: Equatable, Sendable {
  case unknown
  case rest
  case notStarted(dayName: String, setCount: Int)
  case inProgress(elapsedSeconds: Int)
  case partial(durationMinutes: Int)
  case completed(durationMinutes: Int)

  var accessibilityText: String {
    switch self {
    case .unknown:
      "训练状态未知"
    case .rest:
      "今日休息"
    case .notStarted(let dayName, let setCount):
      "今日 · \(dayName) · \(setCount) 组 › 开始训练"
    case .inProgress(let elapsedSeconds):
      "训练中 · \(TrainingSessionTimer.text(seconds: elapsedSeconds))"
    case .partial(let durationMinutes):
      "今日已练 · \(durationMinutes) 分钟"
    case .completed(let durationMinutes):
      "今日已完成 · \(durationMinutes) 分钟"
    }
  }
}

@Observable
@MainActor
final class DashboardTrainingStatusViewModel {
  private(set) var snapshot: TrainingSessionSnapshot?
  private(set) var currentDate: Date
  private(set) var hasLoaded = false

  @ObservationIgnored private let sessions: any TrainingSessionRepository
  private let sessionActivityCenter: TrainingSessionActivityCenter
  @ObservationIgnored private let now: @Sendable () -> Date
  @ObservationIgnored private let onOpenTraining: @MainActor () -> Void
  // Stale-response guard: overlapping reloads (.task / pull-to-refresh /
  // onAppear / scenePhase.active) may resolve out of order; only the newest
  // issued request is allowed to write the snapshot or the shared center.
  @ObservationIgnored private var reloadGeneration = 0

  init(
    sessions: any TrainingSessionRepository,
    sessionActivityCenter: TrainingSessionActivityCenter = TrainingSessionActivityCenter(),
    now: @escaping @Sendable () -> Date = { Date() },
    onOpenTraining: @escaping @MainActor () -> Void
  ) {
    self.sessions = sessions
    self.sessionActivityCenter = sessionActivityCenter
    self.now = now
    self.onOpenTraining = onOpenTraining
    self.currentDate = now()
  }

  func loadIfNeeded() async {
    guard !hasLoaded else { return }
    await reload()
  }

  func reload() async {
    currentDate = now()
    if let sharedSnapshot = sessionActivityCenter.snapshot {
      snapshot = sharedSnapshot
      hasLoaded = true
    }
    reloadGeneration += 1
    let issuedGeneration = reloadGeneration
    do {
      let fetchedSnapshot = try await sessions.fetchSession(on: nil)
      guard issuedGeneration == reloadGeneration else { return }
      if fetchedSnapshot.session == nil,
        sessionActivityCenter.holdsOptimisticInProgress,
        let optimisticSnapshot = sessionActivityCenter.snapshot
      {
        let gymDaysMatch =
          optimisticSnapshot.gymDay != nil
          && optimisticSnapshot.gymDay == fetchedSnapshot.gymDay
        if optimisticSnapshot.gymDay == nil, let fetchedGymDay = fetchedSnapshot.gymDay {
          let adoptedSnapshot = TrainingSessionSnapshot(
            gymDay: fetchedGymDay,
            session: optimisticSnapshot.session
          )
          sessionActivityCenter.storeOptimisticInProgress(adoptedSnapshot)
          snapshot = adoptedSnapshot
          hasLoaded = true
          return
        }
        if gymDaysMatch {
          snapshot = optimisticSnapshot
          hasLoaded = true
          return
        }
      }
      snapshot = fetchedSnapshot
      sessionActivityCenter.storeAuthoritative(fetchedSnapshot)
      hasLoaded = true
    } catch {
      // Preserve a previously rendered session. Only the first failed load
      // becomes unknown; a transient refresh must not masquerade as not-started.
    }
  }

  func scenePhaseChanged(to scenePhase: ScenePhase) async {
    guard scenePhase == .active else { return }
    await reload()
  }

  func tick() {
    currentDate = now()
  }

  func openTraining() {
    onOpenTraining()
  }

  var displayDate: Date {
    guard let gymDay = snapshot?.gymDay else { return currentDate }
    let formatStyle = Date.ISO8601FormatStyle(timeZone: Calendar.current.timeZone)
      .year().month().day()
    return (try? formatStyle.parse(gymDay)) ?? currentDate
  }

  func status(for day: StudentPlanDay?) -> DashboardTodayTrainingStatus {
    guard let snapshot else { return .unknown }
    // `snapshot.gymDay` is the single gym-day authority. In the local
    // 00:00–04:00 crossover it can intentionally differ from Calendar.current;
    // never discard its session by re-deriving a local day from startedAt.
    switch snapshot.session?.status {
    case .inProgress:
      guard let session = snapshot.session else { return .unknown }
      let elapsed = max(0, Int(currentDate.timeIntervalSince(session.startedAt)))
      return .inProgress(elapsedSeconds: elapsed)
    case .partial:
      return .partial(
        durationMinutes: max(0, (snapshot.session?.durationSeconds ?? 0) / 60)
      )
    case .completed:
      return .completed(
        durationMinutes: max(0, (snapshot.session?.durationSeconds ?? 0) / 60)
      )
    case nil:
      guard let day else { return .rest }
      return notStartedStatus(for: day)
    }
  }

  private func notStartedStatus(for day: StudentPlanDay) -> DashboardTodayTrainingStatus {
    .notStarted(
      dayName: MainLiftExerciseFamilyResolver.dayName(in: day) ?? "辅助日",
      setCount: day.exercises.reduce(0) { $0 + $1.prescribedSets.count }
    )
  }
}

@available(iOS 17.0, macOS 14.0, *)
struct DashboardTrainingStatusBar: View {
  let day: StudentPlanDay?
  @Bindable var viewModel: DashboardTrainingStatusViewModel
  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    let status = viewModel.status(for: day)
    Group {
      if status == .rest || status == .unknown {
        passiveBar(status)
      } else {
        Button(action: viewModel.openTraining) {
          statusContent(status)
        }
        .buttonStyle(.plain)
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(status.accessibilityText)
    .onChange(of: scenePhase) { _, newPhase in
      Task { await viewModel.scenePhaseChanged(to: newPhase) }
    }
    .task(id: isInProgress(status)) {
      guard isInProgress(status) else { return }
      while !Task.isCancelled {
        do {
          try await Task.sleep(for: .seconds(1))
        } catch {
          return
        }
        viewModel.tick()
      }
    }
  }

  private func passiveBar(_ status: DashboardTodayTrainingStatus) -> some View {
    HStack(spacing: 10) {
      if status == .rest {
        Image(systemName: "bed.double.fill")
          .foregroundStyle(Color.MeetPR.fgSecondary)
      }
      Text(status == .rest ? "今日休息" : "— —")
        .font(Font.MeetPR.bodyEmphasis)
        .foregroundStyle(status == .rest ? Color.MeetPR.fgPrimary : Color.MeetPR.fgTertiary)
      Spacer()
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(16)
    .background(Color.MeetPR.surface1)
    .clipShape(.rect(cornerRadius: 12))
    .overlay {
      RoundedRectangle(cornerRadius: 12).stroke(Color.MeetPR.border, lineWidth: 1)
    }
  }

  @ViewBuilder
  private func statusContent(_ status: DashboardTodayTrainingStatus) -> some View {
    HStack(spacing: 8) {
      switch status {
      case .notStarted(let dayName, let setCount):
        Text("今日 · \(dayName) · \(setCount) 组")
          .font(Font.MeetPR.bodyEmphasis)
          .foregroundStyle(Color.MeetPR.fgPrimary)
        Spacer()
        Text("› 开始训练")
          .font(Font.MeetPR.body)
          .foregroundStyle(Color.MeetPR.fgSecondary)
      case .inProgress(let elapsedSeconds):
        Circle()
          .fill(Color.MeetPR.brandRed)
          .frame(width: 8, height: 8)
        Text("训练中 · \(TrainingSessionTimer.text(seconds: elapsedSeconds))")
          .font(.system(size: 14, design: .monospaced).monospacedDigit())
          .foregroundStyle(Color.MeetPR.fgPrimary)
        Spacer()
        Image(systemName: "chevron.right")
          .foregroundStyle(Color.MeetPR.fgTertiary)
      case .partial(let durationMinutes):
        completionCheckmark(color: Color.MeetPR.fgSecondary)
        Text("今日已练 · \(durationMinutes) 分钟")
          .font(.system(size: 13))
          .foregroundStyle(Color.MeetPR.fgSecondary)
        Spacer()
        Image(systemName: "chevron.right")
          .foregroundStyle(Color.MeetPR.fgTertiary)
      case .completed(let durationMinutes):
        completionCheckmark(color: Color.MeetPR.green)
        Text("今日已完成 · \(durationMinutes) 分钟")
          .font(.system(size: 13))
          .foregroundStyle(Color.MeetPR.green)
        Spacer()
        Image(systemName: "chevron.right")
          .foregroundStyle(Color.MeetPR.fgTertiary)
      case .unknown, .rest:
        EmptyView()
      }
    }
    .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
    .padding(.horizontal, 16)
    .background(Color.MeetPR.surface1)
    .clipShape(.rect(cornerRadius: 12))
    .overlay {
      RoundedRectangle(cornerRadius: 12).stroke(Color.MeetPR.border, lineWidth: 1)
    }
  }

  private func completionCheckmark(color: Color) -> some View {
    Image(systemName: "checkmark")
      .font(.system(size: 12, weight: .bold))
      .foregroundStyle(color)
  }

  private func isInProgress(_ status: DashboardTodayTrainingStatus) -> Bool {
    if case .inProgress = status { return true }
    return false
  }
}
