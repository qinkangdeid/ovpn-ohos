// 配置 Tab：列出所有 .ovpn 配置 + 导入按钮 + 整张列表（不再被 Hero 卡挤压）

import { picker, fileIo as fs, fileUri } from '@kit.CoreFileKit';
import { BasicDataSource, showToast } from './Common';
import { VpnItem } from './VpnItem';
import {
  Palette,
  Radius,
  SpringSnappy,
  Dur
} from './Theme';

interface ItemData {
  name: string
  cfg: string
  fullPath: string
}

@Component
export struct ConfigsTab {
  private data: BasicDataSource<ItemData> = new BasicDataSource<ItemData>();
  @State configCount: number = 0;
  @State importPressed: boolean = false;

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
      // === 顶部行：标题 + 计数药丸 ===
      Row() {
        Text('VPN 配置')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(Palette.textSecondary)
          .letterSpacing(0.5)
        Blank()
        if (this.configCount > 0) {
          Row({ space: 4 }) {
            Column()
              .width(5)
              .height(5)
              .borderRadius(2.5)
              .backgroundColor(Palette.primary)
            Text(`${this.configCount}`)
              .fontSize(11)
              .fontColor(Palette.primaryDeep)
              .fontWeight(FontWeight.Medium)
          }
          .padding({ left: 8, right: 10, top: 3, bottom: 3 })
          .backgroundColor(Palette.primarySoft)
          .borderRadius(Radius.pill)
        }
      }
      .width('92%')
      .padding({ top: 14, bottom: 8 })

      // === 列表 / 空态 ===
      if (this.configCount > 0) {
        List() {
          LazyForEach(this.data, (item: ItemData) => {
            ListItem() {
              VpnItem(item)
            }
            .width('100%')
            // 入场淡入（保守用 OPACITY 单效果，避免 combine 兼容性风险）
            .transition(TransitionEffect.OPACITY
              .animation({ duration: Dur.slow, curve: Curve.EaseOut }))
          })
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ bottom: 4 })
      } else {
        Column() {
          // 空态：浅色圆 + 文档图标
          Stack() {
            Column()
              .width(120)
              .height(120)
              .borderRadius(60)
              .linearGradient({
                angle: 135,
                colors: [['#EEF2FF', 0.0], ['#E0E7FF', 1.0]]
              })
            Text('📂')
              .fontSize(46)
          }

          Text('还没有配置')
            .fontSize(16)
            .fontColor(Palette.textPrimary)
            .fontWeight(FontWeight.Medium)
            .margin({ top: 22 })

          Text('点击下方按钮导入 .ovpn 文件')
            .fontSize(12)
            .fontColor(Palette.textMuted)
            .margin({ top: 6 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      }

      // === 导入按钮（玻璃质感渐变 + 按下回弹） ===
      Stack() {
        Column()
          .width('100%')
          .height(54)
          .borderRadius(Radius.md)
          .linearGradient({
            angle: 135,
            colors: [['#3B82F6', 0.0], ['#2563EB', 1.0]]
          })

        // 顶部高光
        Column()
          .width('100%')
          .height(54)
          .borderRadius(Radius.md)
          .linearGradient({
            angle: 180,
            colors: [['#FFFFFF33', 0.0], ['#FFFFFF00', 0.5]]
          })

        Row({ space: 10 }) {
          Text('+')
            .fontSize(22)
            .fontColor(Color.White)
            .fontWeight(FontWeight.Bold)
          Text('导入 .ovpn 配置')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
        }
      }
      .width('92%')
      .height(54)
      .shadow({ radius: 18, color: '#2563EB66', offsetY: 8 })
      .margin({ bottom: 18 })
      .scale({ x: this.importPressed ? 0.97 : 1, y: this.importPressed ? 0.97 : 1 })
      .animation({ duration: Dur.fast, curve: SpringSnappy })
      .onTouch((e) => {
        if (e.type === TouchType.Down) this.importPressed = true
        else if (e.type === TouchType.Up || e.type === TouchType.Cancel) this.importPressed = false
      })
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
