# spec 078 — 训练视频角标:回看浮层 + 烧录导出(学员+教练双端)

- **状态**:InReview
- **级别/节奏**:T2(跨 ChatUI/StudentKit/CoachKit + 导出管线);P1,目标 1.0(21) 班车。
- **范围**:纯 iOS,零 backend,零新增网络请求。
- **产品意图**:教练晒学员视频是既有营销习惯;角标卡=信息不是水印(重量×次数×RPE 是
  观众想看的内容),烧录导出让品牌随视频文件出海(微信/抖音/小红书平台无关)。

## 问题(为什么做)

学员录完的训练视频在 app 内回看、教练端查看时,画面里没有任何训练数据与品牌元素;
教练对外展示学员成果只能自己录屏/下载原片,MeetPR 在传播链条里零出场。

## 方案概览

两件事,共用同一套角标卡视觉:

1. **回看浮层**:共享播放器加可选角标卡浮层,展示 动作名/重量×次数/RPE/组号,可点按收起。
2. **烧录导出**:播放器加「导出」入口,把同款角标卡合成进视频文件,存入系统相册,
   用户自行转发(V1 不接任何分享 SDK)。

## 角标卡式样(正典 = David 2026-08-20 mockup,一比一)

深色近黑底、大圆角的悬浮卡片,置于画面下部居中,左右留边:

- **头部行**:左 = 品牌金圆形 logo 小图标 + 「MEETPR」白色字标;右 = 「第 N 组」
  (「第」「组」次要灰,N 白色粗体)。
- **动作名行**:白色粗体(如「传统硬拉」)。
- **数据行**:超大号白色粗体重量数字(如「180」)+ 次要灰小字「kg」+ 「× 4」
  (× 次要灰、次数白粗);行尾右侧 = RPE 胶囊(深底、品牌金描边圆角,「RPE」次要
  灰小字 + 数值品牌金粗体)。
- 配色取 DesignSystem 现有品牌金/文本 token,不硬编码新色值;若确无对应 token,
  按 mockup 观感取色并集中定义在角标组件内。
- logo 图标资产:优先复用 asset catalog 现有品牌资产;没有则从 `docs/brand/` 真源出一份
  小尺寸 PNG 加入 asset catalog;仍不可行则纯文字字标兜底,不阻塞主线。

**烧录版比浮层版多一行**:卡片底部小字署名「教练:<名>」——教练端导出取教练自己
displayName;学员端导出取绑定教练名;无教练则整行隐藏。浮层版(app 内)不带署名行。

## A. 回看浮层

- `ChatUI.FeedbackVideoPlayerView` 新增可选参数,模式对齐现有 `markers: [VideoMarker]? = nil`
  先例(⚠️ 仓 gotcha:公开 init 跨模块默认参数是链接地雷,加参方式照 markers 当时的处理,
  确保既有调用点编译链接无恙):

  ```swift
  public struct VideoBadgeInfo: Equatable, Sendable {
    public let exerciseName: String?
    public let weightKg: Double?
    public let reps: Int?
    public let rpe: Double?      // 0.5 步进,显示格式照 app 现有 RPE 口径
    public let setOrdinal: Int?  // 显示用 1-based,由调用点按现有显示口径给,组件内绝不 +1
    public let coachName: String?
  }
  ```

  `badge: VideoBadgeInfo? = nil`;nil = 现行为完全不变。字段全可选,缺哪个隐藏哪块
  (如无 RPE 则无胶囊;无组号则头部行右侧空)。
- **全屏播放**:浮层默认展开;单击卡片收起为小态(仅 logo 圆标),再点展开;收起状态
  不持久化。**嵌入式反馈工作台(270pt 播放窗)**:恒为收起 logo 圆标、不可展开——展开卡
  (~110-130pt)在 270pt 窗内物理上必与中央播放按钮相交抢点击,而组数据(动作/重量×次数/
  RPE/组号)在工作台旁侧信息卡常显,浮层在此只承担品牌露出;完整角标体验走全屏。
  (2026-08-21 review-loop 轮 1 遮挡 BLOCKER 的收敛口径。)
  浮层不得遮挡 markers 打点条与播放控制的可点区(硬约束,与默认展开冲突时以此为准)。
