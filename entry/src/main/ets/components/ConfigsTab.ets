// 配置 Tab：列出所有 .ovpn 配置 + 导入按钮 + 整张列表（不再被 Hero 卡挤压）

import { picker, fileIo as fs, fileUri } from '@kit.CoreFileKit';
import { BasicDataSource, showToast } from './Common';
import { VpnItem } from './VpnItem';

interface ItemData {
  name: string
  cfg: string
  fullPath: string
}

@Component
export struct ConfigsTab {
  private data: BasicDataSource<ItemData> = new BasicDataSource<ItemData>();
  @State configCount: number = 0;

  getDir(): string {
    return this.getUIContext().getHostContext()?.filesDir + '/ovpn'
  }

  async aboutToAppear() {
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

  build() {
    Column() {
      // 顶部 + 计数
      Row() {
        Text('VPN 配置')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#374151')
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
      .padding({ top: 14, bottom: 8 })

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
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      }

      // 导入按钮
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
      .margin({ bottom: 16 })
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
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
  }
}
