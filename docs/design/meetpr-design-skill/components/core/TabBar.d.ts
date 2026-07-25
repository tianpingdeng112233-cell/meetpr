/** 底部四标签导航（83px 高）。选中金/琥珀，未选中灰；图标 24px stroke-2。 */
export interface TabBarProps {
  /** 0=今日 1=训练 2=成长 3=我的 */
  active?: number;
  theme?: 'dark' | 'light';
  onChange?: (index: number) => void;
}
