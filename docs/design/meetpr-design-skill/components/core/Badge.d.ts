/** 状态胶囊标签：当前 / 已通知教练 / PR 等。mono 11px 700。 */
export interface BadgeProps {
  tone?: 'gold' | 'success' | 'danger' | 'neutral';
  theme?: 'dark' | 'light';
  children?: React.ReactNode;
}
