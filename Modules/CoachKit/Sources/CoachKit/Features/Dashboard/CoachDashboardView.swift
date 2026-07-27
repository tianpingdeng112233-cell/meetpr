import DesignSystem
import Foundation
import RepositoryContracts
import SwiftUI

@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct CoachDashboardView: View {
  let attentionCount: Int
  let pendingCount: Int
  let context: CoachStudentDetailContext
  var rows: [StudentRosterRowModel] = []
  var onOpenReceiving: @MainActor () -> Void = {}
  var onOpenRoster: @MainActor () -> Void = {}
  @Bindable var viewModel: CoachDashboardViewModel

  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        header
        ScrollView {
          VStack(alignment: .leading, spacing: MeetPRSpacing.base) {
            if let body = viewModel.dailyDigestBody {
              dailyDigest(body)
            }
            if pendingCount > 0 {
              newStudentCard
            }
            signalsSection
            statsCard
          }
          .padding(MeetPRSpacing.base)
        }
        .scrollIndicators(.hidden)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color.MeetPR.bg)
      .hideNavigationBar()
      .task {
        await viewModel.loadIfNeeded()
      }
      .refreshable {
        await viewModel.reload()
      }
    }
  }

  private var header: some View {
    HStack(alignment: .bottom) {
      VStack(alignment: .leading, spacing: MeetPRSpacing.xs) {
        HStack(spacing: MeetPRSpacing.sm) {
          Text(Self.headerEyebrow)
            .font(Font.MeetPR.monoLabel)
            .tracking(Font.MeetPR.monoLabelTracking)
            .foregroundStyle(Color.MeetPR.fgSecondary)
          Rectangle()
            .fill(Color.MeetPR.brandRed)
            .frame(width: 32, height: 1)
        }
        Text("今日")
          .font(.system(size: 36, weight: .heavy))
          .foregroundStyle(Color.MeetPR.fgPrimary)
      }
      Spacer()
    }
    .padding(.horizontal, MeetPRSpacing.base)
    .padding(.top, MeetPRSpacing.xs)
    .padding(.bottom, MeetPRSpacing.md)
  }

  private func dailyDigest(_ body: String) -> some View {
    Text(body)
      .font(.system(size: 12, design: .monospaced))
      .foregroundStyle(Color.MeetPR.fgSecondary)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, MeetPRSpacing.md)
      .padding(.vertical, MeetPRSpacing.sm)
      .background(Color.MeetPR.surface1)
      .clipShape(.rect(cornerRadius: MeetPRRadius.md))
      .overlay {
        RoundedRectangle(cornerRadius: MeetPRRadius.md)
          .stroke(Color.MeetPR.border, lineWidth: 1)
      }
      .accessibilityIdentifier("coach-daily-digest")
  }

  private var newStudentCard: some View {
    Button(action: onOpenReceiving) {
      VStack(alignment: .leading, spacing: 0) {
        HStack(spacing: MeetPRSpacing.sm) {
          Circle().fill(Color.MeetPR.brandRed).frame(width: 6, height: 6)
          Text("新学员请求 // \(pendingCount.formatted(.number.precision(.integerLength(2))))")
            .font(Font.MeetPR.monoLabel)
            .tracking(Font.MeetPR.monoLabelTracking)
            .foregroundStyle(Color.MeetPR.brandRed)
        }
        Text("\(pendingCount) 名新学员等待你接收")
          .font(.system(size: 17, weight: .semibold))
          .foregroundStyle(Color.MeetPR.fgPrimary)
          .padding(.top, MeetPRSpacing.sm)
        Text("查看接收队列 →")
          .font(.system(size: 14))
          .foregroundStyle(Color.MeetPR.fgSecondary)
          .padding(.top, MeetPRSpacing.xs + 2)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(MeetPRSpacing.base)
      .background(Color.MeetPR.surface2)
      .clipShape(.rect(cornerRadius: MeetPRRadius.lg))
      .overlay {
        RoundedRectangle(cornerRadius: MeetPRRadius.lg)
          .stroke(Color.MeetPR.brandRed.opacity(0.3), lineWidth: 1)
      }
    }
    .buttonStyle(.plain)
  }

  private var signalsSection: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
      Text(signalSectionTitle)
        .font(Font.MeetPR.monoLabel)
        .tracking(Font.MeetPR.monoLabelTracking)
        .foregroundStyle(Color.MeetPR.fgSecondary)
      signalsCard
    }
  }

  private var signalSectionTitle: String {
    guard viewModel.loadState == .loaded else { return "信号" }
    return "今天 \(viewModel.signals.count) 个需要你"
  }

  @ViewBuilder
  private var signalsCard: some View {
    switch viewModel.loadState {
    case .loading:
      signalMessageCard("信号加载中…")
    case .failed:
      signalMessageCard("信号加载失败,下拉重试")
    case .loaded:
      if viewModel.signals.isEmpty {
        emptySignalsCard
      } else {
        VStack(spacing: 0) {
          ForEach(viewModel.signals) { signal in
            NavigationLink {
              StudentDetailView(
                summary: CoachStudentSummary(
                  id: signal.studentID,
                  displayName: signal.studentName,
                  status: .active
                ),
                context: context
              )
            } label: {
              CoachSignalRow(
                signal: signal,
                showsTopBorder: signal.id != viewModel.signals.first?.id
              )
            }
            .buttonStyle(.plain)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.MeetPR.surface1)
        .clipShape(.rect(cornerRadius: MeetPRRadius.lg))
        .overlay {
          RoundedRectangle(cornerRadius: MeetPRRadius.lg)
            .stroke(Color.MeetPR.border, lineWidth: 1)
        }
      }
    }
  }

  private func signalMessageCard(_ message: String) -> some View {
    Text(message)
      .font(.system(size: 14))
      .foregroundStyle(Color.MeetPR.fgTertiary)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(MeetPRSpacing.base)
      .background(Color.MeetPR.surface1)
      .clipShape(.rect(cornerRadius: MeetPRRadius.lg))
      .overlay {
        RoundedRectangle(cornerRadius: MeetPRRadius.lg)
          .stroke(Color.MeetPR.border, lineWidth: 1)
      }
  }

  private var emptySignalsCard: some View {
    HStack(spacing: MeetPRSpacing.md) {
      Image(systemName: "checkmark.circle")
        .font(.system(size: 20))
        .foregroundStyle(Color.MeetPR.green)
      Text("今天没有需要你处理的学员")
        .font(.system(size: 14))
        .foregroundStyle(Color.MeetPR.fgSecondary)
      Spacer()
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(MeetPRSpacing.base)
    .background(Color.MeetPR.surface1)
    .clipShape(.rect(cornerRadius: MeetPRRadius.lg))
    .overlay {
      RoundedRectangle(cornerRadius: MeetPRRadius.lg)
        .stroke(Color.MeetPR.border, lineWidth: 1)
    }
  }

  private var statsCard: some View {
    HStack(spacing: 0) {
      statContent(
        label: "学员",
        value: activeCount,
        unit: "活跃",
        valueColor: Color.MeetPR.fgPrimary
      )
      divider
      Button(action: onOpenRoster) {
        statContent(
          label: "待关注",
          value: attentionCount,
          unit: "学员",
          valueColor: attentionCount > 0 ? Color.MeetPR.brandRed : Color.MeetPR.fgPrimary
        )
      }
      .buttonStyle(.plain)
    }
    .padding(MeetPRSpacing.base)
    .background(Color.MeetPR.surface1)
    .clipShape(.rect(cornerRadius: MeetPRRadius.lg))
    .overlay {
      RoundedRectangle(cornerRadius: MeetPRRadius.lg)
        .stroke(Color.MeetPR.border, lineWidth: 1)
    }
  }

  private var divider: some View {
    Rectangle()
      .fill(Color.MeetPR.border)
      .frame(width: 1, height: 48)
      .padding(.horizontal, MeetPRSpacing.md)
  }

  private func statContent(label: String, value: Int, unit: String, valueColor: Color) -> some View
  {
    VStack(alignment: .leading, spacing: MeetPRSpacing.xs) {
      Text(label)
        .font(Font.MeetPR.monoLabel)
        .tracking(Font.MeetPR.monoLabelTracking)
        .foregroundStyle(Color.MeetPR.brandRed)
      HStack(alignment: .lastTextBaseline, spacing: MeetPRSpacing.xs) {
        Text("\(value)")
          .font(.system(size: 36, weight: .heavy).monospacedDigit())
          .foregroundStyle(valueColor)
        Text(unit)
          .font(.system(size: 13))
          .foregroundStyle(Color.MeetPR.fgTertiary)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var activeCount: Int {
    rows.filter { $0.student.status == .active }.count
  }

  private static var headerEyebrow: String {
    Date().formatted(
      .dateTime.month().day().weekday(.wide).locale(Locale(identifier: "zh_Hans_CN")))
  }
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct CoachSignalRow: View {
  let signal: CoachSignal
  let showsTopBorder: Bool

  var body: some View {
    HStack(alignment: .top, spacing: MeetPRSpacing.md) {
      Circle()
        .fill(signal.severity.dotColor)
        .frame(width: 8, height: 8)
        .padding(.top, 6)
        .accessibilityIdentifier("coach-signal-dot-\(signal.severity.rawValue)")
      VStack(alignment: .leading, spacing: 4) {
        HStack(alignment: .firstTextBaseline, spacing: MeetPRSpacing.sm) {
          Text(signal.studentName)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Color.MeetPR.fgPrimary)
          Text(signal.type.displayLabel)
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(Color.MeetPR.fgTertiary)
        }
        Text(signal.reason)
          .font(.system(size: 13))
          .foregroundStyle(Color.MeetPR.fgSecondary)
          .multilineTextAlignment(.leading)
          .lineLimit(2)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      Image(systemName: "chevron.right")
        .font(.system(size: 15))
        .foregroundStyle(Color.MeetPR.fgTertiary)
        .padding(.top, 4)
    }
    .padding(.horizontal, MeetPRSpacing.base)
    .padding(.vertical, MeetPRSpacing.base - 2)
    .frame(minHeight: 68)
    .overlay(alignment: .top) {
      if showsTopBorder {
        Rectangle().fill(Color.MeetPR.border).frame(height: 1)
      }
    }
  }
}

extension CoachSignalType {
  var displayLabel: String {
    switch self {
    case .missedTraining: "缺练"
    case .weightFailed: "被压"
    case .personalRecord: "PR"
    }
  }
}

extension CoachSignalSeverity {
  var dotColor: Color {
    switch self {
    case .red: Color.MeetPR.brandRed
    case .yellow: Color.MeetPR.signalYellow
    case .green: Color.MeetPR.green
    }
  }
}
