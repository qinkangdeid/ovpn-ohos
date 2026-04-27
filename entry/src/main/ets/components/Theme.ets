// 视觉系统 token：颜色 / 圆角 / 阴影 / 动画曲线
// 改一处全局生效，避免散落 magic number。命名靠拢 HarmonyOS 设计语言。

import { curves } from '@kit.ArkUI'

// ===== 颜色 =====
// Material Design 官方色阶:Blue (主) + Green (成功) + Grey (中性)。
// 尽量贴合 Material 3 tonal token 的语义:primary / primaryContainer (=primarySoft)。
export class Palette {
  // 中性色 (Material Grey 系)
  static readonly bgTop: string = '#FAFAFA'        // Grey 50
  static readonly bgBottom: string = '#ECEFF1'     // Blue Grey 50
  static readonly surface: string = '#FFFFFF'
  static readonly surfaceMuted: string = '#F5F5F5' // Grey 100
  static readonly border: string = '#E0E0E0'       // Grey 300
  static readonly divider: string = '#EEEEEE'      // Grey 200

  // 文字 (Material 推荐的中性灰阶)
  static readonly textPrimary: string = '#212121'   // Grey 900
  static readonly textSecondary: string = '#424242' // Grey 800
  static readonly textMuted: string = '#757575'     // Grey 600
  static readonly textHint: string = '#BDBDBD'      // Grey 400

  // 主色 — Material Blue
  static readonly primary: string = '#1976D2'      // Blue 700
  static readonly primaryDeep: string = '#0D47A1'  // Blue 900
  static readonly primarySoft: string = '#BBDEFB'  // Blue 100 (≈ M3 primaryContainer)
  static readonly primaryGlow: string = '#401976D2'

  // 成功 — Material Green
  static readonly success: string = '#2E7D32'      // Green 800
  static readonly successBright: string = '#43A047' // Green 600
  static readonly successSoft: string = '#C8E6C9'  // Green 100
  static readonly successTint: string = '#E8F5E9'  // Green 50
  static readonly successGlow: string = '#4043A047'

  // 警告 / 危险 — Material Orange / Red
  static readonly warn: string = '#F57C00'         // Orange 700
  static readonly danger: string = '#D32F2F'       // Red 700
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
// Material elevation:用纯黑低 alpha,而不是带色光晕。
// 大致对应 M3 elevation level 1 / level 3 / level 4。
export const ShadowSoft: ShadowOptions = {
  radius: 8,
  color: '#1F000000', // ~12% black, elevation 1
  offsetY: 2
}

export const ShadowLifted: ShadowOptions = {
  radius: 16,
  color: '#29000000', // ~16% black, elevation 3
  offsetY: 6
}

// 状态高亮的"光晕":带主色 tint + 中等 alpha,营造 Material FAB 的层次
export const ShadowGlowSuccess: ShadowOptions = {
  radius: 24,
  color: '#5C2E7D32', // Green 800 @ 36%
  offsetY: 8
}

export const ShadowGlowPrimary: ShadowOptions = {
  radius: 24,
  color: '#5C1976D2', // Blue 700 @ 36%
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