- **调用点接线**(数据只从调用点现有上下文解析,拿不到的字段传 nil,不新发请求):
  1. 学员组内回看:`VideoAttachmentSection` → `SetVideoPlaybackView`(set 行上下文最全,必接);
  2. 教练端:`StudentDetail/Videos` 网格 → `CoachVideoPlayerView` 与反馈工作台
     `VideoFeedbackDetailView`(现有上下文能解析多少传多少,必接);
  3. 聊天 set 卡片 / 学员反馈收件箱:现有上下文够就接,不够传 nil,不为此改数据层。

## B. 烧录导出

- 入口:播放器 chrome 加「导出」按钮(与 markers 控件同层级),仅 `badge != nil` 时显示。
- 合成:`AVMutableVideoComposition` + Core Animation layer 把角标卡(含署名行)烧进画面,
  位置与浮层观感一致(下部居中);badge 尺寸按视频 renderSize 宽度比例映射,保证
  竖屏/横屏视频观感一致。⚠️ 必须正确处理 `preferredTransform`(手机竖拍带旋转元数据),
  renderSize 用变换后的自然尺寸,不得出现烧完画面横倒。
- 导出质量:高质量 preset 重编码,时长/帧率与原片一致;烧录卡在整段时长内常显。
- 产物存系统相册:`PHPhotoLibrary` add-only 权限,`Info.plist` 增
  `NSPhotoLibraryAddUsageDescription`(本地化照仓内 Info.plist 现行方式,中英双语)。
- 导出中显示进度/忙碌指示,完成 toast「已存入相册」,失败给可读错误。
- **教练端首次导出**弹一次确认框:「对外发布前请确认已获学员同意」(确认后
  UserDefaults 记住不再弹);学员端导出不弹。
- 导出在主 app 进程内做即可,V1 不做后台导出/队列。

## 架构约束(硬)

1. 角标卡组件放 ChatUI(或 DesignSystem,按仓内组件归属惯例),浮层与烧录共用同一套
   布局常量/绘制,不得两处各画一份。
2. 烧录渲染不依赖 UIKit 截屏 hack;用 ImageRenderer 或 Core Animation 直画,macOS 编译
   面注意 `#if canImport(UIKit)` 隔离(SPM 单测跑 macOS host,⚠️ `#if os(iOS)` 包住的测试
   会静默不执行——测试写法照仓内现行模式,保证真的在跑)。
3. i18n:所有新字符串进对应 strings enum(StudentStrings/CoachKit 现行机制),中英双语。
4. 组号/RPE 显示口径与 app 内现有显示完全一致(⚠️ set_index 0/1-based 历史混乱,
   组件只收 display-ready 值)。

## 不做(防蔓延)

- 不接微信/抖音分享 SDK;不做二维码(抖音对二维码水印限流);不做前后对比合成、
  e1RM 曲线海报(V2/V3 另拍);不做学员强制审批流;不改任何后端接口。

## 验收标准

1. 学员组内回看:角标卡展示动作名/重量×次数/RPE/组号,与该组记录一致;点击可收起/展开。
2. 教练端查看学员视频:同上;两端 badge 数据缺失时对应块隐藏、无占位残影。
3. 导出:竖拍视频导出后相册成片方向正确、画质无明显劣化、角标卡常显且含署名行
   (教练端=教练名);教练端首次导出弹同意确认、二次不弹。
4. `badge: nil` 路径:聊天/收件箱等未接线调用点行为与现版完全一致。
5. build + 全量 `test_sim` 绿;新增排版/合成逻辑有单测(角标字段隐藏规则、导出后
   时长与轨道断言)。
6. 模拟器截图取证:学员回看浮层、教练端浮层、导出成片(相册内播放截图)。
