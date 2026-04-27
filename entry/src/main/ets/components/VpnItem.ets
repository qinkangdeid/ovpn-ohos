import hilog from '@ohos.hilog';
import { BUNDLE_NAME } from 'BuildProfile';
import { vpnExtension as vpnExt } from '@kit.NetworkKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { preferences } from '@kit.ArkData';
import { showToast } from '../components/Common';
import {
  Palette,
  Radius,
  ShadowSoft,
  SpringResponsive,
  SpringSnappy,
  Dur
} from './Theme';

const TAG: string = '[ItemVpn]'
const bundleName = BUNDLE_NAME
const abilityName = 'OvpnExtAbility'
const CREDS_PREF = 'vpn_creds'

// 用户名密码持久化（plaintext 存 Preferences；不在系统 Keystore 里，权限隔离靠 App 沙箱）。
// 后续可改 HUKS 加密存储，目前先满足"重启不丢"的最低需求。
async function getCredsStore(ctx: Context): Promise<preferences.Preferences> {
  return await preferences.getPreferences(ctx, { name: CREDS_PREF })
}

@Component
export struct VpnItem {
  @Prop name: string = ''
  @Prop cfg: string = ''
  @Prop fullPath: string = ''
  @State display: boolean = false
  @State username: string = ''
  @State password: string = ''
  @State pressed: boolean = false
  @State pulseScale: number = 1
  @StorageLink('vpn.activeName') activeName: string = ''
  @StorageLink('vpn.busyName') busyName: string = ''

  aboutToAppear() {
    this.loadCreds()
    // 启动状态点 pulse（在 .animation 上配 iterations -1 + Alternate）
    this.pulseScale = 1.6
  }

