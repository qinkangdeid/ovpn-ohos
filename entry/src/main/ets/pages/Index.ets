import hilog from '@ohos.hilog';
import { BUNDLE_NAME } from 'BuildProfile';
import { connection } from '@kit.NetworkKit';
import { showToast } from '../components/Common';
import { BusinessError, commonEventManager } from '@kit.BasicServicesKit';
import { HomeTab } from '../components/HomeTab';
import { ConfigsTab } from '../components/ConfigsTab';
import { LogsTab } from '../components/LogsTab';
import { BookmarksTab } from '../components/BookmarksTab';

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
  private tabsController: TabsController = new TabsController()

  async aboutToAppear() {
    ctx = this.getUIContext()
    // 初始化 AppStorage 默认值
    if (AppStorage.get<string>('vpn.activeName') === undefined) AppStorage.setOrCreate('vpn.activeName', '')
    if (AppStorage.get<string>('vpn.busyName') === undefined) AppStorage.setOrCreate('vpn.busyName', '')
    if (AppStorage.get<number>('vpn.connectedAt') === undefined) AppStorage.setOrCreate('vpn.connectedAt', 0)
    if (AppStorage.get<string>('vpn.lastUsedName') === undefined) AppStorage.setOrCreate('vpn.lastUsedName', '')
  }

  @Builder
  TabBarItem(label: string, idx: number, icon: Resource) {
    Column() {
      Image(icon)
        .width(22)
        .height(22)
        .fillColor(this.currentTab === idx ? '#3B82F6' : '#9CA3AF')
      Text(label)
        .fontSize(11)
        .fontColor(this.currentTab === idx ? '#3B82F6' : '#6B7280')
        .fontWeight(this.currentTab === idx ? FontWeight.Medium : FontWeight.Normal)
        .margin({ top: 3 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Column() {
      // 顶部 wordmark
      Row() {
        Image($r('app.media.logo_splash'))
          .height(22)
          .objectFit(ImageFit.Contain)
        Blank()
      }
      .width('92%')
      .padding({ top: 12, bottom: 4 })

      // Tabs 容器
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
      .barHeight(64)
      .barMode(BarMode.Fixed)
      .scrollable(true)
      .onChange((idx: number) => { this.currentTab = idx })
    }
    .width('100%')
    .height('100%')
    .linearGradient({
      angle: 180,
      colors: [['#F8FAFC', 0.0], ['#EEF2F7', 1.0]]
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
