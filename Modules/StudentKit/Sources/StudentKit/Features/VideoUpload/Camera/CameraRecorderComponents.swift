#if os(iOS)
  import AVFoundation
  import DesignSystem
  import SwiftUI

  struct RecorderCaptureView: View {
    let session: AVCaptureSession
    let phase: CameraRecorderPhase
    let recordedDuration: TimeInterval
    let maximumDuration: TimeInterval
    let onClose: () -> Void
    let onRecordToggle: () -> Void

    var body: some View {
      ZStack {
        CameraPreviewView(session: session)
          .ignoresSafeArea()

        VStack {
          HStack {
            RecorderCloseButton(action: onClose)
            Spacer()
            RecorderTimeView(
              isRecording: phase == .recording || phase == .stopping,
              recordedDuration: recordedDuration,
              maximumDuration: maximumDuration
            )
          }
          .padding()

          Spacer()

          RecorderButton(
            isRecording: phase == .recording || phase == .stopping,
            isEnabled: phase == .ready || phase == .recording,
            action: onRecordToggle
          )
          .padding(.bottom, 42)
        }
      }
    }
  }

  struct RecorderTimeView: View {
    let isRecording: Bool
    let recordedDuration: TimeInterval
    let maximumDuration: TimeInterval

    var body: some View {
      VStack(alignment: .trailing, spacing: 4) {
        Text(RecorderTimeFormatter.string(from: recordedDuration))
          .font(.title3.monospacedDigit().bold())
          .foregroundStyle(.white)
        if isRecording {
          let remaining = max(0, maximumDuration - recordedDuration)
          Text(
            StudentStrings.replacing(
              .cameraRecorderComponents001,
              values: ["\(RecorderTimeFormatter.string(from: maximumDuration))"])
          )
          .font(.caption)
          .foregroundStyle(.white.opacity(0.8))
          if remaining <= 10 {
            Text(
              StudentStrings.replacing(
                .cameraRecorderComponents002, values: ["\(Int(remaining.rounded(.up)))"])
            )
            .font(.caption.bold())
            .foregroundStyle(.yellow)
          }
        }
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(.black.opacity(0.52))
      .clipShape(.rect(cornerRadius: 12))
    }
  }

  struct RecorderButton: View {
    let isRecording: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
      Button(action: action) {
        ZStack {
          Circle()
            .stroke(.white, lineWidth: 5)
            .frame(width: 82, height: 82)
          if isRecording {
            RoundedRectangle(cornerRadius: 7)
              .fill(.red)
              .frame(width: 34, height: 34)
          } else {
            Circle()
              .fill(.red)
              .frame(width: 68, height: 68)
          }
        }
      }
      .disabled(!isEnabled)
      .opacity(isEnabled ? 1 : 0.65)
      .accessibilityLabel(
        isRecording
          ? StudentStrings.localized(.cameraRecorderComponents003)
          : StudentStrings.localized(.cameraRecorderComponents004))
    }
  }

  struct RecorderReviewView: View {
    let url: URL
    let duration: TimeInterval
    @Binding var saveToPhotoLibrary: Bool
    let isBusy: Bool
    let showsTrimSuggestion: Bool
    let onTrim: () -> Void
    let onNeverSuggestTrim: () -> Void
    let onUse: () -> Void
    let onClose: () -> Void

    var body: some View {
      VStack(spacing: 0) {
        ZStack(alignment: .topLeading) {
          LoopingVideoPlayer(url: url)
            .id(url)
            .ignoresSafeArea(edges: .top)
          RecorderCloseButton(action: onClose)
            .padding()
        }

        VStack(spacing: 18) {
          Text(
            StudentStrings.replacing(
              .cameraRecorderComponents005,
              values: ["\(RecorderTimeFormatter.string(from: duration))"])
          )
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size12, weight: .semibold))
          .foregroundStyle(.white.opacity(0.82))

          Toggle(StudentStrings.localized(.cameraRecorderComponents006), isOn: $saveToPhotoLibrary)
            .tint(.yellow)
            .foregroundStyle(.white)

          if showsTrimSuggestion {
            HStack(spacing: MeetPRSpacing.space1) {
              Text(StudentStrings.localized(.cameraRecorderComponents007))
                .font(.MeetPR.body(size: MeetPRFontMetrics.size11))
                .foregroundStyle(Color.MeetPR.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

              Spacer(minLength: MeetPRSpacing.space1)

              Button(
                StudentStrings.localized(.cameraRecorderComponents008), action: onNeverSuggestTrim
              )
              .font(.MeetPR.body(size: MeetPRFontMetrics.size11, weight: .semibold))
              .foregroundStyle(Color.MeetPR.textSecondary)
            }
          }

          HStack(spacing: 16) {
            Button(StudentStrings.localized(.cameraRecorderComponents009), action: onTrim)
              .buttonStyle(.bordered)
              .tint(.white)
              .foregroundStyle(.white)
              .frame(maxWidth: .infinity)
              .disabled(isBusy)

            Button(StudentStrings.localized(.cameraRecorderComponents010), action: onUse)
              .buttonStyle(.borderedProminent)
              .tint(.yellow)
              .foregroundStyle(.black)
              .frame(maxWidth: .infinity)
              .disabled(isBusy)
          }
          .controlSize(.large)
        }
        .padding(24)
        .background(.black)
      }
    }
  }

  struct RecorderStatusAction {
    let title: String
    let systemImage: String?
    let action: () -> Void

    init(
      title: String,
      systemImage: String? = nil,
      action: @escaping () -> Void
    ) {
      self.title = title
      self.systemImage = systemImage
      self.action = action
    }
  }

  struct RecorderStatusView: View {
    let systemImage: String
    let title: String
    let message: String
    var primaryAction: RecorderStatusAction?
    var secondaryAction: RecorderStatusAction?

    var body: some View {
      VStack(spacing: 20) {
        VStack(spacing: 12) {
          Image(systemName: systemImage)
            .font(.largeTitle)
          Text(title)
            .font(.title3.bold())
          Text(message)
            .multilineTextAlignment(.center)
            .foregroundStyle(.white.opacity(0.78))
        }
        .foregroundStyle(.white)

        if let primaryAction {
          Button(action: primaryAction.action) {
            if let systemImage = primaryAction.systemImage {
              Label(primaryAction.title, systemImage: systemImage)
            } else {
              Text(primaryAction.title)
            }
          }
          .buttonStyle(.borderedProminent)
          .tint(.yellow)
          .foregroundStyle(.black)
        }

        if let secondaryAction {
          Button(secondaryAction.title, action: secondaryAction.action)
            .foregroundStyle(.white)
        }
      }
      .padding()
    }
  }

  struct RecorderCloseButton: View {
    let action: () -> Void

    var body: some View {
      Button(action: action) {
        Image(systemName: "xmark")
          .font(.headline)
          .foregroundStyle(.white)
          .frame(width: 44, height: 44)
          .background(.black.opacity(0.52))
          .clipShape(.circle)
      }
      .accessibilityLabel(StudentStrings.localized(.cameraRecorderComponents011))
    }
  }

  struct RecorderToastView: View {
    let message: String

    var body: some View {
      VStack {
        Spacer()
        Text(message)
          .font(.callout)
          .foregroundStyle(.white)
          .padding(.horizontal)
          .padding(.vertical, 12)
          .background(.black.opacity(0.82))
          .clipShape(.capsule)
          .padding(.bottom, 32)
      }
    }
  }

  enum RecorderTimeFormatter {
    static func string(from duration: TimeInterval) -> String {
      let totalSeconds = max(0, Int(duration.rounded(.down)))
      let minutes = totalSeconds / 60
      let seconds = totalSeconds % 60
      let secondsText = seconds < 10 ? "0\(seconds)" : "\(seconds)"
      return "\(minutes):\(secondsText)"
    }
  }
#endif
