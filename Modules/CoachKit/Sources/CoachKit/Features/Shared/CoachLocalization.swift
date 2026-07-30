import Foundation

/// CoachKit 各 feature 共用的本地化取值口。
///
/// 三个 feature 的 strings 文件各自复制一份 `localized`/`replacing` 之后,
/// 既是平行工具也容易漂移(review-loop 2026-07-30)。统一放这里,
/// 各 feature 只负责声明自己的 key。
enum CoachLocalization {
  static func localized(_ key: String.LocalizationValue) -> String {
    String(localized: key, bundle: .module)
  }

  static func replacing(
    _ key: String.LocalizationValue,
    values: [String: String]
  ) -> String {
    values.reduce(localized(key)) { partial, entry in
      partial.replacingOccurrences(of: "{\(entry.key)}", with: entry.value)
    }
  }
}
