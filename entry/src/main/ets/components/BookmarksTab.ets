// 浏览器 Tab：分组书签 grid。
// 默认组(网络检测/国内/国外)写死在代码里,公开可提交。
// 私有组(公司/家里 等)由用户自己写 JSON 导入,存到沙箱 filesDir/bookmarks.json,
// 不进仓库。格式见仓库根目录 docs/bookmarks.example.json。

import hilog from '@ohos.hilog';
import { picker, fileIo as fs, fileUri } from '@kit.CoreFileKit';
import { showToast } from './Common';

const TAG: string = '[BookmarksTab]'
const STORE_FILE: string = 'bookmarks.json'

interface Bookmark {
  name: string
  url: string
  badge?: string
  bg?: string
}

interface BookmarkGroup {
  name: string
  bookmarks: Bookmark[]
}

interface BookmarksFile {
  groups: BookmarkGroup[]
}

// 公开默认组：写死在代码里,公开仓库无敏感信息
const DEFAULT_GROUPS: BookmarkGroup[] = [
  {
    name: '网络检测',
    bookmarks: [
      { name: '我的 IP', url: 'https://ip.sb', badge: 'IP', bg: '#3B82F6' },
      { name: 'IP 信息', url: 'https://ipinfo.io', badge: 'i', bg: '#0EA5E9' },
      { name: 'IP 检测', url: 'https://www.whatismyip.com', badge: 'W', bg: '#6366F1' },
      { name: 'DNS 检测', url: 'https://www.dnsleaktest.com', badge: 'D', bg: '#8B5CF6' },
      { name: '网速测试', url: 'https://fast.com', badge: 'F', bg: '#EF4444' },
    ]
  },
  {
    name: '国内',
    bookmarks: [
      { name: '百度', url: 'https://www.baidu.com', badge: '百', bg: '#2932E1' },
      { name: 'B站', url: 'https://www.bilibili.com', badge: 'B', bg: '#FB7299' },
      { name: '知乎', url: 'https://www.zhihu.com', badge: '知', bg: '#0084FF' },
      { name: '微博', url: 'https://weibo.com', badge: '微', bg: '#E6162D' },
      { name: '淘宝', url: 'https://www.taobao.com', badge: '淘', bg: '#FF6F00' },
      { name: '京东', url: 'https://www.jd.com', badge: '京', bg: '#E1251B' },
    ]
  },
  {
    name: '国外',
    bookmarks: [
      { name: 'Google', url: 'https://www.google.com', badge: 'G', bg: '#22C55E' },
      { name: 'YouTube', url: 'https://www.youtube.com', badge: 'Y', bg: '#DC2626' },
      { name: 'GitHub', url: 'https://github.com', badge: 'GH', bg: '#1F2937' },
      { name: 'Twitter/X', url: 'https://twitter.com', badge: 'X', bg: '#000000' },
      { name: 'Reddit', url: 'https://www.reddit.com', badge: 'R', bg: '#F97316' },
      { name: 'Wikipedia', url: 'https://www.wikipedia.org', badge: 'W', bg: '#6B7280' },
      { name: 'Stack Overflow', url: 'https://stackoverflow.com', badge: 'SO', bg: '#F59E0B' },
      { name: 'Hacker News', url: 'https://news.ycombinator.com', badge: 'HN', bg: '#FF6600' },
    ]
  },
]

// 当用户 JSON 没指定 badge/bg 时,按名字自动生成
const BADGE_PALETTE: string[] = [
  '#3B82F6', '#22C55E', '#EF4444', '#F59E0B',
  '#8B5CF6', '#EC4899', '#0EA5E9', '#10B981',
  '#6366F1', '#F97316'
]

function autoBadge(name: string): string {
  const trimmed = name.trim()
  if (!trimmed) return '?'
  const code = trimmed.charCodeAt(0)
  // 中文区间直接取第一个字符
  if (code >= 0x4E00 && code <= 0x9FFF) return trimmed.charAt(0)
  return trimmed.charAt(0).toUpperCase()
}

function autoColor(name: string): string {
  let h = 0
  for (let i = 0; i < name.length; i++) {
    h = ((h << 5) - h + name.charCodeAt(i)) | 0
  }
  return BADGE_PALETTE[Math.abs(h) % BADGE_PALETTE.length]
}

function getBadge(bm: Bookmark): string {
  return bm.badge && bm.badge.length > 0 ? bm.badge : autoBadge(bm.name)
}

function getBg(bm: Bookmark): string {
  return bm.bg && bm.bg.length > 0 ? bm.bg : autoColor(bm.name)
}

// 粘贴 JSON 对话框:多行 TextArea + 解析/取消按钮。
// TextArea 长按系统会出"粘贴"菜单,鸿蒙 ArkUI 原生支持,不需要额外申请权限。
@CustomDialog
struct PasteJsonDialog {
  controller: CustomDialogController
  @State text: string = ''
  onConfirm: (text: string) => void = (text: string) => {}

