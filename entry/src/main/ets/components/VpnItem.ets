import hilog from '@ohos.hilog';
import { BUNDLE_NAME } from 'BuildProfile';
import { vpnExtension as vpnExt } from '@kit.NetworkKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { preferences } from '@kit.ArkData';
import { showToast } from '../components/Common';

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
  @StorageLink('vpn.activeName') activeName: string = ''
  @StorageLink('vpn.busyName') busyName: string = ''

  // 检测配置是否要求账号密码登录
  needsAuth(): boolean {
    return /^auth-user-pass[ \t\r]*(?:[#;].*)?$/m.test(this.cfg)
  }

  // 推导：当前条目处于"已连接"或"正在连接/断开"状态
  isOn(): boolean {
    return this.name === this.activeName || this.name === this.busyName
  }

  // 整个 App 是否处于忙碌（其他卡片要禁用）
  someoneBusy(): boolean {
    return this.busyName !== ''
  }

  selfBusy(): boolean {
    return this.name === this.busyName
  }

  isConnected(): boolean {
    return this.name === this.activeName && !this.selfBusy()
  }

  statusLabel(): string {
    if (this.selfBusy()) {
      return this.name === this.activeName ? '正在断开…' : '正在连接…'
    }
    if (this.isConnected()) return '已连接'
    if (this.needsAuth() && (!this.username || !this.password)) return '需要登录凭据'
    return '空闲'
  }

  statusColor(): string {
    if (this.selfBusy()) return '#3B82F6'
    if (this.isConnected()) return '#16A34A'
    return '#9CA3AF'
  }

  aboutToAppear() {
    this.loadCreds()
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
        // 状态点（已连接时带光晕环）
        Stack() {
          if (this.isConnected()) {
            Circle({ width: 18, height: 18 })
              .fill('#22C55E')
              .opacity(0.18)
          }
          Circle({ width: 10, height: 10 })
            .fill(this.statusColor())
        }
        .width(18)
        .height(18)
        .margin({ right: 12 })

        Column() {
          Text(this.name)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#1F2937')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.statusLabel())
            .fontSize(11)
            .fontColor(this.statusColor())
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .onClick(() => { this.display = !this.display })

        Toggle({ type: ToggleType.Switch, isOn: this.isOn() })
          .selectedColor('#22C55E')
          .switchPointColor(Color.White)
          .enabled(!this.someoneBusy())
          .onChange(async (isOn) => {
            // 防抖：状态已经一致就跳过
            if (isOn === this.isOn()) return
            if (isOn) {
              if (this.needsAuth() && (!this.username || !this.password)) {
                this.display = true
                showToast(this.getUIContext(), '请先填写用户名 / 密码', 2200)
                return
              }
              AppStorage.setOrCreate('vpn.busyName', this.name)
              // 记下"上次使用"，供 HomeTab 大圆按钮直接 toggle
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
                // stop 调用本身不一定有 DESTROY 事件回来，主动清状态作为兜底
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

        // chevron 替代旧"展开/收起"文字按钮
        Text('▾')
          .fontSize(16)
          .fontColor('#9CA3AF')
          .margin({ left: 12 })
          .rotate({ angle: this.display ? 180 : 0 })
          .animation({ duration: 180, curve: Curve.EaseInOut })
          .onClick(() => { this.display = !this.display })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 14, bottom: 14 })

      // 展开区
      if (this.display) {
        Divider().color('#E5E7EB').margin({ left: 16, right: 16 })

        if (this.needsAuth()) {
          Column() {
            Text('登录凭据')
              .fontSize(12)
              .fontColor('#6B7280')
              .fontWeight(FontWeight.Medium)
              .margin({ top: 14, bottom: 8 })

            TextInput({ placeholder: '用户名', text: this.username })
              .placeholderColor('#9CA3AF')
              .fontSize(15)
              .height(44)
              .borderRadius(10)
              .backgroundColor('#F8FAFC')
              .padding({ left: 12, right: 12 })
              .margin({ bottom: 8 })
              .onChange((v) => { this.username = v; this.saveCreds() })

            TextInput({ placeholder: '密码', text: this.password })
              .type(InputType.Password)
              .placeholderColor('#9CA3AF')
              .fontSize(15)
              .height(44)
              .borderRadius(10)
              .backgroundColor('#F8FAFC')
              .padding({ left: 12, right: 12 })
              .onChange((v) => { this.password = v; this.saveCreds() })
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding({ left: 16, right: 16 })
        }

        Column() {
          Text('OpenVPN 配置')
            .fontSize(12)
            .fontColor('#6B7280')
            .fontWeight(FontWeight.Medium)
            .margin({ top: 14, bottom: 8 })

          TextArea({ text: this.cfg })
            .fontSize(12)
            .fontFamily('monospace')
            .height(180)
            .borderRadius(10)
            .backgroundColor('#0F172A')
            .fontColor('#E2E8F0')
            .padding(12)
            .onChange((value) => { this.cfg = value })
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding({ left: 16, right: 16 })

        Row() {
          Button('保存修改')
            .fontSize(14)
            .fontColor(Color.White)
            .backgroundColor('#3B82F6')
            .height(40)
            .borderRadius(10)
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
        }.width('100%').padding({ left: 16, right: 16, top: 12, bottom: 14 })
      }
    }
    .width('92%')
    .margin({ top: 5, bottom: 5 })
    .backgroundColor(this.isConnected() ? '#F0FDF4' : Color.White)
    .borderRadius(16)
    .shadow({
      radius: this.isConnected() ? 16 : 8,
      color: this.isConnected() ? '#22C55E33' : '#0A000000',
      offsetY: this.isConnected() ? 4 : 2
    })
    .border(this.isConnected() ? { width: { left: 4 }, color: { left: '#22C55E' } } : { width: 0 })
  }
}
