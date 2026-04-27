// 视觉系统 token：颜色 / 圆角 / 阴影 / 动画曲线
// 改一处全局生效，避免散落 magic number。命名靠拢 HarmonyOS 设计语言。

import { curves } from '@kit.ArkUI'

// ===== 颜色 =====
export class Palette {
  // 中性色
  static readonly bgTop: string = '#F8FAFC'
  static readonly bgBottom: string = '#EDF1F7'
  static readonly surface: string = '#FFFFFF'
  static readonly surfaceMuted: string = '#F1F5F9'
  static readonly border: string = '#E5E7EB'
  static readonly divider: string = '#EEF1F5'

  // 文字
  static readonly textPrimary: string = '#0F172A'
  static readonly textSecondary: string = '#475569'
  static readonly textMuted: string = '#94A3B8'
  static readonly textHint: string = '#CBD5E1'

  // 主色（蓝）
  static readonly primary: string = '#2563EB'
  static readonly primaryDeep: string = '#1D4ED8'
  static readonly primarySoft: string = '#DBEAFE'
  static readonly primaryGlow: string = '#552563EB'

  // 成功（已连接）— 翠绿/薄荷，比 safety green 更冷更 premium
  static readonly success: string = '#0D9488'
  static readonly successBright: string = '#14B8A6'
  static readonly successSoft: string = '#CCFBF1'
  static readonly successTint: string = '#F0FDFA'
  static readonly successGlow: string = '#5514B8A6'

  // 警告 / 危险
  static readonly warn: string = '#F59E0B'
  static readonly danger: string = '#EF4444'
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
  color: '#140F172A',
  offsetY: 4
}

export const ShadowLifted: ShadowOptions = {
  radius: 28,
  color: '#1F0F172A',
  offsetY: 12
}

export const ShadowGlowSuccess: ShadowOptions = {
  radius: 32,
  color: '#6614B8A6',
  offsetY: 8
}

export const ShadowGlowPrimary: ShadowOptions = {
  radius: 32,
  color: '#552563EB',
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
