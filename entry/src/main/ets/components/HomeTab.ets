// 首页 Tab：超大 ON/OFF 圆形按钮 + 状态信息
// 点击大圆切换"上次使用过的配置"的连接状态。lastUsed 来自 ConfigsTab 启动 VPN 时写入。

import hilog from '@ohos.hilog';
import { BUNDLE_NAME } from 'BuildProfile';
import { vpnExtension as vpnExt } from '@kit.NetworkKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { preferences } from '@kit.ArkData';
import { showToast } from './Common';

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
  private timer: number = -1

  aboutToAppear() {
    this.timer = setInterval(() => { this.now = Date.now() }, 1000) as number
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
    if (this.isConnecting() || this.isDisconnecting()) return '···'
    return this.isConnected() ? 'ON' : 'OFF'
  }

  ringColor(): string {
    if (this.isConnecting() || this.isDisconnecting()) return '#3B82F6'
    return this.isConnected() ? '#22C55E' : '#94A3B8'
  }

  haloColor(): string {
    if (this.isConnecting() || this.isDisconnecting()) return '#BFDBFE'
    return this.isConnected() ? '#86EFAC' : '#E2E8F0'
  }

  titleColor(): string {
    if (this.isConnecting() || this.isDisconnecting()) return '#1D4ED8'
    return this.isConnected() ? '#15803D' : '#1F2937'
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
      // 加载凭据（如果有）
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

  build() {
    Column() {
      Blank()

      // 大圆按钮
      Stack() {
        Circle({ width: 260, height: 260 })
          .fill(this.haloColor())
          .opacity(0.35)
        Circle({ width: 200, height: 200 })
          .fill(this.ringColor())
          .shadow({ radius: 32, color: this.ringColor() + '55', offsetY: 10 })
        Text(this.centerLabel())
          .fontSize(this.isConnecting() || this.isDisconnecting() ? 64 : 56)
          .fontColor(Color.White)
          .fontWeight(FontWeight.Bold)
          .letterSpacing(2)
      }
      .width(260)
      .height(260)
      .onClick(() => this.toggle())

      // 主标题
      Text(this.statusTitle())
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.titleColor())
        .margin({ top: 28 })

      // 副信息
      if (this.isConnected()) {
        Row() {
          Text(this.activeName)
            .fontSize(14)
            .fontColor('#16A34A')
            .fontWeight(FontWeight.Medium)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .padding({ left: 14, right: 14, top: 5, bottom: 5 })
        .backgroundColor('#DCFCE7')
        .borderRadius(20)
        .margin({ top: 12 })

        Text(this.formatDuration(this.now - this.connectedAt))
          .fontSize(20)
          .fontFamily('monospace')
          .fontColor('#374151')
          .fontWeight(FontWeight.Medium)
          .margin({ top: 12 })
      } else if (this.isConnecting() || this.isDisconnecting()) {
        Text(this.busyName)
          .fontSize(14)
          .fontColor('#3B82F6')
          .fontWeight(FontWeight.Medium)
          .margin({ top: 10 })
      } else if (this.hasSelection()) {
        Text('点击连接')
          .fontSize(13)
          .fontColor('#9CA3AF')
          .margin({ top: 10 })
        Row() {
          Text(this.lastUsedName)
            .fontSize(13)
            .fontColor('#374151')
            .fontWeight(FontWeight.Medium)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .padding({ left: 12, right: 12, top: 4, bottom: 4 })
        .backgroundColor('#F1F5F9')
        .borderRadius(20)
        .margin({ top: 6 })
      } else {
        Text('请先去 配置 tab 选择 VPN')
          .fontSize(13)
          .fontColor('#9CA3AF')
          .margin({ top: 10 })
      }

      Blank()
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}
