/**
 * 应用主框架：底部 Tabs —— 绘图 / 小派 / 计算 / 设置
 * 全屏使用指引覆盖层（首启自动展示一次 + 可拖动/可隐藏的悬浮 "?" + 设置页入口）
 */
import { PlotPage } from './plot/PlotPage';
import { AgentPage } from './agent/AgentPage';
import { CalcPage } from './calc/CalcPage';
import { SettingsPage } from './settings/SettingsPage';
import { GuidePage } from './guide/GuidePage';
import { AppStore } from '../core/storage/AppStore';
import { Theme } from '../core/theme/Theme';
import { Responsive } from '../core/layout/Responsive';
import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';

@Entry
@Component
struct Index {
  @State showGuide: boolean = false;
  @State darkMode: boolean = AppStorage.get<boolean>('darkMode') === true;
  @State curTab: number = 0;
  @State showHelp: boolean = true;
  @State helpX: number = 0;
  @State helpY: number = 0;
  @State areaW: number = 0;
  @State areaH: number = 0;

  private dragStartX: number = 0;
  private dragStartY: number = 0;
  private helpStartX: number = 0;
  private helpStartY: number = 0;
  private moved: number = 0;
  private helpHideTimer: number = -1;
  private helpLongFired: boolean = false;
  private mainWin: window.Window | null = null;

  private onTheme: (dark: boolean) => void = (dark: boolean): void => {
    this.darkMode = dark;
  };

  /** 窗口尺寸变化（平板旋转 / PC 拖拽窗口）：更新断点，切换导航形态 */
  private onWinSize: (size: window.Size) => void = (size: window.Size): void => {
    const w: number = this.getUIContext().px2vp(size.width);
    const h: number = this.getUIContext().px2vp(size.height);
    if (w > 0) {
      this.areaW = w;
    }
    if (h > 0) {
      this.areaH = h;
    }
    this.clampHelp();
  };

  /** 兼容 onAreaChange 的 Length 字符串（如 "394.00vp"） */
  private applyArea(w: Length, h: Length): void {
    const wv: number = parseFloat(String(w));
    const hv: number = parseFloat(String(h));
    if (Number.isFinite(wv) && wv > 0) {
      this.areaW = wv;
    }
    if (Number.isFinite(hv) && hv > 0) {
      this.areaH = hv;
    }
    this.clampHelp();
  }

  private async initWindowSize(): Promise<void> {
    try {
      const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const win = await window.getLastWindow(ctx);
      this.mainWin = win;
      const rect = win.getWindowProperties().windowRect;
      const w: number = this.getUIContext().px2vp(rect.width);
      const h: number = this.getUIContext().px2vp(rect.height);
      if (w > 0) {
        this.areaW = w;
      }
      if (h > 0) {
        this.areaH = h;
      }
      this.clampHelp();
      win.on('windowSizeChange', this.onWinSize);
    } catch (e) {
      console.error(`window size listen failed: ${JSON.stringify(e)}`);
    }
  }

  /** 设置页恢复悬浮按钮时，主页立即显示 */
  private onHelpChange: (show: boolean) => void = (show: boolean): void => {
    this.showHelp = show;
    if (show) {
      this.helpX = AppStore.getHelpX();
      this.helpY = AppStore.getHelpY();
      this.clampHelp();
    }
  };

  aboutToAppear(): void {
    Theme.subscribe(this.onTheme);
    AppStore.subscribeHelp(this.onHelpChange);
    const ctx: common.UIAbilityContext | undefined = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (ctx) {
      AppStore.init(ctx);
    }
    AppStorage.setOrCreate<boolean>('darkMode', AppStore.getDarkMode());
    this.darkMode = AppStore.getDarkMode();
    AppStore.applyColorMode();
    this.showHelp = AppStore.getShowHelp();
    this.helpX = AppStore.getHelpX();
    this.helpY = AppStore.getHelpY();
    if (AppStore.getFirstLaunch()) {
      this.showGuide = true;
      AppStore.setGuided();
    }
    this.initWindowSize();
  }

