/** 卡片容器。暗色 #141416 无阴影靠层级；亮色白卡+弥散阴影。accent=左侧 3px 金条（焦点卡）；inset=嵌入式浅层（教练备注）。 */
export interface CardProps {
  theme?: 'dark' | 'light';
  /** 左侧 3px 金色纵条 — 教练反馈/当前动作等焦点卡 */
  accent?: boolean;
  /** 嵌入层（圆角10、更浅底色，用于卡中卡） */
  inset?: boolean;
  style?: React.CSSProperties;
  children?: React.ReactNode;
}