  build() {
    Column() {
      Text('粘贴书签 JSON')
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor('#1F2937')
      Text('在下方粘贴(长按文本框可调出系统粘贴菜单)')
        .fontSize(11)
        .fontColor('#9CA3AF')
        .margin({ top: 6, bottom: 12 })

      TextArea({ text: this.text, placeholder: '在此粘贴 JSON…' })
        .fontSize(12)
        .fontFamily('monospace')
        .placeholderColor('#9CA3AF')
        .fontColor('#1F2937')
        .height(240)
        .width('100%')
        .borderRadius(10)
        .backgroundColor('#F8FAFC')
        .padding(12)
        .onChange((v: string) => { this.text = v })

      Row({ space: 10 }) {
        Button('取消')
          .fontSize(14)
          .fontColor('#6B7280')
          .backgroundColor('#F3F4F6')
          .height(42)
          .layoutWeight(1)
          .borderRadius(10)
          .onClick(() => { this.controller.close() })
        Button('解析并导入')
          .fontSize(14)
          .fontColor(Color.White)
          .backgroundColor('#3B82F6')
          .height(42)
          .layoutWeight(1)
          .borderRadius(10)
          .onClick(() => {
            const t: string = this.text
            this.controller.close()
            this.onConfirm(t)
          })
      }
      .width('100%')
      .margin({ top: 14 })
    }
    .padding(20)
    .width(360)
    .backgroundColor(Color.White)
    .borderRadius(18)
  }
}

@Component
export struct BookmarksTab {
  @State groups: BookmarkGroup[] = DEFAULT_GROUPS.slice()
  @State hasImported: boolean = false

  async aboutToAppear() {
    await this.loadImported()
  }

  private getStorePath(): string {
    return (this.getUIContext().getHostContext()?.filesDir ?? '') + '/' + STORE_FILE
  }

  private async fileExists(path: string): Promise<boolean> {
    try {
      const stat = await fs.stat(path)
      return stat.isFile()
    } catch {
      return false
    }
  }

  async loadImported() {
    const path = this.getStorePath()
    if (!path) return
    try {
      if (!(await this.fileExists(path))) return
      const text = await fs.readText(path)
      const data = JSON.parse(text) as BookmarksFile
      if (data && data.groups && data.groups.length > 0) {
        this.groups = DEFAULT_GROUPS.concat(data.groups)
        this.hasImported = true
      }
    } catch (e) {
      hilog.error(0x0000, TAG, 'load imported bookmarks fail %{public}s', JSON.stringify(e) ?? '')
    }
  }

  // 共享:解析 JSON 文本 + 落盘 + 刷新 UI。
  // 粘贴入口和文件入口最终都汇到这里。
  async importFromText(text: string) {
    const trimmed = text.trim()
    if (!trimmed) {
      showToast(this.getUIContext(), '内容为空', 1500)
      return
    }
    let data: BookmarksFile
    try {
      data = JSON.parse(trimmed) as BookmarksFile
    } catch (parseErr) {
      showToast(this.getUIContext(), 'JSON 解析失败,请检查格式', 2800)
      return
    }
    if (!data || !data.groups || data.groups.length === 0) {
      showToast(this.getUIContext(), '格式错误:缺少 groups 字段或为空', 2800)
      return
    }
    try {
      const path = this.getStorePath()
      const fd = await fs.open(path, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC)
      try {
        await fs.write(fd.fd, JSON.stringify(data))
      } finally {
        await fs.close(fd)
      }
      this.groups = DEFAULT_GROUPS.concat(data.groups)
      this.hasImported = true

      let totalBm = 0
      for (let i = 0; i < data.groups.length; i++) {
        const bms = data.groups[i].bookmarks
        if (bms) totalBm += bms.length
      }
      showToast(this.getUIContext(), `已导入 ${data.groups.length} 个分组 / ${totalBm} 条书签`, 2400)
    } catch (e) {
      showToast(this.getUIContext(), `保存失败: ${JSON.stringify(e)}`, 3000)
      hilog.error(0x0000, TAG, 'save bookmarks fail %{public}s', JSON.stringify(e) ?? '')
    }
  }

  // 入口 1:从文件选取
  async importFromFile() {
    try {
      const dp = new picker.DocumentViewPicker()
      const uris = await dp.select({ fileSuffixFilters: ['.json'] })
      if (!uris || !uris.length) return
      const fUri = new fileUri.FileUri(uris[0])
      const text = await fs.readText(fUri.path)
      await this.importFromText(text)
    } catch (e) {
      showToast(this.getUIContext(), `读取文件失败: ${JSON.stringify(e)}`, 3000)
      hilog.error(0x0000, TAG, 'pick file fail %{public}s', JSON.stringify(e) ?? '')
    }
  }

  // 入口 2:粘贴 JSON 文本(打开对话框,用户长按粘贴)
  importFromPaste() {
    this.pasteDialog.open()
  }

