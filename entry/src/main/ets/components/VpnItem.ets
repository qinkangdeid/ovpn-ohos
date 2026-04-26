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
  @State isOn: boolean = false
  @State username: string = ''
  @State password: string = ''
  @State busy: boolean = false

  // 检测配置是否要求账号密码登录
  // 匹配裸 `auth-user-pass`（可带行尾 # 或 ; 注释，CRLF 行尾也兼容），排除 `auth-user-pass FILE` 这种从文件读凭据的形式
  needsAuth(): boolean {
    return /^auth-user-pass[ \t\r]*(?:[#;].*)?$/m.test(this.cfg)
  }

  aboutToAppear() {
    this.loadCreds()
  }

  // 从 Preferences 加载之前保存的用户名密码（key 用 ovpn 文件名，避免不同 config 撞车）
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
      // 顶部行: 整行可点击展开/收起；状态点 + 名字 / 状态文 + Toggle + Chevron 箭头
      Row() {
        Circle({ width: 10, height: 10 })
          .fill(this.isOn ? '#22C55E' : '#9CA3AF')
          .margin({ right: 10 })

        Column() {
          Text(this.name)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#1F2937')
          Text(this.isOn ? 'Connected' : (this.needsAuth() && (!this.username || !this.password) ? 'Auth required' : 'Idle'))
            .fontSize(11)
            .fontColor(this.isOn ? '#22C55E' : '#6B7280')
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .onClick(() => { this.display = !this.display })

        Toggle({ type: ToggleType.Switch, isOn: this.isOn })
          .selectedColor('#3B82F6')
          .enabled(!this.busy)
          .onChange(async (isOn) => {
            if (this.busy) return
            this.isOn = isOn
            if (isOn) {
              if (this.needsAuth() && (!this.username || !this.password)) {
                this.display = true
                showToast(this.getUIContext(), '请先填写用户名 / 密码', 2200)
                this.isOn = false
                return
              }
              this.busy = true
              await this.startVpn()
              this.busy = false
            } else {
              this.busy = true
              await this.stopVpn()
              this.busy = false
            }
          })

        Button(this.display ? '收起' : '展开')
          .fontSize(13)
          .fontColor('#3B82F6')
          .backgroundColor(Color.Transparent)
          .height(32)
          .margin({ left: 8 })
          .onClick(() => { this.display = !this.display })
      }
      .width('100%')
      .padding({ left: 14, right: 10, top: 12, bottom: 12 })

      // 展开区域: 账号密码 / 配置内容 / 保存按钮
      if (this.display) {
        Divider().color('#E5E7EB').margin({ left: 14, right: 14 })

        if (this.needsAuth()) {
          Column() {
            Text('登录凭据')
              .fontSize(13)
              .fontColor('#6B7280')
              .fontWeight(FontWeight.Medium)
              .margin({ top: 12, bottom: 8 })

            TextInput({ placeholder: '用户名', text: this.username })
              .placeholderColor('#9CA3AF')
              .fontSize(15)
              .height(42)
              .borderRadius(8)
              .backgroundColor('#F9FAFB')
              .padding({ left: 12, right: 12 })
              .margin({ bottom: 8 })
              .onChange((v) => { this.username = v; this.saveCreds() })

            TextInput({ placeholder: '密码', text: this.password })
              .type(InputType.Password)
              .placeholderColor('#9CA3AF')
              .fontSize(15)
              .height(42)
              .borderRadius(8)
              .backgroundColor('#F9FAFB')
              .padding({ left: 12, right: 12 })
              .onChange((v) => { this.password = v; this.saveCreds() })
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding({ left: 14, right: 14 })
        }

        Column() {
          Text('OpenVPN 配置')
            .fontSize(13)
            .fontColor('#6B7280')
            .fontWeight(FontWeight.Medium)
            .margin({ top: 12, bottom: 8 })

          TextArea({ text: this.cfg })
            .fontSize(12)
            .fontFamily('monospace')
            .height(160)
            .borderRadius(8)
            .backgroundColor('#F9FAFB')
            .padding(10)
            .onChange((value) => { this.cfg = value })
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding({ left: 14, right: 14 })

        Row() {
          Button('保存修改')
            .fontSize(14)
            .fontColor(Color.White)
            .backgroundColor('#3B82F6')
            .height(38)
            .borderRadius(8)
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
        }.width('100%').padding({ left: 14, right: 14, top: 12, bottom: 14 })
      }
    }
    .width('92%')
    .margin({ top: 6, bottom: 6 })
    .backgroundColor(Color.White)
    .borderRadius(14)
    .shadow({ radius: 8, color: '#0A000000', offsetY: 2 })
    .border(this.isOn ? { width: { left: 4 }, color: { left: '#22C55E' } } : { width: 0 })
  }

  async startVpn() {
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
      showToast(this.getUIContext(), 'VPN 已启动', 1500);
      hilog.info(0x0000, TAG, '%{public}s', 'start vpnExt Success');
    } catch (err) {
      showToast(this.getUIContext(), '启动失败: ' + JSON.stringify(err), 2400);
      hilog.error(0x0000, TAG, 'start vpnExt Fail %{public}s', JSON.stringify(err) ?? '');
      this.isOn = false
    }
  }

  async stopVpn() {
    try {
      await vpnExt.stopVpnExtensionAbility({ bundleName, abilityName })
      showToast(this.getUIContext(), 'VPN 已停止', 1500);
      hilog.info(0x0000, TAG, '%{public}s', 'stop vpnExt Success');
    } catch (err) {
      showToast(this.getUIContext(), '停止失败: ' + JSON.stringify(err), 2400);
      hilog.error(0x0000, TAG, 'stop vpnExt Fail %{public}s', JSON.stringify(err) ?? '');
    }
  }
}