  needsAuth(): boolean {
    return /^auth-user-pass[ \t\r]*(?:[#;].*)?$/m.test(this.cfg)
  }

  isOn(): boolean {
    return this.name === this.activeName || this.name === this.busyName
  }

  someoneBusy(): boolean { return this.busyName !== '' }
  selfBusy(): boolean { return this.name === this.busyName }
  isConnected(): boolean { return this.name === this.activeName && !this.selfBusy() }
  isBlocked(): boolean { return this.activeName !== '' && this.activeName !== this.name && !this.someoneBusy() }

  statusLabel(): string {
    if (this.selfBusy()) {
      return this.name === this.activeName ? '正在断开…' : '正在连接…'
    }
    if (this.isConnected()) return '已连接'
    if (this.needsAuth() && (!this.username || !this.password)) return '需要登录凭据'
    return '空闲'
  }

  statusColor(): string {
    if (this.selfBusy()) return Palette.primary
    if (this.isConnected()) return Palette.success
    if (this.needsAuth() && (!this.username || !this.password)) return Palette.warn
    return Palette.textMuted
  }

  statusDotColor(): string {
    if (this.selfBusy()) return Palette.primary
    if (this.isConnected()) return Palette.successBright
    if (this.needsAuth() && (!this.username || !this.password)) return Palette.warn
    return Palette.textMuted
  }

  cardShadow(): ShadowOptions {
    if (this.isConnected()) {
      return { radius: 24, color: '#4014B8A6', offsetY: 8 }
    }
    return ShadowSoft
  }

  async loadCreds() {
    if (!this.needsAuth()) return
    try {
      const ctx = this.getUIContext().getHostContext()
      if (!ctx) return
      const store = await getCredsStore(ctx)
      const u = await store.get(`${this.name}.user`, '') as string
      const p = await store.get(`${this.name}.pass`, '') as string
      if (u) this.username = u
      if (p) this.password = p
    } catch (e) {
      hilog.error(0x0000, TAG, 'loadCreds err: %{public}s', JSON.stringify(e) ?? '')
    }
  }

  async saveCreds() {
    try {
      const ctx = this.getUIContext().getHostContext()
      if (!ctx) return
      const store = await getCredsStore(ctx)
      await store.put(`${this.name}.user`, this.username)
      await store.put(`${this.name}.pass`, this.password)
      await store.flush()
    } catch (e) {
      hilog.error(0x0000, TAG, 'saveCreds err: %{public}s', JSON.stringify(e) ?? '')
    }
  }

  build() {
    Column() {
      // 顶部行：状态点 + 标题/状态文字 + Toggle + chevron
      Row() {
        // === 状态点（带 pulse 光环） ===
        Stack() {
          // 外层 pulse 光环：仅连接态可见
          if (this.isConnected() || this.selfBusy()) {
            Column()
              .width(20)
              .height(20)
              .borderRadius(10)
              .backgroundColor(this.statusDotColor())
              .opacity(0.25)
              .scale({ x: this.pulseScale, y: this.pulseScale })
              .animation({
                duration: 1400,
                iterations: -1,
                curve: Curve.EaseInOut,
                playMode: PlayMode.Alternate
              })
          }
          Column()
            .width(10)
            .height(10)
            .borderRadius(5)
            .backgroundColor(this.statusDotColor())
        }
        .width(20)
        .height(20)
        .margin({ right: 14 })

        // === 标题 + 状态 ===
        Column() {
          Text(this.name)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(Palette.textPrimary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.statusLabel())
            .fontSize(11)
            .fontColor(this.statusColor())
            .margin({ top: 3 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .onClick(() => { this.display = !this.display })

        // === Toggle + 守卫遮罩 ===
        Stack() {
          Toggle({ type: ToggleType.Switch, isOn: this.isOn() })
            .width(50)
            .height(28)
            .selectedColor(Palette.successBright)
            .switchPointColor(Color.White)
            .enabled(!this.someoneBusy())
            .onChange(async (isOn) => {
              if (isOn === this.isOn()) return
              if (isOn) {
                if (this.needsAuth() && (!this.username || !this.password)) {
                  this.display = true
                  showToast(this.getUIContext(), '请先填写用户名 / 密码', 2200)
                  return
                }
                AppStorage.setOrCreate('vpn.busyName', this.name)
                AppStorage.setOrCreate('vpn.lastUsedName', this.name)
                try {
                  await vpnExt.startVpnExtensionAbility({
                    bundleName,
                    abilityName,
                    parameters: {
                      cfg: this.cfg,
                      username: this.username,
                      password: this.password
                    }
                  })
                  showToast(this.getUIContext(), 'VPN 已启动', 1200);
                  hilog.info(0x0000, TAG, '%{public}s', 'start vpnExt Success');
                } catch (err) {
                  AppStorage.setOrCreate('vpn.busyName', '')
                  showToast(this.getUIContext(), '启动失败: ' + JSON.stringify(err), 2400);
                  hilog.error(0x0000, TAG, 'start vpnExt Fail %{public}s', JSON.stringify(err) ?? '');
                }
              } else {
                AppStorage.setOrCreate('vpn.busyName', this.name)
                try {
                  await vpnExt.stopVpnExtensionAbility({ bundleName, abilityName })
                  showToast(this.getUIContext(), 'VPN 已停止', 1200);
                  hilog.info(0x0000, TAG, '%{public}s', 'stop vpnExt Success');
                  AppStorage.setOrCreate('vpn.activeName', '')
                  AppStorage.setOrCreate('vpn.connectedAt', 0)
                  AppStorage.setOrCreate('vpn.busyName', '')
                } catch (err) {
                  AppStorage.setOrCreate('vpn.busyName', '')
                  showToast(this.getUIContext(), '停止失败: ' + JSON.stringify(err), 2400);
                  hilog.error(0x0000, TAG, 'stop vpnExt Fail %{public}s', JSON.stringify(err) ?? '');
                }
              }
            })

          // 单选守卫：已有别的配置选中（非 busy 中）时盖一层透明拦截层
          if (this.isBlocked()) {
            Column()
              .width(50)
              .height(28)
              .onClick(() => {
                showToast(this.getUIContext(),
                  `请先关闭已选中的「${this.activeName}」`, 2400)
              })
          }
        }
        .width(50)
        .height(28)

        // chevron
        Text('▾')
          .fontSize(14)
          .fontColor(Palette.textMuted)
          .margin({ left: 14 })
          .rotate({ angle: this.display ? 180 : 0 })
          .animation({ duration: Dur.base, curve: SpringResponsive })
          .onClick(() => { this.display = !this.display })
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 16, bottom: 16 })

      // === 展开区 ===
      if (this.display) {
        Divider()
          .color(Palette.divider)
          .margin({ left: 18, right: 18 })

        if (this.needsAuth()) {
          Column() {
            Text('登录凭据')
              .fontSize(11)
              .fontColor(Palette.textSecondary)
              .fontWeight(FontWeight.Medium)
              .letterSpacing(0.5)
              .margin({ top: 16, bottom: 10 })

            TextInput({ placeholder: '用户名', text: this.username })
              .placeholderColor(Palette.textMuted)
              .fontSize(14)
              .height(44)
              .borderRadius(Radius.sm)
              .backgroundColor(Palette.surfaceMuted)
              .padding({ left: 14, right: 14 })
              .margin({ bottom: 8 })
              .onChange((v) => { this.username = v; this.saveCreds() })

            TextInput({ placeholder: '密码', text: this.password })
              .type(InputType.Password)
              .placeholderColor(Palette.textMuted)
              .fontSize(14)
              .height(44)
              .borderRadius(Radius.sm)
              .backgroundColor(Palette.surfaceMuted)
              .padding({ left: 14, right: 14 })
              .onChange((v) => { this.password = v; this.saveCreds() })
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding({ left: 18, right: 18 })
        }

        Column() {
          Text('OpenVPN 配置')
            .fontSize(11)
            .fontColor(Palette.textSecondary)
            .fontWeight(FontWeight.Medium)
            .letterSpacing(0.5)
            .margin({ top: 16, bottom: 10 })

          TextArea({ text: this.cfg })
            .fontSize(12)
            .fontFamily('monospace')
            .height(200)
            .borderRadius(Radius.sm)
            .backgroundColor('#0F172A')
            .fontColor('#E2E8F0')
            .padding(14)
            .onChange((value) => { this.cfg = value })
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding({ left: 18, right: 18 })

        Row() {
          Button('保存修改')
            .fontSize(14)
            .fontColor(Color.White)
            .backgroundColor(Palette.primary)
            .height(42)
            .borderRadius(Radius.sm)
            .layoutWeight(1)
            .onClick(async () => {
              try {
                const fd = await fs.open(this.fullPath, fs.OpenMode.TRUNC | fs.OpenMode.READ_WRITE)
                await fs.write(fd.fd, this.cfg)
                await fs.close(fd)
                showToast(this.getUIContext(), '配置已保存', 1200);
              } catch (e) {
                showToast(this.getUIContext(), `保存失败: ${JSON.stringify(e)}`, 2400);
                hilog.error(0x0000, TAG, 'SaveBtnErr: %{public}s', JSON.stringify(e));
              }
            })
        }.width('100%').padding({ left: 18, right: 18, top: 14, bottom: 16 })
      }
    }
    .width('92%')
    .margin({ top: 6, bottom: 6 })
    .backgroundColor(this.isConnected() ? Palette.successTint : Palette.surface)
    .borderRadius(Radius.lg)
    .shadow(this.cardShadow())
    .border(this.isConnected()
      ? { width: { left: 4 }, color: { left: Palette.successBright } }
      : { width: 0 })
    .scale({ x: this.pressed ? 0.985 : 1, y: this.pressed ? 0.985 : 1 })
    .animation({ duration: Dur.fast, curve: SpringSnappy })
    .onTouch((e) => {
      if (e.type === TouchType.Down) this.pressed = true
      else if (e.type === TouchType.Up || e.type === TouchType.Cancel) this.pressed = false
    })
  }
}