  private pasteDialog: CustomDialogController = new CustomDialogController({
    builder: PasteJsonDialog({
      onConfirm: (text: string) => { this.importFromText(text) }
    }),
    alignment: DialogAlignment.Center,
    autoCancel: true,
    customStyle: false
  })

  async clearImported() {
    try {
      const path = this.getStorePath()
      if (await this.fileExists(path)) {
        await fs.unlink(path)
      }
      this.groups = DEFAULT_GROUPS.slice()
      this.hasImported = false
      showToast(this.getUIContext(), '已清除自定义书签', 1500)
    } catch (e) {
      showToast(this.getUIContext(), `清除失败: ${JSON.stringify(e)}`, 2400)
    }
  }

  open(url: string) {
    try {
      this.getUIContext().getRouter().pushUrl({ url: 'pages/Browser', params: { url: url } })
    } catch (e) {
      showToast(this.getUIContext(), `打开失败: ${JSON.stringify(e)}`, 2400)
    }
  }

  shortHost(url: string): string {
    return url.replace(/^https?:\/\//, '').replace(/\/.*$/, '')
  }

  @Builder
  BookmarkCard(bm: Bookmark) {
    Column() {
      Stack() {
        Circle({ width: 52, height: 52 })
          .fill(getBg(bm))
        Text(getBadge(bm))
          .fontSize(getBadge(bm).length > 1 ? 16 : 22)
          .fontColor(Color.White)
          .fontWeight(FontWeight.Bold)
      }
      Text(bm.name)
        .fontSize(12)
        .fontColor('#1F2937')
        .fontWeight(FontWeight.Medium)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ top: 8 })
      Text(this.shortHost(bm.url))
        .fontSize(10)
        .fontColor('#9CA3AF')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ top: 2 })
    }
    .width('100%')
    .padding({ top: 14, bottom: 14 })
    .backgroundColor('#FFFFFF')
    .borderRadius(14)
    .onClick(() => this.open(bm.url))
  }

  build() {
    Column() {
      // 顶部
      Row({ space: 8 }) {
        Text('快捷书签')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#374151')
          .layoutWeight(1)
        if (this.hasImported) {
          Button('清除')
            .fontSize(12)
            .fontColor('#6B7280')
            .backgroundColor('#FFFFFF')
            .height(30)
            .borderRadius(8)
            .padding({ left: 12, right: 12 })
            .onClick(() => this.clearImported())
        }
        Button('+ 导入')
          .fontSize(12)
          .fontColor(Color.White)
          .backgroundColor('#3B82F6')
          .height(30)
          .borderRadius(8)
          .padding({ left: 12, right: 12 })
          .bindMenu([
            { value: '粘贴 JSON 文本', action: () => this.importFromPaste() },
            { value: '选取 JSON 文件', action: () => this.importFromFile() },
          ])
      }
      .width('92%')
      .padding({ top: 14, bottom: 8 })

      Scroll() {
        Column({ space: 14 }) {
          ForEach(this.groups, (g: BookmarkGroup) => {
            Column() {
              // 组标题
              Row() {
                Text(g.name)
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#374151')
                Text(`${g.bookmarks ? g.bookmarks.length : 0}`)
                  .fontSize(11)
                  .fontColor('#9CA3AF')
                  .margin({ left: 8 })
                Blank()
              }
              .width('100%')
              .padding({ left: 4, right: 4, bottom: 8 })

              Grid() {
                ForEach(g.bookmarks ? g.bookmarks : [], (bm: Bookmark) => {
                  GridItem() {
                    this.BookmarkCard(bm)
                  }
                }, (bm: Bookmark) => bm.url)
              }
              .columnsTemplate('1fr 1fr 1fr 1fr')
              .columnsGap(10)
              .rowsGap(10)
              .width('100%')
            }
            .width('100%')
          }, (g: BookmarkGroup) => g.name)

          if (!this.hasImported) {
            Column() {
              Text('提示')
                .fontSize(11)
                .fontColor('#9CA3AF')
                .fontWeight(FontWeight.Medium)
              Text('私有书签(公司/家里 等)点右上角"+ 导入":')
                .fontSize(11)
                .fontColor('#9CA3AF')
                .margin({ top: 4 })
              Text('• 粘贴 JSON 文本(微信/飞书发的,长按粘贴)')
                .fontSize(11)
                .fontColor('#9CA3AF')
                .margin({ top: 2 })
              Text('• 选取 JSON 文件(本地保存的 .json)')
                .fontSize(11)
                .fontColor('#9CA3AF')
                .margin({ top: 2 })
              Text('格式参考仓库 docs/bookmarks.example.json')
                .fontSize(11)
                .fontColor('#9CA3AF')
                .margin({ top: 6 })
            }
            .width('100%')
            .padding(14)
            .backgroundColor('#FFFFFF')
            .borderRadius(12)
            .alignItems(HorizontalAlign.Center)
          }
        }
        .width('92%')
      }
      .scrollBar(BarState.Off)
      .layoutWeight(1)
      .padding({ bottom: 16 })
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
  }
}
