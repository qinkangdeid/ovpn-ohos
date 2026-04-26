import hilog from '@ohos.hilog';
import { BUNDLE_NAME } from 'BuildProfile';
import { connection } from '@kit.NetworkKit';
import { picker, fileIo as fs, fileUri } from '@kit.CoreFileKit';
import { BasicDataSource, showToast } from '../components/Common';
import { BusinessError, commonEventManager } from '@kit.BasicServicesKit';
import { VpnItem } from '../components/VpnItem';
import { HeroStatus } from '../components/HeroStatus';

const TAG: string = '[PageIndex]'

interface connectData {
  info: string
  proxy: connection.HttpProxy
}

let ctx: UIContext

// 模块级事件订阅：保留原有 toast 行为，并把状态镜像写入 AppStorage 给 Hero/VpnItem 复用
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
          // 把 busyName 升格为 activeName，记录连接时间
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

interface ItemData {
  name: string
  cfg: string
  fullPath: string
}

@Entry
@Component
struct Index {
  private data: BasicDataSource<ItemData> = new BasicDataSource<ItemData>();
  @State configCount: number = 0;

  getDir(): string {
    return this.getUIContext().getHostContext()?.filesDir + '/ovpn'
  }

  async aboutToAppear() {
    ctx = this.getUIContext()
    // 初始化 AppStorage 默认值（首次访问 undefined 会让 @StorageLink 报错）
    if (AppStorage.get<string>('vpn.activeName') === undefined) {
      AppStorage.setOrCreate('vpn.activeName', '')
    }
    if (AppStorage.get<string>('vpn.busyName') === undefined) {
      AppStorage.setOrCreate('vpn.busyName', '')
    }
    if (AppStorage.get<number>('vpn.connectedAt') === undefined) {
      AppStorage.setOrCreate('vpn.connectedAt', 0)
    }

    const dir = this.getDir()
    try {
      await fs.mkdir(dir)
    } catch (e) {
    }
    try {
      const files = await fs.listFile(dir)
      for (let name of files) {
        const fullPath = dir + '/' + name
        const cfg = await fs.readText(fullPath)
        this.data.push({ name, cfg, fullPath })
      }
      this.configCount = this.data.totalCount()
    } catch (e) {
      console.error(e)
    }
  }

  @Builder
  EmptyState() {
    Column() {
      Stack() {
        Circle({ width: 88, height: 88 })
          .fill('#EEF2FF')
        Text('📂')
          .fontSize(38)
      }
      Text('还没有配置')
        .fontSize(15)
        .fontColor('#374151')
        .fontWeight(FontWeight.Medium)
        .margin({ top: 16 })
      Text('点击下方按钮导入 .ovpn 文件')
        .fontSize(12)
        .fontColor('#9CA3AF')
        .margin({ top: 6 })
    }
    .width('100%')
    .padding({ top: 32, bottom: 32 })
  }

  @Builder
  SecondaryAction(label: string, glyph: Resource, onTap: () => void) {
    Column() {
      SymbolGlyph(glyph)
        .fontSize(20)
        .fontColor(['#6B7280'])
      Text(label)
        .fontSize(11)
        .fontColor('#374151')
        .margin({ top: 4 })
    }
    .layoutWeight(1)
    .height(56)
    .justifyContent(FlexAlign.Center)
    .borderRadius(12)
    .backgroundColor('#FFFFFF')
    .onClick(() => { onTap() })
  }

  build() {
    Column() {
      // 顶部 wordmark
      Row() {
        Image($r('app.media.logo_splash'))
          .height(26)
          .objectFit(ImageFit.Contain)
        Blank()
      }
      .width('92%')
      .padding({ top: 14, bottom: 4 })

      // Hero 状态卡
      HeroStatus()

      // 列表区头
      Row() {
        Text('VPN 配置')
          .fontSize(13)
          .fontColor('#6B7280')
          .fontWeight(FontWeight.Medium)
        Blank()
        if (this.configCount > 0) {
          Text(`${this.configCount}`)
            .fontSize(11)
            .fontColor('#6B7280')
            .backgroundColor('#FFFFFF')
            .borderRadius(10)
            .padding({ left: 10, right: 10, top: 2, bottom: 2 })
        }
      }
      .width('92%')
      .margin({ bottom: 6 })

      // 列表 / 空状态
      if (this.configCount > 0) {
        List() {
          LazyForEach(this.data, (item: ItemData) => {
            ListItem() {
              VpnItem(item)
            }.width('100%')
          })
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ bottom: 4 })
      } else {
        Column() {
          this.EmptyState()
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      }

      // 底部操作区
      Column() {
        // 主操作 - 导入配置
        Button() {
          Row() {
            Text('+')
              .fontSize(20)
              .fontColor(Color.White)
              .fontWeight(FontWeight.Bold)
            Text('导入 .ovpn 配置')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
              .margin({ left: 8 })
          }
        }
        .width('92%')
        .height(50)
        .backgroundColor('#3B82F6')
        .borderRadius(14)
        .shadow({ radius: 14, color: '#3B82F644', offsetY: 6 })
        .onClick(async () => {
          try {
            const dp = new picker.DocumentViewPicker();
            const uris = await dp.select({ fileSuffixFilters: ['.ovpn'] })
            if (!uris || !uris.length) {
              return
            }
            const dir = this.getDir()
            for (let uri of uris) {
              const fUri = new fileUri.FileUri(uri)
              const cfg = await fs.readText(fUri.path)
              const fullPath = `${dir}/${fUri.name}`
              const fd = await fs.open(fullPath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE)
              await fs.write(fd.fd, cfg)
              await fs.close(fd)
              this.data.push({ name: fUri.name, cfg, fullPath })
            }
            this.configCount = this.data.totalCount()
          } catch (e) {
            showToast(this.getUIContext(), `导入失败: ${JSON.stringify(e)}`, 4000);
          }
        })

        // 次级操作三联
        Row({ space: 8 }) {
          this.SecondaryAction('日志', $r('sys.symbol.doc_plaintext'), async () => {
            try {
              await this.getUIContext().getRouter().pushUrl({ url: 'pages/Log' })
            } catch (e) {
              showToast(this.getUIContext(), `打开日志失败: ${JSON.stringify(e)}`, 4000);
            }
          })

          this.SecondaryAction('清空日志', $r('sys.symbol.trash'), async () => {
            try {
              await fs.truncate(this.getUIContext().getHostContext()?.filesDir + '/ovpn.log')
              showToast(this.getUIContext(), '日志已清空', 1200);
            } catch (e) {
              showToast(this.getUIContext(), `清空失败: ${JSON.stringify(e)}`, 4000);
            }
          })

          this.SecondaryAction('浏览器', $r('sys.symbol.globe'), async () => {
            try {
              await this.getUIContext().getRouter().pushUrl({ url: 'pages/Browser' })
            } catch (e) {
              showToast(this.getUIContext(), `打开失败: ${JSON.stringify(e)}`, 4000);
            }
          })
        }
        .width('92%')
        .margin({ top: 12 })
      }
      .width('100%')
      .padding({ bottom: 18 })
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
