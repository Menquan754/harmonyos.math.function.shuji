/**
 * @file AgentCore.ets
 * @brief Offline intent router, knowledge search and calculator bridge for Xiao Pai.
 * @author Menquan754
 * @date 2026-10-31
 */
import { ExprEngine, ParseError } from '../expression/ExprEngine';
import { NumericKit, IndefResult, SeriesResult } from '../numeric/NumericKit';
import { KnowledgeBase, KbEntry } from './KnowledgeBase';

export enum AgentIntent {
  GREET = 'greet',
  CALC_ROOT = 'calc_root',
  CALC_INTEGRAL = 'calc_integral',
  CALC_INDEF = 'calc_indef',
  CALC_SERIES = 'calc_series',
  CALC_DERIV = 'calc_deriv',
  FEATURE = 'feature',
  KB_MATH = 'kb_math',
  KB_USAGE = 'kb_usage',
  OTHER = 'other'
}

export class AgentReply {
  intent: AgentIntent = AgentIntent.OTHER;
  title: string = '';
  text: string = '';
}

export class AgentCore {
  private static fmt(v: number): string {
    if (!Number.isFinite(v)) {
      return '无定义';
    }
    const a: number = Math.abs(v);
    if (a !== 0 && (a >= 1e6 || a < 1e-4)) {
      return v.toExponential(4);
    }
    return Math.round(v * 100000) / 100000 + '';
  }

  private static extractExprFrom(input: string, prefixes: string[]): string {
    let rest: string = input;
    for (let i: number = 0; i < prefixes.length; i++) {
      const idx: number = rest.indexOf(prefixes[i]);
      if (idx >= 0) {
        rest = rest.substring(idx + prefixes[i].length);
      }
    }
    return rest.replace(/\s+/g, '');
  }

  private static findBound(s: string, word: string, allowSign: boolean): number | undefined {
    const idx: number = s.indexOf(word);
    if (idx < 0) {
      return undefined;
    }
    const tail: string = s.substring(idx + word.length);
    const m: RegExpMatchArray | null = tail.match(/(-?|\+?)(\d+(\.\d+)?)/);
    if (m != null) {
      return parseFloat(m[0]);
    }
    return undefined;
  }

