import { fileIo as fs, picker } from '@kit.CoreFileKit';
import { BusinessError } from '@ohos.base';
import { showToast } from '../components/Common';

@Entry
@Component
struct LogTailComponent {
  @State logContent: string = 'loading...';
  private logPath: string = ''; // 日志文件路径
  private isActive: boolean = true;
  private watcher?: fs.Watcher;
  private scroller: Scroller = new Scroller();

  // 组件创建时开始监听
  aboutToAppear() {
    this.logPath = this.getUIContext().getHostContext()?.filesDir + '/ovpn.log'
    this.startLogTail();
  }

  // 组件销毁时停止监听
  aboutToDisappear() {
    this.stopLogTail();
  }

  // 开始日志监听
  async startLogTail() {
    try {
      // 检查文件是否存在
      if (!(await this.checkFileExists())) {
        this.logContent = '日志文件不存在';
        return;
      }
      await this.readLog();

      this.watcher = fs.createWatcher(this.logPath, 0x2, async (e) => {
        if (!this.isActive) {
          return;
        }
        await this.readLog();
      })
      this.watcher.start();
    } catch (err) {
      this.logContent = `错误: ${(err as BusinessError).message}`;
    }
  }

  // 停止日志监听
  stopLogTail() {
    this.isActive = false;
    try {
      this.watcher?.stop()
    } catch (err) {
      console.error(`停止监听失败: ${(err as BusinessError).message}`);
    }
  }

  // 检查文件是否存在
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

  // 导出日志：通过系统 SaveDocumentPicker 让用户选位置保存（可保存到下载/iCloud/U 盘等）
  // 文件名带时间戳避免覆盖。落盘后用户可自行用 AirDrop / 微信 / 邮件等发出去。
  // 注意：picker.save 返回的是 URI，不能走 fileUri.FileUri.path 转沙箱内路径再 copyFile，
  // 那样会触发 13900001 (Operation not permitted)。要直接用 URI 调 fs.open 打开目标文件。
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
      if (!uris || !uris.length) {
        return
      }
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

  onPageShow() {
    setTimeout(() => {
      this.scroller.scrollEdge(Edge.Bottom);
    }, 1e3)
  }

  build() {
    Column() {
      // 顶部栏
      Row() {
        Text('‹')
          .fontSize(28)
          .fontColor('#1F2937')
          .fontWeight(FontWeight.Medium)
          .width(40)
          .height(40)
          .textAlign(TextAlign.Center)
          .onClick(() => { this.getUIContext().getRouter().back() })

        Text('运行日志')
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1F2937')
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .margin({ right: 40 })
      }
      .width('100%')
      .height(48)
      .padding({ left: 8, right: 8 })
      .backgroundColor('#FFFFFF')

      Divider().color('#E5E7EB')

      // 终端面板
      Column() {
        Scroll(this.scroller) {
          Text(this.logContent)
            .fontSize(12)
            .fontFamily('monospace')
            .textAlign(TextAlign.Start)
            .width('100%')
            .padding(12)
            .fontColor('#E2E8F0')
        }
        .scrollBar(BarState.Off)
        .layoutWeight(1)
        .width('100%')
        .backgroundColor('#0F172A')
        .borderRadius(12)
      }
      .width('92%')
      .layoutWeight(1)
      .margin({ top: 12, bottom: 12 })

      // 底部导出
      Row() {
        Button('导出日志')
          .fontSize(14)
          .fontColor(Color.White)
          .fontWeight(FontWeight.Medium)
          .height(44)
          .layoutWeight(1)
          .backgroundColor('#3B82F6')
          .borderRadius(12)
          .shadow({ radius: 10, color: '#3B82F633', offsetY: 4 })
          .onClick(() => this.exportLog())
      }
      .width('92%')
      .padding({ bottom: 16 })
    }
    .width('100%')
    .height('100%')
    .linearGradient({
      angle: 180,
      colors: [['#F8FAFC', 0.0], ['#EEF2F7', 1.0]]
    })
  }
}