  aboutToDisappear(): void {
    Theme.unsubscribe(this.onTheme);
    AppStore.unsubscribeHelp(this.onHelpChange);
    this.clearHelpTimer();
    if (this.mainWin !== null) {
      this.mainWin.off('windowSizeChange', this.onWinSize);
      this.mainWin = null;
    }
  }

  private clampHelp(): void {
    if (this.areaW <= 0 || this.areaH <= 0) {
      return;
    }
    if (this.helpX < 0) {
      this.helpX = this.areaW - 56;
    }
    if (this.helpY < 0) {
      // 默认放在右侧中部，避开底部输入框 / 列表操作按钮
      this.helpY = this.areaH * 0.46;
    }
    const maxX: number = this.areaW - 46;
    const maxY: number = this.areaH - 46;
    this.helpX = Math.max(6, Math.min(maxX, this.helpX));
    this.helpY = Math.max(6, Math.min(maxY, this.helpY));
  }

  private hideHelp(): void {
    this.clearHelpTimer();
    this.showHelp = false;
    AppStore.setShowHelp(false);
    this.getUIContext().getPromptAction().showToast({ message: '悬浮按钮已隐藏，可在设置中恢复' });
  }

  private clearHelpTimer(): void {
    if (this.helpHideTimer !== -1) {
      clearTimeout(this.helpHideTimer);
      this.helpHideTimer = -1;
    }
  }

