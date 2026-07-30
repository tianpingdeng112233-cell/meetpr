/// Coach-side half of the evaluation feature seal.
///
/// 与学员端 private 的 `StudentKit.BindGateViewModel.evaluationSealed` 成对；
/// 解封要翻两处。
enum CoachEvaluationSeal {
  static let isSealed = true

  static func shouldRenderBanner(isBannerVisible: Bool) -> Bool {
    !isSealed && isBannerVisible
  }

  static var shouldLoadEvaluation: Bool {
    !isSealed
  }
}
