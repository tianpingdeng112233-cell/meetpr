# 动作留言卡片等宽（P1）

David 在截图反馈后确认，学员发出的动作留言靠右，教练收到靠左，同侧卡片等宽。原卡片标签跟随文字宽度，学员时间线默认居中。iPhone 17e 上三条长中短合成留言分别宽 332、318、219.67 pt。

卡片标签在背景内占满父级分配的宽度，学员时间线在对侧留 32 pt。教练时间线沿用既有收发方向。卡片高度随正文换行。

共享卡片渲染测试的长短两例修前都未占满 280 pt，修后通过。StudentKit 串行全量 1300 项、ChatUI 96 项通过，改动 Swift 文件严格 lint 通过。Standards、Spec 独立审查均无未决项。Android 同批修复见 [meetpr-rn#198](https://github.com/tianpingdeng112233-cell/meetpr-rn/pull/198)。
