// 视觉系统 token：颜色 / 圆角 / 阴影 / 动画曲线
// 改一处全局生效，避免散落 magic number。命名靠拢 HarmonyOS 设计语言。

import { curves } from '@kit.ArkUI'

// ===== 颜色 =====
// 整体偏"素雅":去饱和后的尘雾蓝 + 茶绿(sage),不再用电子蓝/翠绿。
export class Palette {
  // 中性色
  static readonly bgTop: string = '#F7F8FA'
  static readonly bgBottom: string = '#EEF1F4'
  static readonly surface: string = '#FFFFFF'
  static readonly surfaceMuted: string = '#F2F4F7'
  static readonly border: string = '#E4E7EC'
  static readonly divider: string = '#EEF0F3'

  // 文字
  static readonly textPrimary: string = '#1F2937'
  static readonly textSecondary: string = '#52606D'
  static readonly textMuted: string = '#9AA5B1'
  static readonly textHint: string = '#CBD2D9'

  // 主色(尘雾蓝)
  static readonly primary: string = '#5B7CB7'
  static readonly primaryDeep: string = '#3F5A8A'
  static readonly primarySoft: string = '#E4EAF3'
  static readonly primaryGlow: string = '#3D5B7CB7'

  // 成功(已连接)— 茶绿/sage,饱和度比 teal 低一档,显克制
  static readonly success: string = '#6B8E7C'
  static readonly successBright: string = '#84A797'
  static readonly successSoft: string = '#E1EBE4'
  static readonly successTint: string = '#F2F6F2'
  static readonly successGlow: string = '#3D84A797'

  // 警告 / 危险 — 调色,不再是高饱和橙红
  static readonly warn: string = '#D4A55B'
  static readonly danger: string = '#C77B72'
}

// ===== 圆角 =====
export class Radius {
  static readonly xs: number = 8
  static readonly sm: number = 12
  static readonly md: number = 16
  static readonly lg: number = 20
  static readonly xl: number = 24
  static readonly pill: number = 999
}

// ===== 阴影（双层柔和） =====
// 注意:鸿蒙 8 位 hex 是 ARGB 顺序(alpha 在前),不是 web 的 RGBA。
export const ShadowSoft: ShadowOptions = {
  radius: 14,
  color: '#0E1F2937',
  offsetY: 4
}

export const ShadowLifted: ShadowOptions = {
  radius: 28,
  color: '#161F2937',
  offsetY: 12
}

export const ShadowGlowSuccess: ShadowOptions = {
  radius: 32,
  color: '#3D84A797',
  offsetY: 8
}

export const ShadowGlowPrimary: ShadowOptions = {
  radius: 32,
  color: '#3D5B7CB7',
  offsetY: 8
}

// ===== 动画曲线（HM 风格弹簧） =====
// 卡片/列表入场、Toggle 切换：响应式弹簧
export const SpringResponsive: ICurve = curves.springMotion(0.35, 0.85)
// 状态强反馈（按钮回弹）
export const SpringSnappy: ICurve = curves.springMotion(0.28, 0.7)

// ===== 动画时长 =====
export class Dur {
  static readonly fast: number = 160
  static readonly base: number = 240
  static readonly slow: number = 420
  static readonly breathe: number = 1800
}
