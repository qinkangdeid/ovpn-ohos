import hilog from '@ohos.hilog';
import { BUNDLE_NAME } from 'BuildProfile';
import { connection } from '@kit.NetworkKit';
import { picker, fileIo as fs, fileUri } from '@kit.CoreFileKit';
import { BasicDataSource, showToast } from '../components/Common';
import { BusinessError, commonEventManager } from '@kit.BasicServicesKit';
import { VpnItem } from '../components/VpnItem';

const TAG: string = '[PageIndex]'

interface connectData {
  info: string
  proxy: connection.HttpProxy
}

let ctx: UIContext
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
          showToast(ctx, `Connected: ${d.info}`, 3000);
          if (d.proxy?.host) {
            setVpnNet(d.proxy)
          }
          return;
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
  @State vpnConfig: string = '';

  getDir(): string {
    return this.getUIContext().getHostContext()?.filesDir + '/ovpn'
  }

  async aboutToAppear() {
    ctx = this.getUIContext()
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
    } catch (e) {
      console.error(e)
    }
  }

  build() {
    Column() {
      // 顶部 Header: 应用图标 + 标题
      Row() {
        Image($r('app.media.logo_splash'))
          .width(40)
          .height(40)
          .borderRadius(10)
          .margin({ right: 12 })

        Column() {
          Text('OpenVPN')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1F2937')
          Text('鸿蒙原生 VPN 客户端')
            .fontSize(11)
            .fontColor('#6B7280')
            .margin({ top: 2 })
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      }
      .width('92%')
      .padding({ top: 18, bottom: 16 })

      // 列表区
      List() {
        LazyForEach(this.data, (item: ItemData) => {
          ListItem() {
            VpnItem(item)
          }.width('100%')
        })
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ bottom: 8 })

      // 底部操作区: 主操作 Add 突出, 次级操作 Log/Clear/Browser 平铺
      Column() {
        Button('+  导入 .ovpn 配置')
          .width('92%')
          .height(46)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
          .backgroundColor('#3B82F6')
          .borderRadius(12)
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
            } catch (e) {
              showToast(this.getUIContext(), `导入失败: ${JSON.stringify(e)}`, 4000);
            }
          })

        Row() {
          Button('日志')
            .fontSize(13)
            .fontColor('#3B82F6')
            .backgroundColor('#EFF6FF')
            .borderRadius(8)
            .height(36)
            .layoutWeight(1)
            .onClick(async () => {
              try {
                await this.getUIContext().getRouter().pushUrl({ url: 'pages/Log' })
              } catch (e) {
                showToast(this.getUIContext(), `打开日志失败: ${JSON.stringify(e)}`, 4000);
              }
            })

          Button('清空日志')
            .fontSize(13)
            .fontColor('#6B7280')
            .backgroundColor('#F3F4F6')
            .borderRadius(8)
            .height(36)
            .layoutWeight(1)
            .margin({ left: 8 })
            .onClick(async () => {
              try {
                await fs.truncate(this.getUIContext().getHostContext()?.filesDir + '/ovpn.log')
                showToast(this.getUIContext(), '日志已清空', 1200);
              } catch (e) {
                showToast(this.getUIContext(), `清空失败: ${JSON.stringify(e)}`, 4000);
              }
            })

          Button('浏览器')
            .fontSize(13)
            .fontColor('#6B7280')
            .backgroundColor('#F3F4F6')
            .borderRadius(8)
            .height(36)
            .layoutWeight(1)
            .margin({ left: 8 })
            .onClick(async () => {
              try {
                await this.getUIContext().getRouter().pushUrl({ url: 'pages/Browser' })
              } catch (e) {
                showToast(this.getUIContext(), `打开失败: ${JSON.stringify(e)}`, 4000);
              }
            })
        }
        .width('92%')
        .margin({ top: 10 })
      }
      .width('100%')
      .padding({ bottom: 18 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F3F4F6')
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
