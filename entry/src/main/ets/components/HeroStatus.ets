// 顶部连接状态 Hero 卡：大圆形指示器 + 状态文字 + 已连接配置名 + 实时运行时长
// 数据源全部来自 AppStorage，由 Index 页面的事件订阅写入；与 VpnItem 共享同一个状态。

@Component
export struct HeroStatus {
  @StorageLink('vpn.activeName') activeName: string = ''
  @StorageLink('vpn.connectedAt') connectedAt: number = 0
  @StorageLink('vpn.busyName') busyName: string = ''
  @State now: number = Date.now()
  private timer: number = -1

  aboutToAppear() {
    this.timer = setInterval(() => { this.now = Date.now() }, 1000) as number
  }

  aboutToDisappear() {
    if (this.timer !== -1) {
      clearInterval(this.timer)
      this.timer = -1
    }
  }

  isConnected(): boolean { return !!this.activeName && !this.busyName }
  isConnecting(): boolean { return !!this.busyName && !this.activeName }
  isDisconnecting(): boolean { return !!this.busyName && !!this.activeName }

  formatDuration(ms: number): string {
    if (ms <= 0) return '00:00'
    const s = Math.floor(ms / 1000)
    const h = Math.floor(s / 3600)
    const m = Math.floor((s % 3600) / 60)
    const sec = s % 60
    const pad: (n: number) => string = (n) => n.toString().padStart(2, '0')
    return h > 0 ? `${pad(h)}:${pad(m)}:${pad(sec)}` : `${pad(m)}:${pad(sec)}`
  }

  statusTitle(): string {
    if (this.isConnecting()) return '正在连接'
    if (this.isDisconnecting()) return '正在断开'
    if (this.isConnected()) return '已连接'
    return '未连接'
  }

  centerLabel(): string {
    if (this.isConnecting() || this.isDisconnecting()) return '···'
    return this.isConnected() ? 'ON' : 'OFF'
  }

  ringColor(): string {
    if (this.isConnecting() || this.isDisconnecting()) return '#3B82F6'
    return this.isConnected() ? '#22C55E' : '#CBD5E1'
  }

  haloColor(): string {
    if (this.isConnecting() || this.isDisconnecting()) return '#BFDBFE'
    return this.isConnected() ? '#86EFAC' : '#E5E7EB'
  }

  titleColor(): string {
    if (this.isConnecting() || this.isDisconnecting()) return '#1D4ED8'
    return this.isConnected() ? '#15803D' : '#1F2937'
  }

  build() {
    Column() {
      // 圆形状态指示器
      Stack() {
        // 外层光晕
        Circle({ width: 132, height: 132 })
          .fill(this.haloColor())
          .opacity(0.35)
        // 中间填充圆
        Circle({ width: 100, height: 100 })
          .fill(this.ringColor())
          .shadow({ radius: 22, color: this.ringColor() + '66', offsetY: 6 })
        // 中心文字
        Text(this.centerLabel())
          .fontSize(this.isConnecting() || this.isDisconnecting() ? 36 : 30)
          .fontColor(Color.White)
          .fontWeight(FontWeight.Bold)
          .letterSpacing(1)
      }
      .width(132)
      .height(132)

      // 主标题
      Text(this.statusTitle())
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.titleColor())
        .margin({ top: 18 })

      // 副标题：根据状态切换
      if (this.isConnected()) {
        Row() {
          Text(this.activeName)
            .fontSize(13)
            .fontColor('#16A34A')
            .fontWeight(FontWeight.Medium)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .padding({ left: 12, right: 12, top: 4, bottom: 4 })
        .backgroundColor('#DCFCE7')
        .borderRadius(20)
        .margin({ top: 8 })

        Text(this.formatDuration(this.now - this.connectedAt))
          .fontSize(15)
          .fontFamily('monospace')
          .fontColor('#374151')
          .fontWeight(FontWeight.Medium)
          .margin({ top: 8 })
      } else if (this.isConnecting() || this.isDisconnecting()) {
        Text(this.busyName)
          .fontSize(13)
          .fontColor('#3B82F6')
          .fontWeight(FontWeight.Medium)
          .margin({ top: 6 })
      } else {
        Text('选择下方配置开启')
          .fontSize(13)
          .fontColor('#9CA3AF')
          .margin({ top: 6 })
      }
    }
    .width('92%')
    .padding({ top: 26, bottom: 24 })
    .margin({ top: 6, bottom: 14 })
    .backgroundColor(Color.White)
    .borderRadius(22)
    .shadow({ radius: 18, color: '#10000000', offsetY: 6 })
  }
}