  @Builder
  tabBuilder(title: string, index: number, desc: string) {
    Column({ space: 2 }) {
      Text(title)
        .fontSize(desc.length > 0 ? 15 : 13)
        .fontWeight(this.curTab === index ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.curTab === index ? Theme.primary() : Theme.textDim())
      if (desc.length > 0) {
        Text(desc)
          .fontSize(10)
          .fontColor(this.curTab === index ? Theme.primary() : Theme.textDim())
          .opacity(0.8)
      }
    }
    .width('100%')
    .height(desc.length > 0 ? 64 : 56)
    .alignItems(desc.length > 0 ? HorizontalAlign.Start : HorizontalAlign.Center)
    .justifyContent(FlexAlign.Center)
    .padding({ left: desc.length > 0 ? 18 : 0, right: desc.length > 0 ? 8 : 0 })
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // PC：宽侧栏导航；平板：窄侧栏导航；手机：底部导航
      if (this.areaW >= Responsive.PC_MIN) {
        Tabs({ barPosition: BarPosition.Start, index: this.curTab }) {
          TabContent() {
            PlotPage()
          }
          .tabBar(this.tabBuilder('绘图', 0, '函数图像'))

          TabContent() {
            AgentPage()
          }
          .tabBar(this.tabBuilder('小派', 1, '离线知识问答'))

          TabContent() {
            CalcPage()
          }
          .tabBar(this.tabBuilder('计算', 2, '数值计算工具'))

          TabContent() {
            SettingsPage({ onShowGuide: (): void => {
              this.showGuide = true;
            } })
          }
          .tabBar(this.tabBuilder('设置', 3, '偏好与数据'))
        }
        .vertical(true)
        .barWidth(200)
        .scrollable(false)
        .barMode(BarMode.Scrollable)
        .width('100%')
        .height('100%')
        .barBackgroundColor(Theme.tabBarBg())
        .onChange((index: number) => {
          this.curTab = index;
        })
      } else if (this.areaW >= Responsive.PHONE_MAX) {
        Tabs({ barPosition: BarPosition.Start, index: this.curTab }) {
          TabContent() {
            PlotPage()
          }
          .tabBar(this.tabBuilder('绘图', 0, ''))

          TabContent() {
            AgentPage()
          }
          .tabBar(this.tabBuilder('小派', 1, ''))

          TabContent() {
            CalcPage()
          }
          .tabBar(this.tabBuilder('计算', 2, ''))

          TabContent() {
            SettingsPage({ onShowGuide: (): void => {
              this.showGuide = true;
            } })
          }
          .tabBar(this.tabBuilder('设置', 3, ''))
        }
        .vertical(true)
        .barWidth(96)
        .scrollable(false)
        .barMode(BarMode.Scrollable)
        .width('100%')
        .height('100%')
        .barBackgroundColor(Theme.tabBarBg())
        .onChange((index: number) => {
          this.curTab = index;
        })
      } else {
        Tabs({ barPosition: BarPosition.End, index: this.curTab }) {
          TabContent() {
            PlotPage()
          }
          .tabBar(this.tabBuilder('绘图', 0, ''))

          TabContent() {
            AgentPage()
          }
          .tabBar(this.tabBuilder('小派', 1, ''))

          TabContent() {
            CalcPage()
          }
          .tabBar(this.tabBuilder('计算', 2, ''))

          TabContent() {
            SettingsPage({ onShowGuide: (): void => {
              this.showGuide = true;
            } })
          }
          .tabBar(this.tabBuilder('设置', 3, ''))
        }
        .scrollable(false)
        .barMode(BarMode.Fixed)
        .barHeight(56)
        .width('100%')
        .height('100%')
        .barBackgroundColor(Theme.tabBarBg())
        .onChange((index: number) => {
          this.curTab = index;
        })
      }

      // 悬浮 "?" 帮助按钮：可拖动、长按隐藏
      if (this.showHelp) {
        Text('?')
          .fontSize(18)
          .fontColor('#FFFFFF')
          .textAlign(TextAlign.Center)
          .width(42)
          .height(42)
          .borderRadius(21)
          .backgroundColor(Theme.primary())
          .opacity(0.9)
          .shadow({ radius: 8, color: 'rgba(0,0,0,0.25)', offsetX: 0, offsetY: 2 })
          .position({ x: this.helpX, y: this.helpY })
          .onTouch((ev: TouchEvent) => {
            if (ev.touches.length < 1) {
              return;
            }
            const t: TouchObject = ev.touches[0];
            if (ev.type === TouchType.Down) {
              this.dragStartX = t.windowX;
              this.dragStartY = t.windowY;
              this.helpStartX = this.helpX;
              this.helpStartY = this.helpY;
              this.moved = 0;
              this.helpLongFired = false;
              this.clearHelpTimer();
              // 用定时器判定长按：按住 750ms 且未明显移动即隐藏
              this.helpHideTimer = setTimeout(() => {
                this.helpHideTimer = -1;
                if (!this.helpLongFired && this.moved < 12) {
                  this.helpLongFired = true;
                  this.hideHelp();
                }
              }, 750);
            } else if (ev.type === TouchType.Move) {
              const dx: number = t.windowX - this.dragStartX;
              const dy: number = t.windowY - this.dragStartY;
              // 取相对起点的净位移，避免手指抖动被累加成拖动
              this.moved = Math.abs(dx) + Math.abs(dy);
              this.helpX = this.helpStartX + dx;
              this.helpY = this.helpStartY + dy;
              this.clampHelp();
              if (this.moved >= 12) {
                this.clearHelpTimer();
              }
            } else if (ev.type === TouchType.Up) {
              this.clearHelpTimer();
              if (this.helpLongFired) {
                this.helpLongFired = false;
                return;
              }
              if (this.moved >= 12) {
                // 仅拖动后记录位置，点按不改动默认位置
                AppStore.setHelpPos(this.helpX, this.helpY);
              } else {
                this.showGuide = true;
              }
            } else if (ev.type === TouchType.Cancel) {
              this.clearHelpTimer();
              this.helpLongFired = false;
            }
          })
      }

      if (this.showGuide) {
        GuidePage({ show: true, onClose: (): void => {
          this.showGuide = false;
        } })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.bg())
    .onAreaChange((oldV: Area, newV: Area) => {
      this.applyArea(newV.width, newV.height);
    })
  }
}
