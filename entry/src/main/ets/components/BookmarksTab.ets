// 浏览器 Tab：测试用网址书签 grid。点击后跳到 Browser 页加载该 URL。

import { showToast } from './Common';

interface Bookmark {
  name: string
  url: string
  // 单字符/emoji 当 favicon 占位
  badge: string
  // 角标背景色
  bg: string
}

// 默认书签列表。后续要加私有内网站点，直接在这里加一项即可。
const DEFAULT_BOOKMARKS: Bookmark[] = [
  { name: '我的 IP', url: 'https://ip.sb', badge: 'IP', bg: '#3B82F6' },
  { name: 'IP 信息', url: 'https://ipinfo.io', badge: 'I', bg: '#0EA5E9' },
  { name: 'IP 检测', url: 'https://www.whatismyip.com', badge: 'W', bg: '#6366F1' },
  { name: 'DNS 检测', url: 'https://www.dnsleaktest.com', badge: 'D', bg: '#8B5CF6' },
  { name: '网速测试', url: 'https://fast.com', badge: 'F', bg: '#EF4444' },
  { name: 'Google', url: 'https://www.google.com', badge: 'G', bg: '#22C55E' },
  { name: 'YouTube', url: 'https://www.youtube.com', badge: 'Y', bg: '#DC2626' },
  { name: 'GitHub', url: 'https://github.com', badge: 'GH', bg: '#1F2937' },
  { name: 'Twitter/X', url: 'https://twitter.com', badge: 'X', bg: '#000000' },
  { name: 'Reddit', url: 'https://www.reddit.com', badge: 'R', bg: '#F97316' },
  { name: 'Wikipedia', url: 'https://www.wikipedia.org', badge: 'W', bg: '#6B7280' },
  { name: 'StackOverflow', url: 'https://stackoverflow.com', badge: 'SO', bg: '#F59E0B' },
]

@Component
export struct BookmarksTab {
  private bookmarks: Bookmark[] = DEFAULT_BOOKMARKS

  open(url: string) {
    try {
      this.getUIContext().getRouter().pushUrl({ url: 'pages/Browser', params: { url } })
    } catch (e) {
      showToast(this.getUIContext(), `打开失败: ${JSON.stringify(e)}`, 2400)
    }
  }

  build() {
    Column() {
      Row() {
        Text('快捷书签')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#374151')
        Blank()
        Text(`${this.bookmarks.length}`)
          .fontSize(11)
          .fontColor('#6B7280')
          .backgroundColor('#FFFFFF')
          .borderRadius(10)
          .padding({ left: 10, right: 10, top: 2, bottom: 2 })
      }
      .width('92%')
      .padding({ top: 14, bottom: 10 })

      Scroll() {
        Column() {
          // 自适应 grid:窄屏 3 列,宽屏(平板/横屏) 4 列
          Grid() {
            ForEach(this.bookmarks, (bm: Bookmark) => {
              GridItem() {
                Column() {
                  // 角标头像
                  Stack() {
                    Circle({ width: 56, height: 56 })
                      .fill(bm.bg)
                    Text(bm.badge)
                      .fontSize(bm.badge.length > 1 ? 18 : 22)
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
                  Text(bm.url.replace(/^https?:\/\//, '').replace(/\/.*$/, ''))
                    .fontSize(10)
                    .fontColor('#9CA3AF')
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .margin({ top: 2 })
                }
                .width('100%')
                .padding({ top: 16, bottom: 16 })
                .backgroundColor('#FFFFFF')
                .borderRadius(14)
                .onClick(() => this.open(bm.url))
              }
            })
          }
          .columnsTemplate('1fr 1fr 1fr 1fr')
          .columnsGap(10)
          .rowsGap(10)
          .width('100%')
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
