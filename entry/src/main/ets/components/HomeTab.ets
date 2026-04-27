// 首页 Tab：超大圆形按钮（呼吸光晕 + 流动渐变环 + ON/OFF 平滑过渡）+ 状态信息
// 点击大圆切换"上次使用过的配置"的连接状态。lastUsed 来自 ConfigsTab 启动 VPN 时写入。

import hilog from '@ohos.hilog';
import { BUNDLE_NAME } from 'BuildProfile';
import { vpnExtension as vpnExt } from '@kit.NetworkKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { preferences } from '@kit.ArkData';
import { showToast } from './Common';
import {
  Palette,
  Radius,
  SpringResponsive,
  SpringSnappy,
  Dur
} from './Theme';

const TAG: string = '[HomeTab]'
const bundleName = BUNDLE_NAME
const abilityName = 'OvpnExtAbility'
const CREDS_PREF = 'vpn_creds'

async function getCredsStore(ctx: Context): Promise<preferences.Preferences> {
  return await preferences.getPreferences(ctx, { name: CREDS_PREF })
}

@Component
export struct HomeTab {
  @StorageLink('vpn.activeName') activeName: string = ''
  @StorageLink('vpn.connectedAt') connectedAt: number = 0
  @StorageLink('vpn.busyName') busyName: string = ''
  @StorageLink('vpn.lastUsedName') lastUsedName: string = ''
  @State now: number = Date.now()
  @State pressed: boolean = false
  @State haloScale: number = 1
  @State spin: number = 0
  private timer: number = -1

  aboutToAppear() {
    this.timer = setInterval(() => { this.now = Date.now() }, 1000) as number
    this.haloScale = 1.06
    this.spin = 360
  }

  aboutToDisappear() {
    if (this.timer !== -1) {
      clearInterval(this.timer)
      this.timer = -1
    }
  }

  isConnected(): boolean { return !!this.activeName && !this.busyName }
  isConnecting(): boolean { return !!this.busyName && !this.activeName }
  isDisconnecting(): boolean { return !!this.busyName && !!this.activeName }
  isBusy(): boolean { return this.isConnecting() || this.isDisconnecting() }
  hasSelection(): boolean { return !!this.lastUsedName }

  formatDuration(ms: number): string {
    if (ms <= 0) return '00:00'
    const s = Math.floor(ms / 1000)
    const h = Math.floor(s / 3600)
    const m = Math.floor((s % 3600) / 60)
    const sec = s % 60
    const pad: (n: number) => string = (n) => n.toString().padStart(2, '0')
    return h > 0 ? `${pad(h)}:${pad(m)}:${pad(sec)}` : `${pad(m)}:${pad(sec)}`
  }

  statusTitle(): string {
    if (this.isConnecting()) return '正在连接'
    if (this.isDisconnecting()) return '正在断开'
    if (this.isConnected()) return '已连接'
    return '未连接'
  }

  centerLabel(): string {
    if (this.isBusy()) return '···'
    return this.isConnected() ? 'ON' : 'OFF'
  }

  haloColor(): string {
    if (this.isBusy()) return '#BBDEFB'  // Blue 100
    return this.isConnected() ? '#A5D6A7' : '#CFD8DC'  // Green 200 / Blue Grey 100
  }

  haloOpacity(): number {
    if (this.isBusy()) return 0.5
    return this.isConnected() ? 0.6 : 0.3
  }

  titleColor(): string {
    if (this.isBusy()) return Palette.primaryDeep
    // Material Green 900 for the strongest "ON" emphasis
    return this.isConnected() ? '#1B5E20' : Palette.textPrimary
  }

