// swiftlint:disable file_length
import Foundation
import SwiftUI

/// One training-set row, following the five-column `SetRow.dc.html` grid.
@MainActor
// swiftlint:disable:next type_body_length
public struct SetRow: View {
  public enum Status: Equatable, Sendable {
    case pending
    case done
    case failed
  }

  public enum VideoState: Equatable, Sendable {
    case none
    case uploading
    case uploaded
    case failed
  }

  @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

  let index: Int
  let weight: Double?
  let reps: Int
  let rpe: Double
  let status: Status
  let videoState: VideoState
  private let indexAccessibilityIdentifier: String?
  private let prescriptionDisplay: ExerciseSetRecord.PrescriptionDisplay?
  private let onEdit: (@MainActor () -> Void)?
  private let onVideoAction: (@MainActor () -> Void)?

  public init(
    index: Int,
    weight: Double?,
    reps: Int,
    rpe: Double,
    status: Status,
    videoState: VideoState,
    indexAccessibilityIdentifier: String? = nil,
    prescriptionDisplay: ExerciseSetRecord.PrescriptionDisplay? = nil,
    onEdit: (@MainActor () -> Void)? = nil,
    onVideoAction: (@MainActor () -> Void)? = nil
  ) {
    self.index = index
    self.weight = weight
    self.reps = reps
    self.rpe = rpe
    self.status = status
    self.videoState = videoState
    self.indexAccessibilityIdentifier = indexAccessibilityIdentifier
    self.prescriptionDisplay = prescriptionDisplay
    self.onEdit = onEdit
    self.onVideoAction = onVideoAction
  }

