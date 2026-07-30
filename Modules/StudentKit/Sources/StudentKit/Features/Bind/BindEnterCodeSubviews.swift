import CoreModels
import DesignSystem
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct BindEnterCodeHeader: View {
  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.space3) {
      Text("输入教练邀请码")
        .font(Font.MeetPR.display(size: MeetPRFontMetrics.size30, weight: .extraBold))
        .tracking(-0.6)
        .foregroundStyle(Color.MeetPR.textPrimary)

      Text("绑定之后,教练排的计划会直接出现在你的「今日」,你的每组记录也会同步给他。")
        .font(Font.MeetPR.body(size: MeetPRFontMetrics.size14))
        .lineSpacing(BindEnterCodeMetrics.LineSpacing.body14)
        .foregroundStyle(Color.MeetPR.textSecondary)
        .fixedSize(horizontal: false, vertical: true)
    }
  }
}

/// Says where the code comes from, so the student does not have to ask.
///
/// ⚠️ The mockup's copy here was wrong twice over and is corrected against the
/// shipped app: the coach reaches codes via 「我的」→「我的邀请码」 (see
/// `CoachMyProfileView`, which pushes `InviteCodesView`), not 「学员」→「加学员」;
/// and the drawing's "或者直接发你一个链接" is dropped because the app registers
/// no URL scheme or universal link at all.
@available(iOS 17.0, macOS 14.0, *)
struct BindInstructionsCard: View {
  var body: some View {
    HStack(alignment: .top, spacing: MeetPRSpacing.space3) {
      Image(systemName: "info.circle")
        .font(.system(size: MeetPRFontMetrics.size17))
        .foregroundStyle(Color.MeetPR.textTertiary)

      Text(
        "邀请码在教练那边:他打开 MeetPR 教练端 →「我的」→「我的邀请码」,"
          + "会看到一串 \(InviteCodeFormat.length) 位码。"
      )
      .font(Font.MeetPR.body(size: 12.5))
      .lineSpacing(BindEnterCodeMetrics.LineSpacing.caption125Loose)
      .foregroundStyle(Color.MeetPR.textSecondary)
      .fixedSize(horizontal: false, vertical: true)
    }
    .padding(.vertical, MeetPRSpacing.point14)
    .padding(.horizontal, MeetPRSpacing.point15)
    .frame(maxWidth: .infinity, alignment: .leading)
    .meetPRCardSurface(.card, fill: Color.MeetPR.surfaceRaised)
  }
}

/// The gold submit slab.
///
/// Hand-drawn rather than `GoldCTA`: that component is a shimmering capsule
/// built for the training CTA and cannot be configured into 4b's flat 54pt
/// gold rectangle. The disabled treatment comes from the mockup's own disabled
/// 「下一步」 slab — raised surface under disabled ink, no gold glow — so a
/// non-submittable form never renders a fully lit, tappable-looking button.
@available(iOS 17.0, macOS 14.0, *)
struct BindSubmitCTA: View {
  let isDisabled: Bool
  let isLoading: Bool
  let action: @MainActor () -> Void

  var body: some View {
    Button(action: action) {
      ZStack {
        if isLoading {
          ProgressView().tint(Color.MeetPR.inkOnGold)
        } else {
          Text("提交绑定申请")
            .font(Font.MeetPR.body(size: MeetPRFontMetrics.size16, weight: .bold))
        }
      }
      .foregroundStyle(isDisabled ? Color.MeetPR.textDisabled : Color.MeetPR.inkOnGold)
      .frame(maxWidth: .infinity)
      .frame(height: BindEnterCodeMetrics.ctaHeight)
      .background(isDisabled ? Color.MeetPR.surfaceRaised : Color.MeetPR.gold500)
      .clipShape(.rect(cornerRadius: MeetPRRadius.point14))
      .shadow(
        color: isDisabled ? .clear : Color.MeetPR.gold500.opacity(0.22),
        radius: MeetPRSpacing.point9,
        y: MeetPRSpacing.point6
      )
    }
    .buttonStyle(.plain)
    .disabled(isDisabled || isLoading)
    .accessibilityIdentifier("bind.enterCode.submit")
  }
}

/// Sits beside the CTA only while an invalid-code error is showing. The code
/// itself is never auto-cleared (card §错误态) — this is the explicit way out.
@available(iOS 17.0, macOS 14.0, *)
struct BindClearCodeButton: View {
  let action: () -> Void

  var body: some View {
    Button("清空重输", action: action)
      .font(Font.MeetPR.body(size: MeetPRFontMetrics.size14, weight: .semibold))
      .foregroundStyle(Color.MeetPR.textSecondary)
      .frame(maxWidth: .infinity)
      .frame(height: BindEnterCodeMetrics.secondaryButtonHeight)
      .overlay {
        RoundedRectangle(cornerRadius: MeetPRRadius.control)
          .stroke(Color.MeetPR.borderStrong, lineWidth: 1)
      }
      .contentShape(.rect)
      .accessibilityIdentifier("bind.enterCode.clear")
  }
}

@available(iOS 17.0, macOS 14.0, *)
struct BindNoticeBanner: View {
  let notice: BindNotice

  var body: some View {
    Text(notice.message)
      .font(Font.MeetPR.body(size: MeetPRFontMetrics.size14))
      .foregroundStyle(Color.MeetPR.textPrimary)
      .padding(MeetPRSpacing.space3)
      .frame(maxWidth: .infinity, alignment: .leading)
      .meetPRCardSurface(.card, fill: Color.MeetPR.surfaceRaised)
  }
}
