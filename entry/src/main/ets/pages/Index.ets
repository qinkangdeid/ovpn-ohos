import hilog from '@ohos.hilog';
import { BUNDLE_NAME } from 'BuildProfile';
import { connection } from '@kit.NetworkKit';
import { showToast } from '../components/Common';
import { BusinessError, commonEventManager } from '@kit.BasicServicesKit';
import { HomeTab } from '../components/HomeTab';
import { ConfigsTab } from '../components/ConfigsTab';
import { LogsTab } from '../components/LogsTab';
import { BookmarksTab } from '../components/BookmarksTab';
import {
  Palette,
  Radius,
  SpringResponsive,
  SpringSnappy,
  Dur
} from '../components/Theme';

const TAG: string = '[PageIndex]'

interface connectData {
  info: string
  proxy: connection.HttpProxy
}

let ctx: UIContext

// 模块级事件订阅：把 native 端的 CONNECTED/DESTROY/READ_CONFIG_ERR 镜像到 AppStorage，
// HomeTab/VpnItem 通过 @StorageLink 自动响应。
try {
  commonEventManager.createSubscriber({
    events: ['ovpn.READ_CONFIG_ERR', 'ovpn.CONNECTED', 'ovpn.DESTROY'],
    publisherBundleName: BUNDLE_NAME
  },
    (err: BusinessError, subscriber: commonEventManager.CommonEventSubscriber) => {
      if (err) {
        hilog.error(0x0000, TAG, `createSubscriberErr: ${err.code}, name: ${err.name}, msg: ${err.message}`);
        return
      }
      commonEventManager.subscribe(subscriber, (err: BusinessError, data: commonEventManager.CommonEventData) => {
        if (err) {
          hilog.error(0x0000, TAG, `subscribe event err: ${err.code}, name: ${err.name}, msg: ${err.message}`);
          return
        }
        if (data.event === 'ovpn.CONNECTED' && data.data) {
          const s = data.data as string
          const d = JSON.parse(s) as connectData;
          hilog.info(0x0000, TAG, `Connected: ${d.info}`);
          showToast(ctx, `已连接: ${d.info}`, 2400);
          const busy = AppStorage.get<string>('vpn.busyName') ?? ''
          AppStorage.setOrCreate('vpn.activeName', busy)
          AppStorage.setOrCreate('vpn.connectedAt', Date.now())
          AppStorage.setOrCreate('vpn.busyName', '')
          if (d.proxy?.host) {
            setVpnNet(d.proxy)
          }
          return;
        }
        if (data.event === 'ovpn.DESTROY') {
          AppStorage.setOrCreate('vpn.activeName', '')
          AppStorage.setOrCreate('vpn.connectedAt', 0)
          AppStorage.setOrCreate('vpn.busyName', '')
        }
        if (data.event === 'ovpn.READ_CONFIG_ERR') {
          AppStorage.setOrCreate('vpn.busyName', '')
          showToast(ctx, '配置读取失败', 3000)
        }
        hilog.info(0x0000, TAG, `subscribe event: ${data.event}, data: ${data.data}`);
      })
    });
} catch (e) {
  hilog.error(0x0000, TAG, `createSubscriber failed, code is ${JSON.stringify(e)}`);
}

@Entry
@Component
struct Index {
  @State currentTab: number = 0
  @StorageLink('vpn.activeName') activeName: string = ''
  @StorageLink('vpn.busyName') busyName: string = ''
  @StorageLink('vpn.connectedAt') connectedAt: number = 0
  @State now: number = Date.now()
  @State pillPulse: number = 1
  private tabsController: TabsController = new TabsController()
  private timer: number = -1

  async aboutToAppear() {
    ctx = this.getUIContext()
    if (AppStorage.get<string>('vpn.activeName') === undefined) AppStorage.setOrCreate('vpn.activeName', '')
    if (AppStorage.get<string>('vpn.busyName') === undefined) AppStorage.setOrCreate('vpn.busyName', '')
    if (AppStorage.get<number>('vpn.connectedAt') === undefined) AppStorage.setOrCreate('vpn.connectedAt', 0)
    if (AppStorage.get<string>('vpn.lastUsedName') === undefined) AppStorage.setOrCreate('vpn.lastUsedName', '')
    this.timer = setInterval(() => { this.now = Date.now() }, 1000) as number
    this.pillPulse = 1.18
  }

  aboutToDisappear() {
    if (this.timer !== -1) {
      clearInterval(this.timer)
      this.timer = -1
    }
  }

  isConnected(): boolean { return !!this.activeName && !this.busyName }
  isBusy(): boolean { return !!this.busyName }