  /** 计算联动：求根 / 定积分 / 不定积分 / 级数 / 导数值 */
  private static tryCalc(input: string): AgentReply | null {
    const low: string = input.toLowerCase();
    const EMPTY_PARAMS: Map<string, number> = new Map<string, number>();

    // 不定积分：匹配内置原函数表
    if (low.indexOf('不定积分') >= 0 || low.indexOf('原函数') >= 0) {
      const fExpr: string = AgentCore.extractExprFrom(input, ['不定积分', '原函数', '计算', '求', '∫']);
      if (fExpr.length > 0 && fExpr.indexOf('从') < 0) {
        const r: IndefResult = NumericKit.indefIntegral(fExpr);
        if (r.matched) {
          let txt: string = `∫ ${fExpr} dx = ${r.formula}\n`;
          if (r.verifyOk) {
            txt += `数值抽查 ✓：x=${AgentCore.fmt(r.samplePoint)} 处 F\'≈f` +
              `（F\'=${AgentCore.fmt(r.sampleFp)}，f=${AgentCore.fmt(r.sampleF)}）`;
          }
          return { intent: AgentIntent.CALC_INDEF, title: '不定积分', text: txt };
        }
        return {
          intent: AgentIntent.CALC_INDEF,
          title: '不定积分',
          text: `内置原函数表暂未收录 ∫ ${fExpr} dx。\n支持：x^n、sin(x)、cos(x)、e^x、1/x、ln(x)、sqrt(x)、1/(1+x^2)、1/cos(x)^2 等。\n可在"计算 → 变限积分"绘制原函数数值图像。`
        };
      }
    }

    // 级数 / 无穷级数
    if (low.indexOf('无穷级数') >= 0 || low.indexOf('级数') >= 0) {
      const fExpr: string = AgentCore.extractExprFrom(input, ['无穷级数', '级数', '的', '求和', 'Σ', '从', '到', '计算', '求']);
      if (fExpr.length > 0 && fExpr !== '付' && fExpr !== '数') {
        try {
          const ast: Object = ExprEngine.parseWithParams(fExpr).ast;
          const term = (v: number): number => {
            const pm: Map<string, number> = new Map<string, number>();
            pm.set('n', v);
            pm.set('i', v);
            return ExprEngine.evaluate(ast, v, pm);
          };
          const r: SeriesResult = NumericKit.infiniteSeries(term, 1, 300);
          const j: string = r.converged ? '收敛（数值估计）' : '发散 / 未收敛';
          let txt: string = `无穷级数 Σ [${fExpr}]（1 ≤ n ≤ ${r.tailN}）：\nS ≈ ${AgentCore.fmt(r.sum)}\n判定：${j}。${r.judgment}\n`;
          txt += '前几步部分和：';
          for (let k: number = 0; k < r.partials.length; k++) {
            txt += `S_${1 + k}=${AgentCore.fmt(r.partials[k])}  `;
          }
          return { intent: AgentIntent.CALC_SERIES, title: '无穷级数', text: txt };
        } catch (e) {
          return null;
        }
      }
    }

    if (low.indexOf('求根') >= 0 || low.indexOf('零点') >= 0 || low.indexOf('解方程') >= 0) {
      let eq: string = AgentCore.extractExprFrom(input, ['求根', '零点', '解方程', '的', '：', ':']);
      if (eq.indexOf('=') >= 0) {
        const parts: string[] = eq.split('=');
        const left: string = parts[0];
        const right: string = parts.length > 1 ? parts[1] : '0';
        const full: string = `(${left})-(${right})`;
        try {
          const ast: Object = ExprEngine.parseWithParams(full).ast;
          const f = (x: number): number => ExprEngine.evaluate(ast, x, EMPTY_PARAMS);
          const roots: number[] = NumericKit.findRoots(f, -10, 10);
          if (roots.length === 0) {
            return {
              intent: AgentIntent.CALC_ROOT,
              title: '求根计算',
              text: `方程 ${left}=${right} 在 [-10,10] 内未扫描到实根。可尝试增大区间或检查表达式。`
            };
          }
          let lines: string = `方程 ${left}=${right} 的实根（取 5 位）：\n`;
          const shown: number[] = [];
          for (let i: number = 0; i < roots.length; i++) {
            const r: number = roots[i];
            let dup: boolean = false;
            for (let j: number = 0; j < shown.length; j++) {
              if (Math.abs(r - shown[j]) < 1e-4) {
                dup = true;
                break;
              }
            }
            if (!dup) {
              shown.push(r);
              lines += `x = ${AgentCore.fmt(r)}\n`;
            }
          }
          return { intent: AgentIntent.CALC_ROOT, title: '求根计算', text: lines + '（算法：区间扫描 + 二分法）' };
        } catch (e) {
          return null;
        }
      }
      return null;
    }

    if (low.indexOf('积分') >= 0 && low.indexOf('从') >= 0 && low.indexOf('到') >= 0) {
      const a: number | undefined = AgentCore.findBound(input, '从', false);
      const b: number | undefined = AgentCore.findBound(input, '到', false);
      const fExpr: string = AgentCore.extractExprFrom(input, ['积分', '∫', '计算', '求']);
      if (a !== undefined && b !== undefined && fExpr.length > 0) {
        try {
          const ast: Object = ExprEngine.parseWithParams(fExpr).ast;
          const f = (x: number): number => ExprEngine.evaluate(ast, x, EMPTY_PARAMS);
          const val: number = NumericKit.simpson(f, a, b);
          return {
            intent: AgentIntent.CALC_INTEGRAL,
            title: '定积分计算',
            text: `∫ ${fExpr} dx，从 ${AgentCore.fmt(a)} 到 ${AgentCore.fmt(b)}\n= ${AgentCore.fmt(val)}（辛普森公式）`
          };
        } catch (e) {
          return null;
        }
      }
    }

    if ((low.indexOf('导数') >= 0 || low.indexOf('求导') >= 0) && low.indexOf('在') >= 0) {
      const x: number | undefined = AgentCore.findBound(input, '在', true);
      const fExpr: string = AgentCore.extractExprFrom(input, ['导数', '求导', '的', '：', ':']);
      if (x !== undefined && fExpr.length > 0) {
        try {
          const ast: Object = ExprEngine.parseWithParams(fExpr).ast;
          const f = (x0: number): number => ExprEngine.evaluate(ast, x0, EMPTY_PARAMS);
          const d: number = NumericKit.deriv(f, x);
          const y: number = f(x);
          return {
            intent: AgentIntent.CALC_DERIV,
            title: '导数值计算',
            text: `f(x)=${fExpr}，在 x=${AgentCore.fmt(x)}\nf(x) = ${AgentCore.fmt(y)}，f\'(x) ≈ ${AgentCore.fmt(d)}`
          };
        } catch (e) {
          return null;
        }
      }
    }
    return null;
  }

