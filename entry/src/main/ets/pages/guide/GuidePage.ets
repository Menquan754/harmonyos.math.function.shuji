/**
 * 使用指引：全屏覆盖层，分步介绍四大 Tab 与常用手势。
 * 由 Index 控制显隐（首启自动展示一次 + "?" 按钮 + 设置页入口）。
 */
import { Theme } from '../../core/theme/Theme';
import { Responsive } from '../../core/layout/Responsive';

class GuideStep {
  title: string = '';
  text: string = '';
}

function mkStep(title: string, text: string): GuideStep {
  const s: GuideStep = new GuideStep();
  s.title = title;
  s.text = text;
  return s;
}

const GUIDE_STEPS: GuideStep[] = [
  mkStep('绘图页 · 画函数', '输入表达式（支持 a、b、k 等参数），点"添加"即可绘图。\n· 点示例 / 动态函数可一键载入\n· 单指拖动平移（松手带惯性）、双指缩放\n· 在图上点按任意位置可读坐标值\n· ➕/➖ 缩放、⤒ 自适应纵轴、重置视图'),
  mkStep('绘图页 · 多页与动画', '顶部可保存当前一组函数为绘图页，点 ＋ 新建空白页继续画别的函数，随时切回。\n· "动态"一行是同族函数动画：点击后自动播放参数变化\n· 每个参数滑条旁的 ▶ 可手动启停动画'),
  mkStep('小派 · 离线答疑', '内置大学数学知识库，问概念、问用法、直接算积分都能答。\n· 支持：求根、定/不定积分、变限积分、级数、无穷级数、导数\n· 例："积分 x^2 从 0 到 1"、"不定积分 sin(x)"'),
  mkStep('计算 · 数值工具', '十个工具：求根、定积分（含步骤）、不定积分、变限积分、级数、无穷级数、曲线积分、曲面积分、方向场、导数值。\n· 曲线积分：填 P、Q 与参数曲线 x(t)/y(t)（用 x 表示 t）\n· 曲面积分：填被积函数 g、曲面 z=f(x,y) 与投影区域'),
  mkStep('设置 · 主题与帮助', '深色模式开关即时生效；本页与右下角 "?" 均可随时打开本指引。')
];

@Component
export struct GuidePage {
  @Prop show: boolean = false;
  onClose: () => void = () => {
  };
  @State step: number = 0;

  private close(): void {
    this.onClose();
  }

  private next(): void {
    if (this.step < GUIDE_STEPS.length - 1) {
      this.step = this.step + 1;
    } else {
      this.close();
    }
  }

  private prev(): void {
    if (this.step > 0) {
      this.step = this.step - 1;
    }
  }

  build() {
    Column() {
      // 宽屏（平板 / PC）下限制指引卡片宽度并居中
      Column() {
      // 顶部：标题 + 跳过
      Row() {
        Text('使用指引').fontSize(19).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
        Blank()
        Text('跳过').fontSize(13).fontColor('rgba(255,255,255,0.75)')
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .backgroundColor('rgba(255,255,255,0.15)')
          .borderRadius(14)
          .onClick(() => {
            this.close();
          })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 20 })

      Blank().height(20)

      // 步骤卡片
      Column() {
        if (this.step >= 0 && this.step < GUIDE_STEPS.length) {
          Text(GUIDE_STEPS[this.step].title)
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .width('100%')
          Blank().height(12)
          Text(GUIDE_STEPS[this.step].text)
            .fontSize(14)
            .fontColor('rgba(255,255,255,0.9)')
            .lineHeight(22)
            .width('100%')
            .maxLines(20)
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .padding({ left: 20, right: 20 })

      // 页码指示点
      Row({ space: 8 }) {
        ForEach(GUIDE_STEPS, (s: GuideStep, idx: number) => {
          Shape().width(idx === this.step ? 9 : 7).height(idx === this.step ? 9 : 7)
            .backgroundColor(idx === this.step ? '#FFFFFF' : 'rgba(255,255,255,0.35)')
            .borderRadius(6)
        })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ bottom: 16 })

      // 上一步 / 下一步
      Row({ space: 16 }) {
        if (this.step > 0) {
          Button('上一步')
            .fontSize(15)
            .backgroundColor('rgba(255,255,255,0.15)')
            .onClick(() => {
              this.prev();
            })
        } else {
          Blank()
        }
        Button(this.step < GUIDE_STEPS.length - 1 ? '下一步' : '开始使用')
          .fontSize(15)
          .backgroundColor(Theme.primary())
          .onClick(() => {
            this.next();
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ bottom: 34 })
      }
      .width('100%')
      .constraintSize({ maxWidth: 760 })
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
    .backgroundColor('rgba(10,10,12,0.88)')
  }
}