  durationText(): string {
    const ms = this.now - this.connectedAt
    if (ms <= 0) return ''
    const s = Math.floor(ms / 1000)
    const h = Math.floor(s / 3600)
    const m = Math.floor((s % 3600) / 60)
    const sec = s % 60
    const pad: (n: number) => string = (n) => n.toString().padStart(2, '0')
    return h > 0 ? `${pad(h)}:${pad(m)}:${pad(sec)}` : `${pad(m)}:${pad(sec)}`
  }

  // === 顶部全局状态药丸 ===
  @Builder
  StatusPill() {
    if (this.isBusy()) {
      Row({ space: 6 }) {
        Column()
          .width(6)
          .height(6)
          .borderRadius(3)
          .backgroundColor(Palette.primary)
          .scale({ x: this.pillPulse, y: this.pillPulse })
          .animation({
            duration: 900,
            iterations: -1,
            curve: Curve.EaseInOut,
            playMode: PlayMode.Alternate
          })
        Text(this.busyName.replace(/\.ovpn$/, '') + ' 处理中')
          .fontSize(11)
          .fontColor(Palette.primaryDeep)
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .padding({ left: 9, right: 12, top: 5, bottom: 5 })
      .backgroundColor(Palette.primarySoft)
      .borderRadius(Radius.pill)
    } else if (this.isConnected()) {
      Row({ space: 6 }) {
        Column()
          .width(6)
          .height(6)
          .borderRadius(3)
          .backgroundColor(Palette.successBright)
          .scale({ x: this.pillPulse, y: this.pillPulse })
          .animation({
            duration: 1200,
            iterations: -1,
            curve: Curve.EaseInOut,
            playMode: PlayMode.Alternate
          })
        Text(this.durationText())
          .fontSize(11)
          .fontFamily('monospace')
          .fontColor(Palette.success)
          .fontWeight(FontWeight.Medium)
      }
      .padding({ left: 9, right: 12, top: 5, bottom: 5 })
      .backgroundColor(Palette.successSoft)
      .borderRadius(Radius.pill)
    }
  }

  @Builder
  TabBarItem(label: string, idx: number, icon: Resource) {
    Column() {
      // 顶部指示条（淡入 + 缩放）
      Column()
        .width(this.currentTab === idx ? 22 : 0)
        .height(3)
        .borderRadius(2)
        .backgroundColor(Palette.primary)
        .opacity(this.currentTab === idx ? 1 : 0)
        .animation({ duration: Dur.base, curve: SpringResponsive })

      Image(icon)
        .width(22)
        .height(22)
        .fillColor(this.currentTab === idx ? Palette.primary : Palette.textMuted)
        .margin({ top: 6 })
        .scale({
          x: this.currentTab === idx ? 1.08 : 1,
          y: this.currentTab === idx ? 1.08 : 1
        })
        .animation({ duration: Dur.base, curve: SpringSnappy })

      Text(label)
        .fontSize(11)
        .fontColor(this.currentTab === idx ? Palette.primary : Palette.textSecondary)
        .fontWeight(this.currentTab === idx ? FontWeight.Medium : FontWeight.Normal)
        .margin({ top: 3 })
        .animation({ duration: Dur.base, curve: SpringResponsive })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Column() {
      // === 顶栏：wordmark + 全局状态药丸 ===
      Row() {
        Image($r('app.media.logo_splash'))
          .height(22)
          .objectFit(ImageFit.Contain)
        Blank()
        this.StatusPill()
      }
      .width('92%')
      .padding({ top: 14, bottom: 6 })

      // === Tabs ===
      Tabs({ barPosition: BarPosition.End, controller: this.tabsController, index: this.currentTab }) {
        TabContent() {
          HomeTab()
        }.tabBar(this.TabBarItem('连接', 0, $r('app.media.ic_shield')))

        TabContent() {
          ConfigsTab()
        }.tabBar(this.TabBarItem('配置', 1, $r('app.media.ic_settings')))

        TabContent() {
          LogsTab()
        }.tabBar(this.TabBarItem('日志', 2, $r('app.media.ic_log')))

        TabContent() {
          BookmarksTab()
        }.tabBar(this.TabBarItem('浏览器', 3, $r('app.media.ic_globe')))
      }
      .layoutWeight(1)
      .barWidth('100%')
      .barHeight(68)
      .barMode(BarMode.Fixed)
      .scrollable(true)
      .barBackgroundColor('#FFFFFFCC')
      .onChange((idx: number) => { this.currentTab = idx })
    }
    .width('100%')
    .height('100%')
    .linearGradient({
      angle: 180,
      colors: [[Palette.bgTop, 0.0], [Palette.bgBottom, 1.0]]
    })
  }
}

async function setVpnNet(proxy: connection.HttpProxy) {
  try {
    proxy.exclusionList = ['10.', '192.168', '172.16']
    connection.setAppHttpProxy(proxy)
  } catch (e) {
    hilog.error(0x0000, TAG, 'SetAppHttpProxyErr: %{public}s', JSON.stringify(e));
  }
}
