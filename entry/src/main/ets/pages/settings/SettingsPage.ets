/**
 * @file SettingsPage.ets
 * @brief Settings for theme, floating help, guide entry and data reset.
 * @author Menquan754
 * @date 2026-10-31
 */
import { AppStore } from '../../core/storage/AppStore';
import { Theme } from '../../core/theme/Theme';
import { Responsive } from '../../core/layout/Responsive';

@Component
export struct SettingsPage {
  @State darkMode: boolean = AppStorage.get<boolean>('darkMode') === true;
  @State showHelp: boolean = true;
  @State doneTip: string = '';
  onShowGuide: () => void = () => {
  };

  private onTheme: (dark: boolean) => void = (dark: boolean): void => {
    this.darkMode = dark;
  };

  /** 主页长按隐藏悬浮按钮时，同步这里的开关状态 */
  private onHelpChange: (v: boolean) => void = (v: boolean): void => {
    this.showHelp = v;
  };

  aboutToAppear(): void {
    Theme.subscribe(this.onTheme);
    AppStore.subscribeHelp(this.onHelpChange);
    this.darkMode = AppStorage.get<boolean>('darkMode') === true;
    this.showHelp = AppStore.getShowHelp();
  }

  aboutToDisappear(): void {
    Theme.unsubscribe(this.onTheme);
    AppStore.unsubscribeHelp(this.onHelpChange);
  }

  private setShowHelp(v: boolean): void {
    this.showHelp = v;
    AppStore.setShowHelp(v);
  }

  private setDark(v: boolean): void {
    this.darkMode = v;
    AppStore.setDarkMode(v);
  }

  build() {
    Scroll() {
      // 宽屏（平板 / PC）下限制阅读宽度并居中，避免内容被拉得过宽
      Column() {
        Column({ space: 12 }) {
      Row() {
        Text('数迹').fontSize(19).fontWeight(FontWeight.Bold).fontColor(Theme.primary())
        Blank()
      }
      .width('100%')
      .padding({ left: 16, top: 14, bottom: 4 })

      Text('面向大学/研究生的离线数学学习工具：函数绘图、参数动画、数值计算与 AI 答疑助手【小派】。')
        .fontSize(13).fontColor(Theme.textSub()).width('100%').padding({ left: 16, right: 16 })

      // 深色模式
      Row({ space: 10 }) {
        Column() {
          Text('深色模式').fontSize(14).fontColor(Theme.textMain())
          Text('开启后全应用（含画布、图表）切换为深色配色，即时生效。')
            .fontSize(12).fontColor(Theme.textDim()).margin({ top: 3 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: this.darkMode })
          .onChange((on: boolean) => {
            this.setDark(on);
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor(Theme.bgSoft())
      .borderRadius(12)

      // 使用指引
      Row({ space: 10 }) {
        Column() {
          Text('使用指引').fontSize(14).fontColor(Theme.textMain())
          Text('分步介绍绘图、动态函数、多页保存、小派问答与计算工具。')
            .fontSize(12).fontColor(Theme.textDim()).margin({ top: 3 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Text('打开 ›').fontSize(14).fontColor(Theme.primary())
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor(Theme.bgSoft())
      .borderRadius(12)
      .onClick(() => {
        this.onShowGuide();
      })

      // 悬浮帮助按钮
      Row({ space: 10 }) {
        Column() {
          Text('悬浮帮助按钮').fontSize(14).fontColor(Theme.textMain())
          Text('开启后主界面显示可拖动的 "?" 按钮；长按该按钮也可隐藏，在此重新开启。')
            .fontSize(12).fontColor(Theme.textDim()).margin({ top: 3 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: this.showHelp })
          .onChange((on: boolean) => {
            this.setShowHelp(on);
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor(Theme.bgSoft())
      .borderRadius(12)

      Row({ space: 10 }) {
        Column() {
          Text('架构与能力').fontSize(14).fontColor(Theme.textMain())
          Text('· 表达式引擎：递归下降解析 + AST 求值（纯 ArkTS）\n· 绘图引擎：Canvas 自绘，多曲线/点选/缩放/惯性平移/动画\n· 数值库：二分求根、辛普森积分（含步骤）、中心差分、RK4 + 方向场、曲线/曲面积分\n· 小派：意图路由 + 内置知识库 + 计算联动\n· 存储：Preferences 本地持久化（含绘图页组）')
            .fontSize(12).fontColor(Theme.textSub()).margin({ top: 3 }).maxLines(30)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .padding(16)
      .backgroundColor(Theme.bgSoft())
      .borderRadius(12)

      Row({ space: 10 }) {
        Column() {
          Text('离线签名与运行').fontSize(14).fontColor(Theme.textMain())
          Text('本应用为单机离线软件，不依赖后端服务；调试安装使用 SDK 自带 OpenHarmony 调试证书完成本地签名。')
            .fontSize(12).fontColor(Theme.textDim()).margin({ top: 3 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .padding(16)
      .backgroundColor(Theme.bgSoft())
      .borderRadius(12)

      Row({ space: 10 }) {
        Column() {
          Text('清空所有数据').fontSize(14).fontColor(Theme.danger())
          Text('删除全部绘图页、重置设置与首次指引标记，恢复出厂默认。')
            .fontSize(12).fontColor(Theme.textDim()).margin({ top: 3 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Text('清空 ›').fontSize(14).fontColor(Theme.danger())
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor(Theme.bgSoft())
      .borderRadius(12)
      .onClick(() => {
        AlertDialog.show({
          title: '清空所有数据',
          message: '将删除全部绘图页与设置，恢复出厂默认。此操作不可撤销，确定继续吗？',
          autoCancel: true,
          alignment: DialogAlignment.Center,
          primaryButton: {
            value: '取消',
            action: () => {
            }
          },
          secondaryButton: {
            value: '清空',
            fontColor: Theme.danger(),
            action: () => {
              AppStore.clearAllData();
              this.darkMode = false;
              this.showHelp = true;
              this.doneTip = '已清空全部数据';
            }
          }
        });
      })

      if (this.doneTip.length > 0) {
        Text(this.doneTip).fontSize(12).fontColor(Theme.primary()).padding({ left: 16 })
      }

      Row() {
        Text('版本 v1.3.0 · HarmonyOS NEXT（Stage 模型 / ArkTS）').fontSize(12).fontColor(Theme.textDim())
        Blank()
      }
      .width('100%')
      .padding({ left: 16, top: 8 })
    }
    .width('100%')
    .constraintSize({ maxWidth: Responsive.MAX_TEXT })
    .alignItems(HorizontalAlign.Start)
    .padding({ bottom: 24 })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      .backgroundColor(Theme.bg())
    }
    .width('100%')
    .height('100%')
    .align(Alignment.Top)
    .backgroundColor(Theme.bg())
    .scrollBar(BarState.Off)
  }
}
