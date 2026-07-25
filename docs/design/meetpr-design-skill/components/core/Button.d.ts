/**
 * 金色主 CTA / 次级卡片按钮 / 文字按钮。暗色 primary = #FFB800 黑字；亮色 primary = #111827 白字。
 * @startingPoint section="Components" subtitle="MeetPR 三级按钮" viewport="700x210"
 */
export interface ButtonProps {
  /** primary=实体CTA secondary=卡片按钮 ghost=文字链 */
  variant?: 'primary' | 'secondary' | 'ghost';
  /** 主题：决定 primary 的填充策略 */
  theme?: 'dark' | 'light';
  /** 是否带 4.5s 光泽扫过（仅暗色 primary，页面最高层级入口专用） */
  shimmer?: boolean;
  /** 前置图标节点（13px SVG） */
  icon?: React.ReactNode;
  /** 副行文字，如「蹲 · 推 · 拉」 */
  sub?: string;
  children?: React.ReactNode;
  style?: React.CSSProperties;
  onClick?: () => void;
}