  /** 分类 + 生成回答 */
  static ask(userInput: string): AgentReply {
    const input: string = userInput.trim();
    const low: string = input.toLowerCase();

    if (input.length === 0) {
      return { intent: AgentIntent.OTHER, title: '小派', text: '请问你想了解什么？例如：\n· "极限是什么意思"\n· "求根 x^2-2=0"\n· "积分 x^2 从 0 到 1"\n· "不定积分 sin(x)"\n· "无穷级数 1/x^2"\n· "怎么画函数图像"' };
    }

    if (low.indexOf('你好') >= 0 || low === 'hi' || low === 'hello' || low === '嗨' || low.indexOf('哈喽') >= 0 || low.indexOf('早上好') >= 0 || low.indexOf('下午好') >= 0 || low.indexOf('晚上好') >= 0) {
      return {
        intent: AgentIntent.GREET,
        title: '小派',
        text: '你好呀！我是【小派】，「数迹」的离线助手。\n我可以讲解大学数学（高数/线代/概率统计/复变/数值计算）与函数专题（一次/二次/反比例/幂/指数/对数/三角…）概念、指导软件用法，还能直接帮你算：求根、定积分、不定积分、无穷级数、导数值。\n想了解我，可以问"你是谁"；想试试小互动，可以让我"抛硬币"或"掷骰子"哦~'
      };
    }

    // ---------- 自我介绍 ----------
    if (low.indexOf('你是谁') >= 0 || low.indexOf('自我介绍') >= 0 || low.indexOf('介绍你') >= 0 || low.indexOf('介绍下你') >= 0 || low.indexOf('名字') >= 0 || low.indexOf('你叫什么') >= 0) {
      return {
        intent: AgentIntent.GREET,
        title: '小派',
        text: '我是【小派】——「数迹」内置的离线智能助手。\n我的特长：\n· 函数专题：一次/二次/反比例/幂/指数/对数/三角/反三角/双曲等函数概念与图像；\n· 大学数学：高数、线代、概率统计、复变函数、数值计算；\n· 软件指导：绘图、动画、多页保存、导出、计算工具用法；\n· 直接计算：求根、定积分、不定积分、级数、导数值。\n我完全离线运行，不联网也能陪你学数学。'
      };
    }

    // ---------- 道谢 ----------
    if (low.indexOf('谢谢') >= 0 || low.indexOf('感谢') >= 0 || low.indexOf('多谢') >= 0 || low.indexOf('辛苦了') >= 0) {
      return {
        intent: AgentIntent.GREET,
        title: '小派',
        text: '不客气~ 能帮到你我很开心！\n有任何数学问题或者想了解软件功能，随时问我。也可以试试对我说"抛硬币"或"掷骰子"，我陪你玩一个小互动。'
      };
    }

    // ---------- 告别 ----------
    if (low.indexOf('再见') >= 0 || low.indexOf('拜拜') >= 0 || low === 'bye' || low === 'bye!' || low.indexOf('晚安') >= 0) {
      return {
        intent: AgentIntent.GREET,
        title: '小派',
        text: '再见啦~ 记得多来画几组函数图像，温故而知新！\n（提示：绘图页输入表达式就能立刻看到曲线；想复习概念随时来问我。）'
      };
    }

    // ---------- 小互动：抛硬币 / 掷骰子 / 随机数 ----------
    if (low.indexOf('抛硬币') >= 0 || low.indexOf('猜正反') >= 0) {
      const coin: string = Math.random() < 0.5 ? '正面' : '反面';
      return {
        intent: AgentIntent.GREET,
        title: '抛硬币',
        text: `铛！硬币落地：${coin}！\n要再抛一次就对我说"抛硬币"，我也可以"掷骰子"或生成"随机数"~`
      };
    }
    if (low.indexOf('骰子') >= 0 || low.indexOf('摇色子') >= 0 || low.indexOf('掷骰') >= 0) {
      const d: number = Math.floor(Math.random() * 6) + 1;
      return {
        intent: AgentIntent.GREET,
        title: '掷骰子',
        text: `🎲 骰子转动…点数是 ${d}！\n还想玩的话可以继续对我说"掷骰子"，或试试"抛硬币"。`
      };
    }
    if (low.indexOf('随机数') >= 0 || low.indexOf('随机一个数') >= 0 || low.indexOf('猜个数') >= 0) {
      const n: number = Math.floor(Math.random() * 100) + 1;
      return {
        intent: AgentIntent.GREET,
        title: '随机数',
        text: `我随机想了一个 1~100 之间的整数：${n}！\n这是纯离线生成的，绝对公平（也不绝对😄）。`
      };
    }

    // ---------- 能力清单 ----------
    if (low.indexOf('能做什么') >= 0 || low.indexOf('会什么') >= 0 || low.indexOf('能干什么') >= 0 || low.indexOf('你能做') >= 0) {
      return {
        intent: AgentIntent.GREET,
        title: '小派的能力',
        text: '我能为你做的：\n1) 讲数学：函数专题 + 高数/线代/概率统计/复变/数值计算（120+ 条知识），也认识英文术语；\n2) 讲软件：绘图、动态函数、多页保存/删除、图像导出、计算工具；\n3) 算一算：求根、定积分、不定积分、无穷级数、导数值（计算页均给出分步过程）；\n4) 小互动：抛硬币、掷骰子、随机数。\n全部离线运行，无需联网。试试对我说"积分 x^2 从 0 到 1"！'
      };
    }

    const calc: AgentReply | null = AgentCore.tryCalc(input);
    if (calc != null) {
      return calc;
    }

    if (low.indexOf('建议') >= 0 || low.indexOf('补全') >= 0 || low.indexOf('完善') >= 0 || low.indexOf('功能') >= 0) {
      return {
        intent: AgentIntent.FEATURE,
        title: '应用补全建议（小派规划）',
        text: '根据目前架构，推荐优先补全以下功能：\n1) 动画增强：曲线移动轨迹留痕、双参数联动动画；\n2) 导数/切线可视化：在绘图页叠加 f\'(x) 与切线；\n3) 复平面与傅里叶级数动画（研究生数学）；\n4) 符号计算：求导公式推导、不定积分表；\n5) 3D 曲面与等高线绘图；\n6) 学习记录：按知识点收藏并生成错题本；\n7) 端侧小模型问答（AI Kit，视设备能力）。\n以上建议已随架构规划落地优先序，可逐条在后续版本实现。'
      };
    }

    const hits: KbEntry[] = KnowledgeBase.search(input);
    if (hits.length > 0) {
      const e: KbEntry = hits[0];
      return {
        intent: e.kind === 0 ? AgentIntent.KB_MATH : AgentIntent.KB_USAGE,
        title: e.topic,
        text: e.answer
      };
    }

    return {
      intent: AgentIntent.OTHER,
      title: '小派',
      text: '这个问题我暂时没有现成答案（离线知识库有限）。\n你可以换种问法，例如：\n· 数学概念："导数的几何意义"、"什么是特征值"、"留数定理"；\n· 软件操作："怎么画图"、"方向场怎么用"；\n· 直接计算："求根 x^2-2=0"、"积分 sin(x) 从 0 到 3.14"、"不定积分 x^3"、"无穷级数 1/n^2"。\n小派是纯离线知识库，全部内容随应用打包。'
    };
  }

}