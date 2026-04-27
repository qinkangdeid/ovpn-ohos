// 日志 Tab：尾随 ovpn.log + 清空 / 导出

import { fileIo as fs, picker } from '@kit.CoreFileKit';
import { BusinessError } from '@ohos.base';
import { showToast } from './Common';
import { Palette, Radius, ShadowSoft } from './Theme';

@Component
export struct LogsTab {
  @State logContent: string = 'loading...';
  private logPath: string = '';
  private isActive: boolean = true;
  private watcher?: fs.Watcher;
  private scroller: Scroller = new Scroller();

  aboutToAppear() {
    this.logPath = this.getUIContext().getHostContext()?.filesDir + '/ovpn.log'
    this.startLogTail();
  }

  aboutToDisappear() {
    this.stopLogTail();
  }

  async startLogTail() {
    try {
      if (!(await this.checkFileExists())) {
        this.logContent = '日志文件不存在';
        return;
      }
      await this.readLog();

      this.watcher = fs.createWatcher(this.logPath, 0x2, async (_e) => {
        if (!this.isActive) return;
        await this.readLog();
      })
      this.watcher.start();
    } catch (err) {
      this.logContent = `错误: ${(err as BusinessError).message}`;
    }
  }

  stopLogTail() {
    this.isActive = false;
    try {
      this.watcher?.stop()
    } catch (err) {
      console.error(`停止监听失败: ${(err as BusinessError).message}`);
    }
  }

  private async checkFileExists(): Promise<boolean> {
    try {
      const stat = await fs.stat(this.logPath);
      return stat.isFile();
    } catch {
      return false;
    }
  }

  private async readLog() {
    try {
      const fd = await fs.open(this.logPath, fs.OpenMode.READ_ONLY);
      this.logContent = await fs.readText(this.logPath, { encoding: 'utf-8' })
      await fs.close(fd);
      this.scroller.scrollEdge(Edge.Bottom);
    } catch (err) {
      this.logContent = `读取失败: ${(err as BusinessError).message}`;
    }
  }

  async clearLog() {
    try {
      await fs.truncate(this.logPath)
      this.logContent = ''
      showToast(this.getUIContext(), '日志已清空', 1200)
    } catch (e) {
      showToast(this.getUIContext(), `清空失败: ${JSON.stringify(e)}`, 2400);
    }
  }

  async exportLog() {
    try {
      if (!(await this.checkFileExists())) {
        showToast(this.getUIContext(), '日志文件不存在', 1500)
        return
      }
      const ts = new Date().toISOString().replace(/[:.]/g, '-').replace('T', '_').slice(0, 19)
      const fname = `ovpn-${ts}.log`
      const dp = new picker.DocumentViewPicker()
      const uris = await dp.save({ newFileNames: [fname] })
      if (!uris || !uris.length) return
      const dstUri = uris[0]
      const text = await fs.readText(this.logPath, { encoding: 'utf-8' })
      const dst = await fs.open(dstUri, fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC)
      try {
        await fs.write(dst.fd, text)
      } finally {
        await fs.close(dst)
      }
      showToast(this.getUIContext(), `已导出: ${fname}`, 2400)
    } catch (err) {
      showToast(this.getUIContext(), `导出失败: ${JSON.stringify(err)}`, 3000)
    }
  }

  build() {
    Column() {
      // 顶部操作行
      Row({ space: 10 }) {
        Text('运行日志')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(Palette.textSecondary)
          .letterSpacing(0.5)
          .layoutWeight(1)
        Button('清空')
          .fontSize(12)
          .fontColor(Palette.textSecondary)
          .backgroundColor(Palette.surface)
          .height(34)
          .borderRadius(Radius.sm)
          .padding({ left: 16, right: 16 })
          .shadow(ShadowSoft)
          .onClick(() => this.clearLog())
        Button('导出')
          .fontSize(12)
          .fontColor(Color.White)
          .backgroundColor(Palette.primary)
          .height(34)
          .borderRadius(Radius.sm)
          .padding({ left: 16, right: 16 })
          .shadow({ radius: 12, color: '#2563EB55', offsetY: 4 })
          .onClick(() => this.exportLog())
      }
      .width('92%')
      .padding({ top: 14, bottom: 10 })

      // 日志面板（双层：外层渐变描边 + 内层深色）
      Stack() {
        // 渐变描边
        Column()
          .width('100%')
          .height('100%')
          .borderRadius(Radius.md)
          .linearGradient({
            angle: 135,
            colors: [['#1E293B', 0.0], ['#0F172A', 1.0]]
          })

        Scroll(this.scroller) {
          Text(this.logContent)
            .fontSize(12)
            .fontFamily('monospace')
            .textAlign(TextAlign.Start)
            .width('100%')
            .padding(14)
            .fontColor('#CBD5E1')
        }
        .scrollBar(BarState.Off)
        .width('100%')
        .height('100%')
      }
      .width('92%')
      .layoutWeight(1)
      .borderRadius(Radius.md)
      .clip(true)
      .shadow({ radius: 16, color: '#0F172A33', offsetY: 6 })
      .margin({ bottom: 18 })
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
  }
}
