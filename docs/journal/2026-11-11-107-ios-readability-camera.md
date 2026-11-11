# Spec 107 — iOS 摘要可读性与相机空白（P0，待 David 收货）

## 授权与范围

David 在 Android 线上反馈文字拥挤并选择「上下两行，优先清晰」，随后要求检查 iOS。iOS 默认和 XXXL 原生截图虽然没有截断，仍然混用左右、组次在右上、重量在下等结构；David 明确指出「这还不杂乱吗」。本卡统一为动作名在上、完整组次/重量/强度摘要在下。保留既有字号、颜色、按钮、展开编辑和数据规则。

David 将两端问题定为 P0，但最新指令要求：修完打开模拟器，展示全部适用显示分支，**David 确认收货后再发布**。未获收货前不得打发布 tag、上传或上线。

## 基线与复现

- `origin/release/1.0` / 修改前 HEAD `c2e31f2caff580cf60c71c65f8bb782108a2ad2c`；与已上传 `beta/1.0-37` 的代码相同，差异仅发布台账。
- 工程 MeetPR-demo-latest，scheme MeetPR-DemoStudent / DemoStudent，iPhone 17e（iOS 26.5）。未动两台 demo 机或 Archive 脏树。
- 用户截图的六动作合成处方，原生普通/XXXL 两档证明旧自适应结构缺乏一致阅读顺序。不能把“无截断”当作“清晰”。
- 相机：首次同意须知后可正常显示模拟器无相机提示；已有同意状态、重启后首次点击则连续两次出现空白黑屏。
- 独立原生回归脚本 `scripts/verify-all-day-camera-entry.py` 在旧代码失败：`Missing visible recorder control: 相机不可用`。
- 定向日志：`begin target=Optional(...040220) consent=true`，随后 `cover target=nil`。故障发生于 SwiftUI 弹窗内容读取旧状态，尚未进入录制器。初始化卡住/关闭旧页面清目标两个备选假设未得到支持。

## 实现与测试 seam

- `AllDayExerciseLabel` 固定 VStack，整段摘要在动作名下；删去已不使用的 reps/load 分拆显示分支。原有 RIR/RPE 不拆词、长摘要换行规则保留。
- 相机使用 `fullScreenCover(item:)` 直接携带非空拍摄目标；未同意时目标暂存在 pending 字段，同意后再打开，取消则丢弃 pending。关闭清除 active item；上传仍捕获原组/日期/slot。
- Swift 编译器对超长 modifier 链报推断超时，因此相机内容提取为返回具体 CameraRecorderView 的方法，未引入 AnyView。
- 视觉 seam 为实际原生 AllDayExerciseBlock/训练页；不加只断言 VStack 的伪回归。已有转换重量 ViewInspector 测试改为查完整 `1×1  150` 文本并确认不带百分比，去掉内部父视图层级断言。
- 相机 seam 为原生 UI 入口，脚本覆盖已同意、冷启动第一拍、关闭返回、重复三次；不把无摄像头状态当作真实取景通过。

## 验证进度

- 修改后原生相机脚本 3/3 PASS；临时诊断日志已移除。
- iOS 构建通过。StudentKit 首轮 1267 测试仅旧的分拆文本断言失败，已定向适配，待最终复跑。
- 正在准备纯演示数据展示全部 spec 缩略写法、长名、实际值、展开/编辑、主题/字号/单位；临时 Demo fixture 不交付、不入发布包。
- 最终截图、测试、两轴审查及 David 收货状态追加于下方。

## 最终自测与等待收货

- 最终生产源（临时 seed 与 App 注入均已恢复）构建成功；StudentKit 1267 tests / 89 suites 全通过，SwiftLint / diff check 通过。
- 修复后原生脚本两轮冷启动，各 3/3 PASS；新增须知取消→返回→再打开→同意路径正常，无空白页面。
- 独立 Standards=CLEAN、Spec=CLEAN，审查记录 `/Users/david/CodexConfig/reviews/2026-11-11-107-ios-readability-camera.md`。
- 原生截图含六动作、固定/逐组/重复/区间重量、次数区间/AMRAP、RPE/RIR、自重/负重/自选、未换算百分比/顶组、空值、实际修改/未做满、同动作续行、额外组、自加未记录、展开编辑、空日/下一周/已完成日、XXXL 深色与 English/lb。
- 截图索引：本会话 `outputs/ios-inspection/验收索引.html`。百分比已换算的数值显示由现有单元测试覆盖；模拟器没有后置相机，真机取景和录制仍未验证。
- 为 David 查看保留的 gallery App 只在本会话 `work/ios-inspection/gallery-MeetPR.app`，临时 seed/App 源副本在同一 work 目录；均未入仓。恢复展示用 `--qa-gallery -meetpr.appearance light`。QA 学员与原 Demo 学员隔离，无真实数据清理。
- 发布状态：等待 David 模拟器收货。两端均不打新发布 tag、不签发/上传新包；iOS 仍为已上传 37，Android 线上仍为 CN 11。
