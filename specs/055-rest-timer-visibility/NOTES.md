# Spec 055 — 实装期 spec 外发现(不在本卡顺手改)

- **TodayWorkoutViewModel.swift 贴着 file_length 上限**:本卡收敛后 398/400 行(swiftlint
  file_length error 阈值 400)。下一个动这个文件的卡大概率顶破,届时应做真拆分(如把
  draft-building 或 rest-timer 关注点拆出去,需调私有成员访问级),不要再靠删注释缩行。
- **AGENTS.md §本地化(xcstrings)与仓库现实不符**:约定写「用户可见字符串走
  Localizable.xcstrings」,但全仓不存在任何 .xcstrings,存量文案(含「记录此组」等)全部
  硬编码。本卡新文案跟随存量惯例硬编码;要么补一次性的 string catalog 引入卡,要么修订
  AGENTS.md 该节。
