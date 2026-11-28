import DesignSystem
import SwiftUI

struct RestTimerOverlay: View {
  @Bindable var session: RestRingSession
  let available: Bool
  let hidden: Bool
  let hasOtherPresentation: Bool
  let seconds: Int
  let exercise: String
  let headerBottom: CGFloat
  let dockTop: CGFloat?
  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    ZStack {
      if available && !hidden && !hasOtherPresentation {
        RestRingFloatingButton(
          remaining: session.model.phase == .idle
            ? seconds : session.model.remaining(at: session.clock),
          total: session.model.totalSeconds,
          running: session.model.phase == .running, done: session.model.phase == .done,
          showsHint: session.settings.showsHint,
          headerBottom: headerBottom, dockTop: dockTop,
          onTap: { session.tap(seconds: seconds, exercise: exercise) },
          onHold: {
            RestRingFeedback.hold()
            session.openSettings()
          })
      }
    }
    .onChange(of: canPresentFirstSettings, initial: true) { _, _ in
      session.updatePresentationContext(
        isTrainable: available && !hidden,
        hasOtherPresentation: hasOtherPresentation || scenePhase != .active)
    }
    .onChange(of: scenePhase, initial: true) { _, phase in
      session.setForeground(phase == .active)
    }
    #if os(iOS)
      .fullScreenCover(item: $session.presentation) { presentation in
        RestRingModal(session: session, presentation: presentation)
        .presentationBackground(.clear)
        .interactiveDismissDisabled()
      }
    #else
      .sheet(item: $session.presentation) { presentation in
        RestRingModal(session: session, presentation: presentation)
      }
    #endif
    .transaction { $0.disablesAnimations = true }
  }

  private var canPresentFirstSettings: Bool {
    available && !hidden && !hasOtherPresentation && scenePhase == .active
  }
}

private struct RestRingModal: View {
  @Bindable var session: RestRingSession
  let presentation: RestRingSession.Presentation

  var body: some View {
    GeometryReader { proxy in
      let settings = presentation == .settings
      let diameter = settings ? 340.0 : 280.0
      let scale = min(1, (proxy.size.width - 12) / diameter)
      ZStack {
        Button(action: session.dismiss) {
          Color.black.opacity(0.6).contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(StudentStrings.localized(settings ? .restRingSave : .restRingDismiss))
        .accessibilityIdentifier("restRing.scrim")
        if settings {
          RestRingSettingsDisk(
            mainSeconds: $session.settings.mainSeconds,
            accessorySeconds: $session.settings.accessorySeconds,
            vibration: $session.settings.vibration, sound: $session.settings.sound
          )
          .scaleEffect(scale)
        } else {
          RestRingCountdownDisk(
            remaining: session.model.remaining(at: session.clock),
            total: session.model.totalSeconds,
            exercise: session.model.exercise, onSettings: session.openSettings,
            onAdjust: session.adjust, onEnd: session.end
          )
          .scaleEffect(scale)
          Text(StudentStrings.localized(.restRingDismiss))
            .font(.system(size: 12))
            .foregroundStyle(Color.MeetPR.inkOnCTAFill)
            .multilineTextAlignment(.center)
            .frame(maxWidth: proxy.size.width - 24)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2 + diameter * scale / 2 + 24)
            .allowsHitTesting(false)
        }
      }
      .frame(width: proxy.size.width, height: proxy.size.height)
    }
    .ignoresSafeArea()
    .onChange(of: session.settings.sound) { _, _ in session.applyAlertSettings() }
    .onChange(of: session.settings.vibration) { _, _ in session.applyAlertSettings() }
  }
}