  async toggle() {
    if (this.busyName) return
    const ctx = this.getUIContext().getHostContext()
    if (!ctx) return

    if (this.activeName) {
      AppStorage.setOrCreate('vpn.busyName', this.activeName)
      try {
        await vpnExt.stopVpnExtensionAbility({ bundleName, abilityName })
        showToast(this.getUIContext(), 'VPN 已停止', 1200)
        AppStorage.setOrCreate('vpn.activeName', '')
        AppStorage.setOrCreate('vpn.connectedAt', 0)
        AppStorage.setOrCreate('vpn.busyName', '')
      } catch (err) {
        AppStorage.setOrCreate('vpn.busyName', '')
        showToast(this.getUIContext(), '停止失败: ' + JSON.stringify(err), 2400)
        hilog.error(0x0000, TAG, 'stop fail %{public}s', JSON.stringify(err) ?? '')
      }
      return
    }

    if (!this.lastUsedName) {
      showToast(this.getUIContext(), '请先去 配置 tab 选一个 VPN 启用', 2400)
      return
    }

    try {
      const fullPath = ctx.filesDir + '/ovpn/' + this.lastUsedName
      const cfg = await fs.readText(fullPath)
      let username = ''
      let password = ''
      try {
        const store = await getCredsStore(ctx)
        username = await store.get(`${this.lastUsedName}.user`, '') as string
        password = await store.get(`${this.lastUsedName}.pass`, '') as string
      } catch (e) { }

      const needsAuth = /^auth-user-pass[ \t\r]*(?:[#;].*)?$/m.test(cfg)
      if (needsAuth && (!username || !password)) {
        showToast(this.getUIContext(), '该配置需要登录凭据，请去 配置 tab 填写', 2800)
        return
      }

      AppStorage.setOrCreate('vpn.busyName', this.lastUsedName)
      try {
        await vpnExt.startVpnExtensionAbility({
          bundleName,
          abilityName,
          parameters: {
            cfg: cfg,
            username: username,
            password: password
          }
        })
        showToast(this.getUIContext(), 'VPN 已启动', 1200)
      } catch (err) {
        AppStorage.setOrCreate('vpn.busyName', '')
        showToast(this.getUIContext(), '启动失败: ' + JSON.stringify(err), 2400)
        hilog.error(0x0000, TAG, 'start fail %{public}s', JSON.stringify(err) ?? '')
      }
    } catch (e) {
      showToast(this.getUIContext(), `读取配置失败: ${JSON.stringify(e)}`, 2400)
      hilog.error(0x0000, TAG, 'read cfg fail %{public}s', JSON.stringify(e) ?? '')
    }
  }

  // 渐变 inline Builder（直接 inline，避免 typed return 在 ArkTS 下被 fallback 成默认色）
  @Builder
  RingLayer() {
    if (this.isBusy()) {
      // Busy:Material Blue 300 → 700 → 300 流光环
      Column()
        .width(232).height(232).borderRadius(116)
        .linearGradient({
          angle: 45,
          colors: [['#64B5F6', 0.0], ['#1976D2', 0.5], ['#64B5F6', 1.0]]
        })
        .opacity(1.0)
        .rotate({ angle: this.spin })
        .animation({ duration: 1600, iterations: -1, curve: Curve.Linear })
    } else if (this.isConnected()) {
      // Connected:Material Green 300 → 700 → 200,带活力但 Material 色阶
      Column()
        .width(232).height(232).borderRadius(116)
        .linearGradient({
          angle: 45,
          colors: [['#81C784', 0.0], ['#388E3C', 0.5], ['#A5D6A7', 1.0]]
        })
        .opacity(1.0)
        .rotate({ angle: this.spin })
        .animation({ duration: 4500, iterations: -1, curve: Curve.Linear })
    } else {
      // Idle:Material Blue Grey 200/600/200,明显"熄灭"
      Column()
        .width(232).height(232).borderRadius(116)
        .linearGradient({
          angle: 45,
          colors: [['#B0BEC5', 0.0], ['#546E7A', 0.5], ['#B0BEC5', 1.0]]
        })
        .opacity(0.55)
        .rotate({ angle: this.spin })
        .animation({ duration: 6000, iterations: -1, curve: Curve.Linear })
    }
  }

  @Builder
  InnerLayer() {
    if (this.isBusy()) {
      // Material Blue 400 → 800,Material FAB 风格
      Column()
        .width(212).height(212).borderRadius(106)
        .linearGradient({
          angle: 135,
          colors: [['#42A5F5', 0.0], ['#1565C0', 1.0]]
        })
        .shadow({ radius: 28, color: '#5C1976D2', offsetY: 10 })
    } else if (this.isConnected()) {
      // Material Green 400 → 700 → 800,有"在亮"的感觉
      Column()
        .width(212).height(212).borderRadius(106)
        .linearGradient({
          angle: 135,
          colors: [['#66BB6A', 0.0], ['#388E3C', 0.5], ['#2E7D32', 1.0]]
        })
        .shadow({ radius: 32, color: '#702E7D32', offsetY: 10 })
    } else {
      // Material Blue Grey 400 → 800,熄灭对比
      Column()
        .width(212).height(212).borderRadius(106)
        .linearGradient({
          angle: 135,
          colors: [['#90A4AE', 0.0], ['#37474F', 1.0]]
        })
        .shadow({ radius: 14, color: '#3D000000', offsetY: 6 })
    }
  }

  build() {
    Column() {
      Blank()

      // === 巨型按钮（多层堆叠） ===
      Stack() {
        // 1. 远端柔光（呼吸缩放，连接态加亮）
        Column()
          .width(300).height(300).borderRadius(150)
          .backgroundColor(this.haloColor())
          .opacity(this.haloOpacity())
          .scale({ x: this.haloScale, y: this.haloScale })
          .animation({
            duration: Dur.breathe,
            iterations: -1,
            curve: Curve.EaseInOut,
            playMode: PlayMode.Alternate
          })

        // 2. 流动渐变环（旋转）
        this.RingLayer()

        // 3. 内圆（实心 + 主阴影）
        this.InnerLayer()

        // 4. 内圆顶部高光（玻璃质感，固定半透明白渐变）
        Column()
          .width(212).height(212).borderRadius(106)
          .linearGradient({
            angle: 180,
            colors: [['#66FFFFFF', 0.0], ['#00FFFFFF', 0.55]]
          })

        // 5. 中心文字
        Text(this.centerLabel())
          .fontSize(this.isBusy() ? 56 : 60)
          .fontColor(Color.White)
          .fontWeight(FontWeight.Bold)
          .letterSpacing(this.isBusy() ? 0 : 4)
          .animation({ duration: Dur.base, curve: SpringResponsive })
      }
      .width(300)
      .height(300)
      .scale({ x: this.pressed ? 0.95 : 1, y: this.pressed ? 0.95 : 1 })
      .animation({ duration: Dur.fast, curve: SpringSnappy })
      .onTouch((e) => {
        if (e.type === TouchType.Down) this.pressed = true
        else if (e.type === TouchType.Up || e.type === TouchType.Cancel) this.pressed = false
      })
      .onClick(() => this.toggle())

      // === 主标题 ===
      Text(this.statusTitle())
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.titleColor())
        .margin({ top: 32 })
        .animation({ duration: Dur.base, curve: SpringResponsive })

      // === 副信息 ===
      if (this.isConnected()) {
        Row({ space: 6 }) {
          Column().width(6).height(6).borderRadius(3).backgroundColor(Palette.success)
          Text(this.activeName)
            .fontSize(13)
            .fontColor(Palette.success)
            .fontWeight(FontWeight.Medium)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .padding({ left: 12, right: 14, top: 6, bottom: 6 })
        .backgroundColor(Palette.successSoft)
        .borderRadius(Radius.pill)
        .margin({ top: 14 })

        Text(this.formatDuration(this.now - this.connectedAt))
          .fontSize(22)
          .fontFamily('monospace')
          .fontColor(Palette.textSecondary)
          .fontWeight(FontWeight.Medium)
          .letterSpacing(2)
          .margin({ top: 14 })
      } else if (this.isBusy()) {
        Row({ space: 6 }) {
          Column().width(6).height(6).borderRadius(3).backgroundColor(Palette.primary)
          Text(this.busyName)
            .fontSize(13)
            .fontColor(Palette.primaryDeep)
            .fontWeight(FontWeight.Medium)
        }
        .padding({ left: 12, right: 14, top: 6, bottom: 6 })
        .backgroundColor(Palette.primarySoft)
        .borderRadius(Radius.pill)
        .margin({ top: 14 })
      } else if (this.hasSelection()) {
        Text('点击连接')
          .fontSize(13)
          .fontColor(Palette.textMuted)
          .margin({ top: 14 })
        Row({ space: 6 }) {
          Column().width(6).height(6).borderRadius(3).backgroundColor(Palette.textMuted)
          Text(this.lastUsedName)
            .fontSize(13)
            .fontColor(Palette.textSecondary)
            .fontWeight(FontWeight.Medium)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .padding({ left: 12, right: 14, top: 6, bottom: 6 })
        .backgroundColor(Palette.surfaceMuted)
        .borderRadius(Radius.pill)
        .margin({ top: 8 })
      } else {
        Text('请先去 配置 tab 选择 VPN')
          .fontSize(13)
          .fontColor(Palette.textMuted)
          .margin({ top: 14 })
      }

      Blank()
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}