  public var body: some View {
    HStack(spacing: MeetPRSpacing.zero) {
      if let onEdit {
        Button(action: onEdit) {
          metrics
        }
        .buttonStyle(.plain)
      } else {
        metrics
      }

      trailingColumn
    }
    .padding(.horizontal, SetRowContract.horizontalPadding)
    .frame(minHeight: SetRowContract.minimumRowHeight)
    .overlay(alignment: .bottom) {
      Rectangle()
        .fill(Color.MeetPR.borderHairline)
        .frame(height: 1)
    }
    .contentShape(.rect)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilityText)
    .accessibilityHint(onEdit == nil ? "" : DesignSystemStrings.tapToEditSet)
  }

  private var metrics: some View {
    HStack(spacing: MeetPRSpacing.zero) {
      Text(index.formatted())
        .font(.MeetPR.mono(size: MeetPRFontMetrics.size13, weight: .bold))
        .foregroundStyle(status == .pending ? Color.MeetPR.textDim : Color.MeetPR.textMuted)
        .frame(width: SetRowContract.indexColumnWidth, alignment: .leading)
        .optionalAccessibilityIdentifier(indexAccessibilityIdentifier)

      weightMetric

      Text(reps.formatted())
        .font(.MeetPR.mono(size: MeetPRFontMetrics.size14))
        .foregroundStyle(valueColor)
        .frame(maxWidth: .infinity)

      Text(prescriptionDisplay?.rpeText ?? numberText(rpe, alwaysShowsFraction: true))
        .font(.MeetPR.mono(size: MeetPRFontMetrics.size14))
        .foregroundStyle(prescriptionValueColor)
        .frame(maxWidth: .infinity)
    }
    .frame(maxWidth: .infinity)
    .frame(minHeight: SetRowContract.minimumRowHeight)
    .contentShape(.rect)
  }

  @ViewBuilder
  private var weightMetric: some View {
    if let prescriptionDisplay {
      VStack(alignment: .leading, spacing: MeetPRSpacing.point1) {
        HStack(alignment: .firstTextBaseline, spacing: MeetPRSpacing.point3) {
          Text(prescriptionDisplay.weightPrimary)
            .font(.MeetPR.mono(size: MeetPRFontMetrics.size14, weight: .bold))
          if let unit = prescriptionDisplay.weightUnit {
            Text(unit)
              .font(.MeetPR.mono(size: MeetPRFontMetrics.size10, weight: .medium))
              .foregroundStyle(Color.MeetPR.textMuted)
          }
        }
        .foregroundStyle(prescriptionWeightColor)

        if let secondary = prescriptionDisplay.weightSecondary {
          Text(secondary)
            .font(.MeetPR.mono(size: MeetPRFontMetrics.size9))
            .foregroundStyle(
              prescriptionDisplay.emphasis == .muted
                ? Color.MeetPR.textDim
                : Color.MeetPR.textMuted
            )
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    } else {
      Text(weight.map { numberText($0) } ?? "—")
        .font(.MeetPR.mono(size: MeetPRFontMetrics.size15, weight: .bold))
        .foregroundStyle(valueColor)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private var trailingColumn: some View {
    HStack(spacing: SetRowContract.iconSpacing) {
      statusIcon

      if let onVideoAction {
        Button(action: onVideoAction) {
          videoIcon
        }
        .buttonStyle(.plain)
        .contentShape(
          .rect.inset(
            by: -(SetRowContract.videoHitTarget - SetRowContract.cameraFrame) / 2
          )
        )
        .accessibilityLabel(videoAccessibilityText)
      } else {
        videoIcon
      }
    }
    .frame(
      width: SetRowContract.trailingColumnWidth,
      height: SetRowContract.minimumRowHeight,
      alignment: .trailing
    )
  }

  private var valueColor: Color {
    switch status {
    case .failed: Color.MeetPR.dangerMuted
    case .done: Color.MeetPR.textPrimary
    case .pending: Color.MeetPR.textDim
    }
  }

  private var prescriptionWeightColor: Color {
    guard let prescriptionDisplay else { return valueColor }
    if status == .failed { return Color.MeetPR.dangerMuted }
    return prescriptionDisplay.emphasis == .muted
      ? Color.MeetPR.textMuted
      : Color.MeetPR.textPrimary
  }

  private var prescriptionValueColor: Color {
    guard let prescriptionDisplay else { return valueColor }
    if status == .failed { return Color.MeetPR.dangerMuted }
    return prescriptionDisplay.emphasis == .muted
      ? Color.MeetPR.textDim
      : Color.MeetPR.textSecondary
  }

  @ViewBuilder
  private var statusIcon: some View {
    switch status {
    case .done:
      CheckmarkIconShape()
        .stroke(
          Color.MeetPR.success,
          style: StrokeStyle(
            lineWidth: SetRowContract.doneStroke,
            lineCap: .round,
            lineJoin: .round
          )
        )
        .frame(width: SetRowContract.doneFrame, height: SetRowContract.doneFrame)
        .foregroundStyle(Color.MeetPR.success)
    case .failed:
      XmarkIconShape()
        .stroke(
          Color.MeetPR.danger,
          style: StrokeStyle(lineWidth: SetRowContract.failedStroke, lineCap: .round)
        )
        .frame(width: SetRowContract.failedFrame, height: SetRowContract.failedFrame)
    case .pending:
      PendingIconShape()
        .stroke(Color.MeetPR.textGhost, lineWidth: SetRowContract.pendingStroke)
        .frame(width: SetRowContract.pendingFrame, height: SetRowContract.pendingFrame)
    }
  }

  private var videoIcon: some View {
    CameraIconShape()
      .stroke(
        videoColor,
        style: StrokeStyle(
          lineWidth: SetRowContract.cameraStroke,
          lineCap: .round,
          lineJoin: .round
        )
      )
      .frame(width: SetRowContract.cameraFrame, height: SetRowContract.cameraFrame)
      .overlay {
        if differentiateWithoutColor && videoState == .failed {
          VideoSlashShape()
            .stroke(
              Color.MeetPR.danger,
              style: StrokeStyle(lineWidth: SetRowContract.cameraStroke, lineCap: .round)
            )
        }
      }
  }

  private var videoColor: Color {
    switch videoState {
    case .none: Color.MeetPR.textGhost
    case .uploading, .uploaded: Color.MeetPR.textMuted
    case .failed: Color.MeetPR.danger
    }
  }

  private var accessibilityText: String {
    let statusText =
      switch status {
      case .pending: DesignSystemStrings.setPending
      case .done: DesignSystemStrings.setDone
      case .failed: DesignSystemStrings.setFailed
      }
    let videoText =
      switch videoState {
      case .none: DesignSystemStrings.noVideo
      case .uploading, .uploaded: DesignSystemStrings.videoAttached
      case .failed: DesignSystemStrings.videoUploadFailed
      }
    let weightText =
      prescriptionDisplay.map {
        [$0.weightPrimary, $0.weightUnit, $0.weightSecondary]
          .compactMap { $0 }
          .joined(separator: " ")
      }
      ?? weight.map { DesignSystemStrings.setWeight(numberText($0)) }
      ?? DesignSystemStrings.noSuggestedWeight
    let metrics = DesignSystemStrings.setMetrics(
      weight: weightText,
      reps: reps,
      rpe: prescriptionDisplay?.rpeText ?? numberText(rpe, alwaysShowsFraction: true)
    )
    return DesignSystemStrings.setAccessibilityLabel(
      index: index,
      metrics: metrics,
      status: statusText,
      video: videoText
    )
  }

  private var videoAccessibilityText: String {
    switch videoState {
    case .none: DesignSystemStrings.noVideo
    case .uploading, .uploaded: DesignSystemStrings.videoAttached
    case .failed: DesignSystemStrings.videoUploadFailedRetry
    }
  }

  private func numberText(_ value: Double, alwaysShowsFraction: Bool = false) -> String {
    if alwaysShowsFraction {
      return value.formatted(.number.precision(.fractionLength(1)))
    }
    return value.formatted(.number.precision(.fractionLength(0...2)))
  }
}

extension View {
  @ViewBuilder
  fileprivate func optionalAccessibilityIdentifier(_ identifier: String?) -> some View {
    if let identifier {
      accessibilityIdentifier(identifier)
    } else {
      self
    }
  }
}

enum SetRowContract {
  static let indexColumnWidth: CGFloat = 22
  static let trailingColumnWidth: CGFloat = 64
  static let videoHitTarget: CGFloat = 44
  static let minimumRowHeight: CGFloat = 44
  static let horizontalPadding: CGFloat = 14
  static let iconSpacing: CGFloat = 11
  static let doneFrame: CGFloat = 16
  static let doneStroke: CGFloat = 2.5
  static let failedFrame: CGFloat = 15
  static let failedStroke: CGFloat = 2.6
  static let pendingFrame: CGFloat = 15
  static let pendingStroke: CGFloat = 2.4
  static let cameraFrame: CGFloat = 19
  static let cameraStroke: CGFloat = 2
}

private struct CheckmarkIconShape: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: rect.svgPoint(x: 20, y: 6))
    path.addLine(to: rect.svgPoint(x: 9, y: 17))
    path.addLine(to: rect.svgPoint(x: 4, y: 12))
    return path
  }
}

