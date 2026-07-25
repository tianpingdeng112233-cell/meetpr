/** 组次记录表：# / 重量 / 次数 / RPE / 状态。✓绿=完成 ✗红=失败 空圈=未记录；摄像机只表示视频上传（绿/灰），与成败无关。 */
export interface SetTableProps {
  rows: Array<{ w: number | string; r: number | string; rpe: number | string; done?: boolean; failed?: boolean; video?: boolean }>;
  theme?: 'dark' | 'light';
}
