import { fileIo as fs, picker, fileUri } from '@kit.CoreFileKit';
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
      const fUri = new fileUri.FileUri(uris[0])
      await fs.copyFile(this.logPath, fUri.path)
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
      Row() {
        Button('导出日志')
          .fontSize(13)
          .fontColor(Color.White)
          .backgroundColor('#3B82F6')
          .borderRadius(8)
          .height(36)
          .layoutWeight(1)
          .onClick(() => this.exportLog())
      }
      .width('100%')
      .padding({ left: 10, right: 10, top: 8, bottom: 8 })

      Scroll(this.scroller) {
        Text(this.logContent)
          .fontSize(13)
          .fontFamily('monospace')
          .textAlign(TextAlign.Start)
          .width('100%')
          .padding(10)
          .fontColor(Color.White)
          .backgroundColor(Color.Black)
          .borderRadius(8)
      }
      .scrollBar(BarState.Off)
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
  }
}