private struct XmarkIconShape: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: rect.svgPoint(x: 18, y: 6))
    path.addLine(to: rect.svgPoint(x: 6, y: 18))
    path.move(to: rect.svgPoint(x: 6, y: 6))
    path.addLine(to: rect.svgPoint(x: 18, y: 18))
    return path
  }
}

private struct PendingIconShape: Shape {
  func path(in rect: CGRect) -> Path {
    let center = rect.svgPoint(x: 12, y: 12)
    let radius = min(rect.width, rect.height) * 9 / 24
    return Path(
      ellipseIn: CGRect(
        x: center.x - radius,
        y: center.y - radius,
        width: radius * 2,
        height: radius * 2
      )
    )
  }
}

private struct CameraIconShape: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    let cameraBody = CGRect(
      x: rect.svgX(2.5),
      y: rect.svgY(7),
      width: rect.width * 12.5 / 24,
      height: rect.height * 10 / 24
    )
    path.addRoundedRect(
      in: cameraBody,
      cornerSize: CGSize(width: rect.width * 2.5 / 24, height: rect.height * 2.5 / 24)
    )
    path.move(to: rect.svgPoint(x: 15, y: 10.5))
    path.addLine(to: rect.svgPoint(x: 21, y: 7.5))
    path.addLine(to: rect.svgPoint(x: 21, y: 16.5))
    path.addLine(to: rect.svgPoint(x: 15, y: 13.5))
    path.closeSubpath()
    return path
  }
}

private struct VideoSlashShape: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: rect.svgPoint(x: 4, y: 20))
    path.addLine(to: rect.svgPoint(x: 20, y: 4))
    return path
  }
}

extension CGRect {
  fileprivate func svgX(_ value: CGFloat) -> CGFloat {
    minX + (value / 24) * width
  }

  fileprivate func svgY(_ value: CGFloat) -> CGFloat {
    minY + (value / 24) * height
  }

  fileprivate func svgPoint(x: CGFloat, y: CGFloat) -> CGPoint {
    CGPoint(x: svgX(x), y: svgY(y))
  }
}

#Preview("SetRow · All States · Dark") {
  VStack(spacing: MeetPRSpacing.zero) {
    SetRow(index: 1, weight: 175, reps: 3, rpe: 8.5, status: .done, videoState: .uploaded)
    SetRow(index: 2, weight: 175, reps: 3, rpe: 8.5, status: .failed, videoState: .failed)
    SetRow(index: 3, weight: 175, reps: 3, rpe: 8.5, status: .pending, videoState: .none)
    SetRow(index: 4, weight: 175, reps: 3, rpe: 8.5, status: .done, videoState: .uploading)
  }
  .background(Color.MeetPR.surfaceCard)
  .preferredColorScheme(.dark)
}

#Preview("SetRow · All States · Light") {
  VStack(spacing: MeetPRSpacing.zero) {
    SetRow(index: 1, weight: 175, reps: 3, rpe: 8.5, status: .done, videoState: .uploaded)
    SetRow(index: 2, weight: 175, reps: 3, rpe: 8.5, status: .failed, videoState: .failed)
    SetRow(index: 3, weight: 175, reps: 3, rpe: 8.5, status: .pending, videoState: .none)
    SetRow(index: 4, weight: 175, reps: 3, rpe: 8.5, status: .done, videoState: .uploading)
  }
  .background(Color.MeetPR.surfaceCard)
  .preferredColorScheme(.light)
}
