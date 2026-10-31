/**
 * @file AgentPage.ets
 * @brief Xiao Pai chat tab: offline maths Q&A and quick calculations.
 *
 * Responsibilities
 *   - Keeps the message list, input box and quick-question chips, and forwards
 *     every message to `AgentCore.ask()`.
 *   - Shows a short thinking state, renders replies as chat bubbles, and
 *     presents computed results such as integrals, series and derivatives.
 *   - Caps its content with Responsive.MAX_TEXT so long answers stay readable
 *     on tablets and PC.
 *
 * Consumers
 *   - pages/Index.ets as the second tab. The page performs no network I/O.
 *
 * @author Menquan754
 * @date 2026-10-31
 */
import { AgentCore, AgentReply } from '../../core/agent/AgentCore';
import { Theme } from '../../core/theme/Theme';
import { Responsive } from '../../core/layout/Responsive';

class ChatItem {
  who: number = 0; // 0=用户 1=小派
  text: string = '';
  title: string = '';
}

const QUICK_QUESTS: string[] = [
  '你好', '你是谁', '导数的几何意义', '怎么画函数图像', '积分 x^2 从 0 到 1', '不定积分 sin(x)', '无穷级数 1/x^2', '抛硬币'
];

@Component
export struct AgentPage {
  @State darkMode: boolean = AppStorage.get<boolean>('darkMode') === true;
  @State input: string = '';
  @State msgs: ChatItem[] = [];
  @State thinking: boolean = false;

  private onTheme: (dark: boolean) => void = (dark: boolean): void => {
    this.darkMode = dark;
  };

  aboutToAppear(): void {
    Theme.subscribe(this.onTheme);
    this.darkMode = AppStorage.get<boolean>('darkMode') === true;
    const w: ChatItem = new ChatItem();
    w.who = 1;
    w.title = '小派';
    w.text = '你好！我是【小派】，「数迹」的离线数学助手。\n· 讲解大学数学：高数 / 线代 / 概率统计 / 复变 / 数值计算\n· 函数专题：一次 / 二次 / 反比例 / 幂 / 指数 / 对数 / 三角…\n· 指导软件用法，也能直接计算：求根、定积分、不定积分、级数、导数值\n· 还会抛硬币、掷骰子陪你放松一下\n试试下面的快捷提问吧！';
    this.msgs = [w];
  }

  aboutToDisappear(): void {
    Theme.unsubscribe(this.onTheme);
  }
  private scroller: Scroller = new Scroller();

  private push(who: number, title: string, text: string): void {
    const m: ChatItem = new ChatItem();
    m.who = who;
    m.title = title;
    m.text = text;
    this.msgs = this.msgs.concat(m);
    setTimeout(() => {
      this.scroller.scrollEdge(Edge.Bottom);
    }, 50);
  }

  private send(text: string): void {
    const t: string = text.trim();
    if (t.length === 0 || this.thinking) {
      return;
    }
    this.push(0, '我', t);
    this.input = '';
    this.thinking = true;
    setTimeout(() => {
      let reply: AgentReply;
      try {
        reply = AgentCore.ask(t);
      } catch (e) {
        reply = new AgentReply();
        reply.title = '小派';
        reply.text = '出错了，请换个问法试试。';
      }
      this.push(1, reply.title, reply.text);
      this.thinking = false;
    }, 120);
  }

  build() {
    Column() {
      // 宽屏（平板 / PC）下限制对话区宽度并居中
      Column() {
      Row() {
        Text('小派').fontSize(17).fontWeight(FontWeight.Bold).fontColor(Theme.primary())
        Text('· 离线数学助手').fontSize(12).fontColor(Theme.textDim()).margin({ left: 6 })
        Blank()
        Text('清空').fontSize(13).fontColor(Theme.textDim())
          .onClick(() => {
            const w: ChatItem = new ChatItem();
            w.who = 1;
            w.title = '小派';
            w.text = '会话已清空，随时问我数学问题~';
            this.msgs = [w];
          })
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 10, bottom: 8 })

      // 快捷提问
      Scroll(this.scroller) {
        Row({ space: 8 }) {
          ForEach(QUICK_QUESTS, (q: string) => {
            Text(q)
              .fontSize(12)
              .fontColor(Theme.accentBlue())
              .padding({ left: 10, right: 10, top: 4, bottom: 4 })
              .backgroundColor(Theme.linkBg())
              .borderRadius(14)
              .onClick(() => {
                this.send(q);
              })
          })
        }
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
      .padding({ left: 12 })

      // 消息列表
      List({ space: 10 }) {
        ForEach(this.msgs, (m: ChatItem) => {
          ListItem() {
            Row() {
              if (m.who === 1) {
                Text('派')
                  .fontSize(14)
                  .fontColor('#FFFFFF')
                  .textAlign(TextAlign.Center)
                  .width(34)
                  .height(34)
                  .borderRadius(17)
                  .backgroundColor(Theme.primary())
                  .margin({ right: 8, top: 2 })
                Column() {
                  if (m.title.length > 0) {
                    Text(m.title).fontSize(11).fontColor(Theme.textDim()).margin({ bottom: 2 })
                  }
                  Text(m.text)
                    .fontSize(14)
                    .fontColor(Theme.textMain())
                    .padding({ left: 12, right: 12, top: 8, bottom: 8 })
                    .backgroundColor(Theme.bgSoft())
                    .borderRadius(12)
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
              } else {
                Blank().layoutWeight(1)
                Text(m.text)
                  .fontSize(14)
                  .fontColor('#FFFFFF')
                  .padding({ left: 12, right: 12, top: 8, bottom: 8 })
                  .backgroundColor(Theme.accentBlue())
                  .borderRadius(12)
                  .maxLines(200)
              }
            }
            .width('100%')
            .alignItems(VerticalAlign.Top)
            .padding({ left: 12, right: 12 })
          }
        })
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)

      if (this.thinking) {
        Row() {
          Text('小派思考中…').fontSize(12).fontColor(Theme.textDim())
          Blank()
        }
        .width('100%')
        .padding({ left: 16, bottom: 4 })
      }

      // 输入区
      Row({ space: 8 }) {
        TextInput({ text: this.input, placeholder: '问小派数学问题…' })
          .layoutWeight(1)
          .backgroundColor(Theme.inputBg())
          .fontColor(Theme.textMain())
          .onChange((v: string) => {
            this.input = v;
          })
          .onSubmit(() => {
            this.send(this.input);
          })
        Button('发送')
          .fontSize(14)
          .backgroundColor(Theme.primary())
          .onClick(() => {
            this.send(this.input);
          })
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 8, bottom: 12 })
      }
      .width('100%')
      .constraintSize({ maxWidth: Responsive.MAX_TEXT })
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(Theme.bg())
  }
}