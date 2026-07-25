/** 周历日期块（44px 高）。selected=黑底金描边+橙点；dim=休息日/未来降灰；dot 表示训练状态。 */
export interface DayChipProps {
  /** 星期标签，如「周三」 */
  dow: string;
  /** 日期数字，如 22 */
  day: number | string;
  state?: 'default' | 'selected' | 'dim';
  /** 右上状态点：success=已完成 gold=进行中 danger=未完成；休息日不打点 */
  dot?: 'success' | 'gold' | 'danger' | null;
  theme?: 'dark' | 'light';
}
