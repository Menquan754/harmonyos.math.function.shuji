/**
 * @file CalcPage.ets
 * @brief Numeric calculator tab with eleven tools and step-by-step output.
 *
 * Responsibilities
 *   - Offers eleven tools: roots, definite integral, indefinite integral,
 *     variable-limit integral, series, infinite series, line integral, surface
 *     integral, direction field, derivative value, and limits / extrema.
 *   - Validates input (clamped loop counts, parsed expressions) and prints the
 *     intermediate steps and conclusions produced by NumericKit.
 *   - Caps its width at Responsive.MAX_CALC and keeps each tool's input state
 *     independent while switching tool tabs.
 *
 * Consumers
 *   - pages/Index.ets as the third tab; expressions are parsed by ExprEngine
 *     and evaluated by NumericKit.
 *
 * @author Menquan754
 * @date 2026-10-31
 */
import { ExprEngine } from '../../core/expression/ExprEngine';
import { NumericKit, IndefResult, SeriesResult, IntegralSteps } from '../../core/numeric/NumericKit';
import { Theme } from '../../core/theme/Theme';
import { Responsive } from '../../core/layout/Responsive';

class OdeParseResult {
  ok: boolean = false;
  ast: Object = ExprEngine.parseWithParams('x').ast;
}

function fmtNum(v: number): string {
  if (!Number.isFinite(v)) {
    return '无定义';
  }
  const a: number = Math.abs(v);
  if (a !== 0 && (a >= 1e6 || a < 1e-4)) {
    return v.toExponential(4);
  }
  return Math.round(v * 100000) / 100000 + '';
}

/** 整数输入限幅，避免超大循环拖慢或卡死界面 */
function clampInt(s: string, def: number, min: number, max: number): number {
  const v: number = parseInt(s);
  if (!Number.isFinite(v)) {
    return def;
  }
  if (v < min) {
    return min;
  }
  if (v > max) {
    return max;
  }
  return v;
}

@Component
export struct CalcPage {
  @State darkMode: boolean = AppStorage.get<boolean>('darkMode') === true;
  @State tab: number = 0;
  // 求根
  @State rootExpr: string = 'x^2-2';
  @State rootA: string = '-10';
  @State rootB: string = '10';
  // 定积分
  @State intExpr: string = 'x^2';
  @State intA: string = '0';
  @State intB: string = '1';
  // 导数
  @State derExpr: string = 'sin(x)';
  @State derX: string = '0.5';
  // 不定积分
  @State indefExpr: string = 'sin(x)';
  @State indefResult: string = '（输入表达式，匹配内置原函数表）';
  // 变限积分
  @State varExpr: string = 'sin(x)';
  @State varA: string = '0';
  @State varX: string = '2';
  @State varResult: string = '';
  // 级数
  @State serExpr: string = '1/x^2';
  @State serStart: string = '1';
  @State serCount: string = '12';
  @State serResult: string = '';
  // 无穷级数
  @State infExpr: string = '1/x^2';
  @State infStart: string = '1';
  @State infMax: string = '500';
  @State infResult: string = '';
  // 曲线积分
  @State liP: string = 'x*y';
  @State liQ: string = 'x^2';
  @State liXt: string = 'cos(x)';
  @State liYt: string = 'sin(x)';
  @State liT0: string = '0';
  @State liT1: string = '6.283';
  @State liResult: string = '';
  // 曲面积分
  @State sfG: string = 'x^2+y^2';
  @State sfZ: string = 'x^2+y^2';
  @State sfX0: string = '0';
  @State sfX1: string = '1';
  @State sfY0: string = '0';
  @State sfY1: string = '1';
  @State sfResult: string = '';
  // 方向场
  @State odeExpr: string = 'x+y';
  @State odeY0: string = '0.5';
  @State odeResult: string = '';
  // 极限 / 极值
  @State limExpr: string = 'sin(x)/x';
  @State limX: string = '0';
  @State limResult: string = '';
  @State extExpr: string = 'x^3-3*x';
  @State extA: string = '-5';
  @State extB: string = '5';
  @State extResult: string = '';

  @State rootResult: string = '（输入表达式与区间，点击计算）';
  @State intResult: string = '';
  @State derResult: string = '';

  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private varTimer: number = -1;
  private odeTimer: number = -1;
  private readonly ODE_XMIN: number = -6;
  private readonly ODE_XMAX: number = 6;
  private readonly ODE_YMIN: number = -4;
  private readonly ODE_YMAX: number = 4;

  private makeF(expr: string, yValue?: number): (x: number) => number {
    let ast: Object;
    try {
      ast = ExprEngine.parseWithParams(expr).ast;
    } catch (e) {
      return (x: number): number => NaN;
    }
    const base: Object = ast;
    return (x: number): number => {
      const pm: Map<string, number> = new Map<string, number>();
      if (yValue !== undefined) {
        pm.set('y', yValue);
      }
      return ExprEngine.evaluate(base, x, pm);
    };
  }

  private onTheme: (dark: boolean) => void = (dark: boolean): void => {
    this.darkMode = dark;
  };

  aboutToAppear(): void {
    Theme.subscribe(this.onTheme);
    this.darkMode = AppStorage.get<boolean>('darkMode') === true;
  }

  aboutToDisappear(): void {
    Theme.unsubscribe(this.onTheme);
    if (this.varTimer !== -1) {
      clearTimeout(this.varTimer);
      this.varTimer = -1;
    }
    if (this.odeTimer !== -1) {
      clearTimeout(this.odeTimer);
      this.odeTimer = -1;
    }
  }

  /** 画布重绘防抖：连续输入时只在停顿后重绘一次，避免卡顿 */
  private scheduleVarDraw(): void {
    if (this.varTimer !== -1) {
      clearTimeout(this.varTimer);
    }
    this.varTimer = setTimeout(() => {
      this.varTimer = -1;
      this.varDraw();
    }, 120);
  }

  private scheduleOdeDraw(): void {
    if (this.odeTimer !== -1) {
      clearTimeout(this.odeTimer);
    }
    this.odeTimer = setTimeout(() => {
      this.odeTimer = -1;
      this.odeDraw();
      this.doOde();
    }, 120);
  }

  /** 二元求值：x 为主变量，y 传入参数表 */
  private evalXY(ast: Object, xv: number, yv: number): number {
    const pm: Map<string, number> = new Map<string, number>();
    pm.set('y', yv);
    return ExprEngine.evaluate(ast, xv, pm);
  }

  /** 三元求值：x 为主变量，y/z 传入参数表 */
  private evalXYZ(ast: Object, xv: number, yv: number, zv: number): number {
    const pm: Map<string, number> = new Map<string, number>();
    pm.set('y', yv);
    pm.set('z', zv);
    return ExprEngine.evaluate(ast, xv, pm);
  }

  // ---------------- 求根 ----------------
  private doRoot(): void {
    const a: number = parseFloat(this.rootA);
    const b: number = parseFloat(this.rootB);
    if (!Number.isFinite(a) || !Number.isFinite(b)) {
      this.rootResult = '请填写有效的区间端点';
      return;
    }
    let ast: Object;
    try {
      ast = ExprEngine.parseWithParams(this.rootExpr).ast;
    } catch (e) {
      this.rootResult = `表达式有误：${e instanceof Error ? e.message : ''}`;
      return;
    }
    const f = (x: number): number => ExprEngine.evaluate(ast, x, new Map<string, number>());
    const lo: number = Math.min(a, b);
    const hi: number = Math.max(a, b);
    if (hi - lo < 1e-12) {
      this.rootResult = '区间长度不能为 0，请输入不同的左右端点。';
      return;
    }
    const scanN: number = 400;
    const roots: number[] = NumericKit.findRoots(f, lo, hi, scanN);
    const fa: number = f(lo);
    const fb: number = f(hi);
    let txt: string = `① 方程：f(x) = ${this.rootExpr} = 0\n`;
    txt += `② 搜索区间：[${fmtNum(lo)}, ${fmtNum(hi)}]，等分为 ${scanN} 段\n`;
    txt += `③ 端点值：f(a) = ${fmtNum(fa)}，f(b) = ${fmtNum(fb)}\n`;
    if (Number.isFinite(fa) && Number.isFinite(fb)) {
      const prod: number = fa * fb;
      txt += `④ 符号判断：f(a)·f(b) = ${fmtNum(prod)}`;
      if (prod <= 0) {
        txt += ' ≤ 0，由零点定理可知区间内至少有一个实根\n';
      } else {
        txt += ' > 0，端点同号；继续扫描内部的变号点\n';
      }
    }
    if (roots.length === 0) {
      txt += `\n扫描结果：未检测到符号变化，区间内没有实根（重根或超出扫描精度时可能漏判）。`;
      this.rootResult = txt;
      return;
    }
    txt += `⑤ 扫描结果：检测到 ${roots.length} 个变号点\n`;
    // 对第一个根所在的小区间展示二分法迭代过程
    const step: number = (hi - lo) / scanN;
    let bl: number = Math.max(lo, roots[0] - step);
    let bh: number = Math.min(hi, roots[0] + step);
    let fl: number = f(bl);
    if (!Number.isFinite(fl)) {
      bl = lo;
      fl = fa;
      bh = hi;
    }
    txt += `\n【二分法迭代过程】以第 1 个根所在区间 [${fmtNum(bl)}, ${fmtNum(bh)}] 为例：\n`;
    let it: number = 0;
    while (it < 14 && Math.abs(bh - bl) > 1e-7) {
      const mid: number = (bl + bh) / 2;
      const fm: number = f(mid);
      if (!Number.isFinite(fm)) {
        txt += `第 ${it + 1} 步：中点 ${fmtNum(mid)} 处无定义，停止迭代\n`;
        break;
      }
      txt += `第 ${it + 1} 步：中点 ${fmtNum(mid)}，f(中点) = ${fmtNum(fm)} → 取${fm * fl <= 0 ? '左' : '右'}半区间\n`;
      if (fm * fl <= 0) {
        bh = mid;
      } else {
        bl = mid;
        fl = fm;
      }
      it++;
    }
    const r0: number = (bl + bh) / 2;
    txt += `区间缩小到宽度 ${fmtNum(Math.abs(bh - bl))}，取 x ≈ ${fmtNum(r0)}\n`;
    txt += `\n【全部实根】\n`;
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
        txt += `x = ${fmtNum(r)}，f(x) = ${fmtNum(f(r))}（残差校验）\n`;
      }
    }
    txt += '\n算法：区间扫描 + 二分法，精度 1e-7';
    this.rootResult = txt;
  }

  // ---------------- 定积分（含步骤） ----------------
  private doIntegral(): void {
    const a: number = parseFloat(this.intA);
    const b: number = parseFloat(this.intB);
    if (!Number.isFinite(a) || !Number.isFinite(b)) {
      this.intResult = '请填写有效的积分上下限';
      return;
    }
    let ast: Object;
    try {
      ast = ExprEngine.parseWithParams(this.intExpr).ast;
    } catch (e) {
      this.intResult = `表达式有误：${e instanceof Error ? e.message : ''}`;
      return;
    }
    const f = (x: number): number => ExprEngine.evaluate(ast, x, new Map<string, number>());
    const lo: number = Math.min(a, b);
    const hi: number = Math.max(a, b);
    if (hi - lo < 1e-12) {
      this.intResult = '积分区间长度为 0，结果为 0。';
      return;
    }
    const r: IntegralSteps = NumericKit.simpsonSteps(f, lo, hi, 2000);
    if (!r.ok) {
      this.intResult = r.text;
      return;
    }
    const r2: IntegralSteps = NumericKit.simpsonSteps(f, lo, hi, 1000);
    const mid: number = (lo + hi) / 2;
    const fMid: number = f(mid);
    const err: number = Math.abs(r.value - r2.value) / 15;
    const sign: number = a > b ? -1 : 1;
    let txt: string = `① 被积函数：f(x) = ${this.intExpr}\n`;
    txt += `② 积分区间：[${fmtNum(lo)}, ${fmtNum(hi)}]`;
    if (a > b) {
      txt += '（上下限颠倒，结果取相反数）';
    }
    txt += '\n';
    txt += `③ 区间长度：b − a = ${fmtNum(hi - lo)}\n`;
    txt += `④ 采样点：f(a) = ${fmtNum(r.fa)}，f(中点) = ${fmtNum(fMid)}，f(b) = ${fmtNum(r.fb)}\n`;
    txt += `⑤ 辛普森公式：S ≈ h/3·[f(a)+f(b)+4Σ奇数点+2Σ偶数点]\n`;
    txt += `   h = ${fmtNum(r.h)}，n = ${r.n}\n`;
    txt += `   Σ奇数点 = ${fmtNum(r.sumOdd)}，Σ偶数点 = ${fmtNum(r.sumEven)}\n`;
    txt += `⑥ 收敛校验：n=1000 时 S = ${fmtNum(r2.value)}，两次差 = ${fmtNum(Math.abs(r.value - r2.value))}\n`;
    txt += `   Richardson 误差估计 ≈ ${fmtNum(err)}\n`;
    txt += `\n结果：∫ = ${fmtNum(sign * r.value)}`;
    this.intResult = txt;
  }

  // ---------------- 导数 ----------------
  private doDeriv(): void {
    const x0: number = parseFloat(this.derX);
    if (!Number.isFinite(x0)) {
      this.derResult = '请填写有效的 x 值';
      return;
    }
    let ast: Object;
    try {
      ast = ExprEngine.parseWithParams(this.derExpr).ast;
    } catch (e) {
      this.derResult = `表达式有误：${e instanceof Error ? e.message : ''}`;
      return;
    }
    const f = (x: number): number => ExprEngine.evaluate(ast, x, new Map<string, number>());
    const h: number = 1e-5;
    const y: number = f(x0);
    const yp: number = f(x0 + h);
    const ym: number = f(x0 - h);
    const d: number = (yp - ym) / (2 * h);
    const dF: number = (yp - y) / h;
    const dB: number = (y - ym) / h;
    const d2: number = (yp - 2 * y + ym) / (h * h);
    let txt: string = `① 函数：f(x) = ${this.derExpr}，求导点 x₀ = ${fmtNum(x0)}\n`;
    txt += `② 取步长 h = ${fmtNum(h)}\n`;
    txt += `③ 采样：f(x₀−h) = ${fmtNum(ym)}，f(x₀) = ${fmtNum(y)}，f(x₀+h) = ${fmtNum(yp)}\n`;
    txt += `④ 中心差分：f′(x₀) ≈ [f(x₀+h) − f(x₀−h)] / (2h)\n`;
    txt += `   = ${fmtNum(d)}\n`;
    txt += `⑤ 对照：前向 ${fmtNum(dF)}，后向 ${fmtNum(dB)}\n`;
    if (Number.isFinite(d2)) {
      txt += `⑥ 二阶导估计：f″(x₀) ≈ [f(x₀+h) − 2f(x₀) + f(x₀−h)] / h² = ${fmtNum(d2)}\n`;
    }
    txt += `\n切线方程：y = ${fmtNum(y)} + ${fmtNum(d)}·(x − ${fmtNum(x0)})`;
    this.derResult = txt;
  }

  // ---------------- 不定积分 ----------------
  private doIndef(): void {
    const expr: string = this.indefExpr.trim();
    if (expr.length === 0) {
      this.indefResult = '请输入函数表达式';
      return;
    }
    const r: IndefResult = NumericKit.indefIntegral(expr);
    if (!r.matched) {
      this.indefResult = `∫ ${expr} dx：未命中内置原函数表。\n内置支持：x^n、sin(x)、cos(x)、e^x、1/x、ln(x)、sqrt(x)、1/sqrt(x)、1/(1+x^2)、1/cos(x)^2 等。\n提示：可用"变限积分"绘制原函数数值图像，或问小派"不定积分 ${expr}"。`;
      return;
    }
    let txt: string = `① 被积函数：f(x) = ${expr}\n`;
    txt += `② 匹配基本积分表 ⇒ ∫ f(x)dx = ${r.formula}\n`;
    txt += `③ 求导校验：对 F(x) 求导应回到 f(x)\n`;
    txt += `   x = ${fmtNum(r.samplePoint)} 处：F′(x) = ${fmtNum(r.sampleFp)}，f(x) = ${fmtNum(r.sampleF)}\n`;
    if (r.verifyOk) {
      txt += '   校验通过 ✓（|F′−f| 在容差内）\n';
    } else {
      txt += '   校验未通过，请人工核对（可能是该点函数无定义）\n';
    }
    txt += '\n提示：不定积分结果需加任意常数 C；复杂函数可用"变限积分"画原函数图像。';
    this.indefResult = txt;
  }

  // ---------------- 变限积分 ----------------
  private doVar(): void {
    const a: number = parseFloat(this.varA);
    const x0: number = parseFloat(this.varX);
    if (!Number.isFinite(a) || !Number.isFinite(x0)) {
      this.varResult = '请填写有效的下限 a 与求值点 x₀';
      return;
    }
    let ast: Object;
    try {
      ast = ExprEngine.parseWithParams(this.varExpr).ast;
    } catch (e) {
      this.varResult = `表达式有误：${e instanceof Error ? e.message : ''}`;
      return;
    }
    const f = (x: number): number => ExprEngine.evaluate(ast, x, new Map<string, number>());
    const Fx: number = NumericKit.simpson(f, a, x0, 800);
    const h: number = 1e-5;
    const dF: number = (NumericKit.simpson(f, a, x0 + h, 400) - NumericKit.simpson(f, a, x0 - h, 400)) / (2 * h);
    const fX: number = f(x0);
    let txt: string = `① 变限积分：F(x) = ∫[${fmtNum(a)}, x] f(t)dt，f(t) = ${this.varExpr}\n`;
    txt += `② 下限处：F(${fmtNum(a)}) = 0（积分区间长度为 0）\n`;
    txt += `③ 求值：F(${fmtNum(x0)}) = ∫[${fmtNum(a)}, ${fmtNum(x0)}] f(t)dt\n`;
    txt += `   辛普森数值积分 ⇒ F(${fmtNum(x0)}) ≈ ${fmtNum(Fx)}\n`;
    txt += `④ 微积分基本定理校验：F′(x₀) = f(x₀)\n`;
    txt += `   F′(x₀) ≈ ${fmtNum(dF)}，f(x₀) = ${fmtNum(fX)}`;
    if (Number.isFinite(dF) && Number.isFinite(fX)) {
      txt += Math.abs(dF - fX) <= 1e-3 * Math.max(1, Math.abs(fX)) ? '  ✓\n' : '  （偏差较大，检查 a 与 x₀ 之间是否有奇点）\n';
    } else {
      txt += '\n';
    }
    txt += '⑤ 下方曲线为 F(x) 在 [−6,6] 上的数值图像';
    this.varResult = txt;
  }

  private varDraw(): void {
    const w: number = this.ctx.width;
    const h: number = this.ctx.height;
    if (w <= 0 || h <= 0) {
      return;
    }
    const a: number = parseFloat(this.varA);
    const f: (x: number) => number = this.makeF(this.varExpr);
    this.ctx.clearRect(0, 0, w, h);
    this.ctx.fillStyle = Theme.bg();
    this.ctx.fillRect(0, 0, w, h);
    const VX_MIN: number = -6;
    const VX_MAX: number = 6;
    const left: number = 34;
    const right: number = 14;
    const top: number = 14;
    const bottom: number = 26;
    const N: number = 161;
    const xs: number[] = [];
    const ys: number[] = [];
    let yMin: number = Infinity;
    let yMax: number = -Infinity;
    for (let i: number = 0; i < N; i++) {
      const x: number = VX_MIN + (VX_MAX - VX_MIN) * i / (N - 1);
      let y: number = NaN;
      if (Number.isFinite(a)) {
        const v: number = NumericKit.simpson(f, a, x, 400);
        if (Number.isFinite(v)) {
          y = v;
        }
      }
      xs.push(x);
      ys.push(y);
      if (Number.isFinite(y)) {
        if (y < yMin) {
          yMin = y;
        }
        if (y > yMax) {
          yMax = y;
        }
      }
    }
    if (!Number.isFinite(yMin) || yMax - yMin < 1e-9) {
      yMin = -1;
      yMax = 1;
    }
    const padY: number = (yMax - yMin) * 0.1;
    yMin -= padY;
    yMax += padY;
    const mX = (x: number): number => left + (x - VX_MIN) / (VX_MAX - VX_MIN) * (w - left - right);
    const mY = (y: number): number => top + (yMax - y) / (yMax - yMin) * (h - top - bottom);
    // 网格线
    this.ctx.strokeStyle = Theme.grid();
    this.ctx.lineWidth = 1;
    for (let x: number = -6; x <= 6; x += 1) {
      const px: number = mX(x);
      this.ctx.beginPath();
      this.ctx.moveTo(px, top);
      this.ctx.lineTo(px, h - bottom);
      this.ctx.stroke();
    }
    for (let y: number = Math.ceil(yMin); y <= Math.floor(yMax); y += 1) {
      const py: number = mY(y);
      this.ctx.beginPath();
      this.ctx.moveTo(left, py);
      this.ctx.lineTo(w - right, py);
      this.ctx.stroke();
    }
    // 坐标轴
    this.ctx.strokeStyle = Theme.axisSoft();
    this.ctx.lineWidth = 1.5;
    const x0Px: number = mX(0);
    const y0Px: number = mY(0);
    this.ctx.beginPath();
    this.ctx.moveTo(left, y0Px);
    this.ctx.lineTo(w - right, y0Px);
    this.ctx.stroke();
    this.ctx.beginPath();
    this.ctx.moveTo(x0Px, top);
    this.ctx.lineTo(x0Px, h - bottom);
    this.ctx.stroke();
    // F(x) 曲线
    this.ctx.strokeStyle = Theme.primary();
    this.ctx.lineWidth = 2.2;
    let started: boolean = false;
    this.ctx.beginPath();
    for (let i: number = 0; i < N; i++) {
      if (!Number.isFinite(ys[i])) {
        started = false;
        continue;
      }
      const px: number = mX(xs[i]);
      const py: number = mY(ys[i]);
      if (!started) {
        this.ctx.moveTo(px, py);
        started = true;
      } else {
        this.ctx.lineTo(px, py);
      }
    }
    this.ctx.stroke();
    // 下限标记
    if (Number.isFinite(a)) {
      this.ctx.fillStyle = Theme.danger();
      this.ctx.beginPath();
      this.ctx.arc(mX(a), mY(0), 4, 0, 2 * Math.PI);
      this.ctx.fill();
    }
  }

  // ---------------- 级数 ----------------
  private doSeries(): void {
    const a: number = clampInt(this.serStart, 1, -1000000, 1000000);
    const cnt: number = clampInt(this.serCount, 12, 1, 2000);
    if (!Number.isFinite(a)) {
      this.serResult = '请填写有效的起始 n';
      return;
    }
    let ast: Object;
    try {
      ast = ExprEngine.parseWithParams(this.serExpr).ast;
    } catch (e) {
      this.serResult = `通项表达式有误：${e instanceof Error ? e.message : ''}`;
      return;
    }
    const term = (n: number): number => ExprEngine.evaluate(ast, n, new Map<string, number>());
    const sums: number[] = NumericKit.seriesPartialSums(term, a, cnt);
    const show: number = Math.min(6, cnt);
    let txt: string = `① 通项：aₙ = ${this.serExpr}（表达式中的 x 代入 n）\n`;
    txt += `② 求前 ${cnt} 项部分和，n 从 ${a} 开始\n`;
    txt += '③ 各项取值：\n';
    for (let i: number = 0; i < show; i++) {
      txt += `   a_${a + i} = ${fmtNum(term(a + i))}，S_${a + i} = ${fmtNum(sums[i])}\n`;
    }
    if (cnt > show) {
      txt += `   … 共 ${cnt} 项\n`;
    }
    txt += `④ 最终部分和：S_${a + cnt - 1} = ${fmtNum(sums[cnt - 1])}\n`;
    txt += `⑤ 末项：a_${a + cnt - 1} = ${fmtNum(term(a + cnt - 1))}`;
    if (cnt >= 2) {
      const last: number = term(a + cnt - 1);
      const prev: number = term(a + cnt - 2);
      if (Math.abs(prev) > 1e-12) {
        txt += `\n⑥ 末两项比值 a_n/a_{n−1} = ${fmtNum(last / prev)}（比值 <1 且稳定说明趋于收敛）`;
      }
    }
    this.serResult = txt;
  }

  private doInfSeries(): void {
    const a: number = clampInt(this.infStart, 1, -1000000, 1000000);
    const m: number = clampInt(this.infMax, 500, 10, 20000);
    if (!Number.isFinite(a)) {
      this.infResult = '请填写有效的起始 n';
      return;
    }
    let ast: Object;
    try {
      ast = ExprEngine.parseWithParams(this.infExpr).ast;
    } catch (e) {
      this.infResult = `通项表达式有误：${e instanceof Error ? e.message : ''}`;
      return;
    }
    const term = (n: number): number => ExprEngine.evaluate(ast, n, new Map<string, number>());
    const r: SeriesResult = NumericKit.infiniteSeries(term, a, m);
    let txt: string = `① 通项：aₙ = ${this.infExpr}，n 从 ${a} 开始\n`;
    txt += `② 最大计算项数：${m}（实际累加到 n = ${r.tailN}）\n`;
    txt += '③ 前几项：';
    for (let i: number = 0; i < 5; i++) {
      txt += `a_${a + i}=${fmtNum(term(a + i))}  `;
    }
    txt += '\n④ 部分和：';
    for (let i: number = 0; i < r.partials.length; i++) {
      txt += `S_${a + i}=${fmtNum(r.partials[i])}  `;
    }
    txt += '\n';
    txt += `⑤ 末项 a_${r.tailN} = ${fmtNum(r.lastTerm)}，部分和 S ≈ ${fmtNum(r.sum)}\n`;
    if (Number.isFinite(r.lastTerm) && Number.isFinite(r.sum)) {
      if (r.converged) {
        const tail: number = Math.abs(r.lastTerm) * 2;
        txt += `⑥ 截断误差估计：|R_N| 约 ≤ ${fmtNum(tail)}（末项量级估计）\n`;
      }
    }
    txt += `⑦ 判定：${r.converged ? '收敛（数值估计）' : '发散 / 未收敛'}\n`;
    txt += r.judgment;
    this.infResult = txt;
  }

  // ---------------- 曲线积分 ----------------
  private doLine(): void {
    const t0: number = parseFloat(this.liT0);
    const t1: number = parseFloat(this.liT1);
    if (!Number.isFinite(t0) || !Number.isFinite(t1)) {
      this.liResult = '请填写有效的参数 t 范围';
      return;
    }
    let astP: Object;
    let astQ: Object;
    let astXt: Object;
    let astYt: Object;
    try {
      astP = ExprEngine.parseWithParams(this.liP).ast;
      astQ = ExprEngine.parseWithParams(this.liQ).ast;
      astXt = ExprEngine.parseWithParams(this.liXt).ast;
      astYt = ExprEngine.parseWithParams(this.liYt).ast;
    } catch (e) {
      this.liResult = `表达式有误：${e instanceof Error ? e.message : ''}`;
      return;
    }
    const pFn = (x: number, y: number): number => this.evalXY(astP, x, y);
    const qFn = (x: number, y: number): number => this.evalXY(astQ, x, y);
    const xt = (t: number): number => ExprEngine.evaluate(astXt, t, new Map<string, number>());
    const yt = (t: number): number => ExprEngine.evaluate(astYt, t, new Map<string, number>());
    const val: number = NumericKit.lineIntegral(pFn, qFn, xt, yt, t0, t1);
    if (!Number.isFinite(val)) {
      this.liResult = '计算失败：参数曲线或被积函数在范围内无定义。';
      return;
    }
    const tm: number = (t0 + t1) / 2;
    const px: number = xt(t0);
    const py: number = yt(t0);
    const dxdt: number = NumericKit.deriv(xt, t0);
    const dydt: number = NumericKit.deriv(yt, t0);
    let txt: string = `① 积分：∫_C [P dx + Q dy]，P = ${this.liP}，Q = ${this.liQ}\n`;
    txt += `② 参数化：x(t) = ${this.liXt}，y(t) = ${this.liYt}，t ∈ [${fmtNum(t0)}, ${fmtNum(t1)}]\n`;
    txt += `③ 化为定积分：∫[P(x(t),y(t))·x′(t) + Q(x(t),y(t))·y′(t)] dt\n`;
    txt += `④ 在 t₀ = ${fmtNum(t0)} 处取样：\n`;
    txt += `   (x, y) = (${fmtNum(px)}, ${fmtNum(py)})\n`;
    txt += `   P = ${fmtNum(pFn(px, py))}，Q = ${fmtNum(qFn(px, py))}\n`;
    txt += `   x′(t) ≈ ${fmtNum(dxdt)}，y′(t) ≈ ${fmtNum(dydt)}\n`;
    txt += `   被积函数 P·x′ + Q·y′ ≈ ${fmtNum(pFn(px, py) * dxdt + qFn(px, py) * dydt)}\n`;
    txt += `⑤ 中点 t = ${fmtNum(tm)} 处再取样，辛普森法 800 段累加\n`;
    txt += `\n结果：∫_C = ${fmtNum(val)}`;
    this.liResult = txt;
  }

  // ---------------- 曲面积分 ----------------
  private doSurface(): void {
    const x0: number = parseFloat(this.sfX0);
    const x1: number = parseFloat(this.sfX1);
    const y0: number = parseFloat(this.sfY0);
    const y1: number = parseFloat(this.sfY1);
    if (!Number.isFinite(x0) || !Number.isFinite(x1) || !Number.isFinite(y0) || !Number.isFinite(y1)) {
      this.sfResult = '请填写有效的投影区域';
      return;
    }
    let astG: Object;
    let astZ: Object;
    try {
      astG = ExprEngine.parseWithParams(this.sfG).ast;
      astZ = ExprEngine.parseWithParams(this.sfZ).ast;
    } catch (e) {
      this.sfResult = `表达式有误：${e instanceof Error ? e.message : ''}`;
      return;
    }
    const gFn = (x: number, y: number, z: number): number => this.evalXYZ(astG, x, y, z);
    const zFn = (x: number, y: number): number => this.evalXY(astZ, x, y);
    const val: number = NumericKit.surfaceIntegral(gFn, zFn, x0, x1, y0, y1);
    if (!Number.isFinite(val)) {
      this.sfResult = '计算失败：曲面或被积函数在区域内无定义。';
      return;
    }
    const cx: number = (x0 + x1) / 2;
    const cy: number = (y0 + y1) / 2;
    const zc: number = zFn(cx, cy);
    const zx: number = NumericKit.deriv((xx: number): number => zFn(xx, cy), cx);
    const zy: number = NumericKit.deriv((yy: number): number => zFn(cx, yy), cy);
    const area: number = Math.abs((x1 - x0) * (y1 - y0));
    let txt: string = `① 积分：∬_S g(x,y,z) dS，g = ${this.sfG}\n`;
    txt += `② 曲面：z = ${this.sfZ}，投影 D = [${fmtNum(x0)}, ${fmtNum(x1)}] × [${fmtNum(y0)}, ${fmtNum(y1)}]\n`;
    txt += `③ 面积元素：dS = √(1 + z_x² + z_y²) dxdy\n`;
    txt += `④ 投影中心 (${fmtNum(cx)}, ${fmtNum(cy)}) 处取样：\n`;
    txt += `   z = ${fmtNum(zc)}，z_x ≈ ${fmtNum(zx)}，z_y ≈ ${fmtNum(zy)}\n`;
    txt += `   √(1+z_x²+z_y²) ≈ ${fmtNum(Math.sqrt(1 + zx * zx + zy * zy))}\n`;
    txt += `   g(x,y,z) = ${fmtNum(gFn(cx, cy, zc))}\n`;
    txt += `⑤ 投影区域面积 ≈ ${fmtNum(area)}，二维辛普森嵌套积分（40×40 段）\n`;
    txt += `\n结果：∬_S = ${fmtNum(val)}`;
    this.sfResult = txt;
  }

  // ---------------- 方向场 ----------------
  private buildOde(): OdeParseResult {
    const r: OdeParseResult = new OdeParseResult();
    try {
      r.ast = ExprEngine.parseWithParams(this.odeExpr.trim()).ast;
      r.ok = true;
    } catch (e) {
      this.odeResult = `表达式有误：${e instanceof Error ? e.message : ''}`;
    }
    return r;
  }

  private odeDraw(): void {
    const w: number = this.ctx.width;
    const h: number = this.ctx.height;
    if (w <= 0 || h <= 0) {
      return;
    }
    const r: OdeParseResult = this.buildOde();
    this.ctx.clearRect(0, 0, w, h);
    this.ctx.fillStyle = Theme.bg();
    this.ctx.fillRect(0, 0, w, h);
    if (!r.ok) {
      this.ctx.fillStyle = Theme.danger();
      this.ctx.font = '14px sans-serif';
      this.ctx.fillText('请先修正表达式', w / 2, h / 2);
      return;
    }
    const left: number = 34;
    const right: number = 14;
    const top: number = 14;
    const bottom: number = 26;
    const mX = (x: number): number => left + (x - this.ODE_XMIN) / (this.ODE_XMAX - this.ODE_XMIN) * (w - left - right);
    const mY = (y: number): number => top + (this.ODE_YMAX - y) / (this.ODE_YMAX - this.ODE_YMIN) * (h - top - bottom);
    // 网格线
    this.ctx.strokeStyle = Theme.grid();
    this.ctx.lineWidth = 1;
    const gx: number = 1;
    for (let x: number = -6; x <= 6; x += gx) {
      const px: number = mX(x);
      this.ctx.beginPath();
      this.ctx.moveTo(px, top);
      this.ctx.lineTo(px, h - bottom);
      this.ctx.stroke();
    }
    for (let y: number = -4; y <= 4; y += 1) {
      const py: number = mY(y);
      this.ctx.beginPath();
      this.ctx.moveTo(left, py);
      this.ctx.lineTo(w - right, py);
      this.ctx.stroke();
    }
    // 坐标轴
    this.ctx.strokeStyle = Theme.axisSoft();
    this.ctx.lineWidth = 1.5;
    const x0Px: number = mX(0);
    const y0Px: number = mY(0);
    this.ctx.beginPath();
    this.ctx.moveTo(left, y0Px);
    this.ctx.lineTo(w - right, y0Px);
    this.ctx.stroke();
    this.ctx.beginPath();
    this.ctx.moveTo(x0Px, top);
    this.ctx.lineTo(x0Px, h - bottom);
    this.ctx.stroke();
    // 斜率场
    const nx: number = 15;
    const ny: number = 11;
    const cells: number[][][] = NumericKit.directionField((x: number, y: number): number => {
      const pm: Map<string, number> = new Map<string, number>();
      pm.set('y', y);
      return ExprEngine.evaluate(r.ast, x, pm);
    }, this.ODE_XMIN, this.ODE_XMAX, this.ODE_YMIN, this.ODE_YMAX, nx, ny);
    this.ctx.strokeStyle = Theme.isDark() ? '#3A3A3A' : '#BBBBBB';
    this.ctx.lineWidth = 1.2;
    const L: number = 0.32;
    for (let i: number = 0; i < nx; i++) {
      for (let j: number = 0; j < ny; j++) {
        const c: number[] = cells[i][j];
        const x: number = c[0];
        const y: number = c[1];
        const s: number = Math.max(-6, Math.min(6, c[2]));
        const ang: number = Math.atan(s);
        const dx: number = L * Math.cos(ang);
        const dy: number = L * Math.sin(ang);
        this.ctx.beginPath();
        this.ctx.moveTo(mX(x - dx), mY(y + dy));
        this.ctx.lineTo(mX(x + dx), mY(y - dy));
        this.ctx.stroke();
      }
    }
    // RK4 数值解
    const y0: number = parseFloat(this.odeY0);
    if (Number.isFinite(y0)) {
      const fxy = (x: number, y: number): number => {
        const pm: Map<string, number> = new Map<string, number>();
        pm.set('y', y);
        return ExprEngine.evaluate(r.ast, x, pm);
      };
      const curve: number[][] = NumericKit.rk4(fxy, this.ODE_XMIN, y0, this.ODE_XMAX, 200);
      this.ctx.strokeStyle = Theme.danger();
      this.ctx.lineWidth = 2.2;
      let started: boolean = false;
      this.ctx.beginPath();
      for (let k: number = 0; k < curve.length; k++) {
        const x: number = curve[k][0];
        const y: number = curve[k][1];
        if (!Number.isFinite(y)) {
          started = false;
          continue;
        }
        const px: number = mX(x);
        const py: number = mY(y);
        if (!started) {
          this.ctx.moveTo(px, py);
          started = true;
        } else {
          this.ctx.lineTo(px, py);
        }
      }
      this.ctx.stroke();
      // 初值点
      this.ctx.fillStyle = Theme.danger();
      this.ctx.beginPath();
      this.ctx.arc(mX(this.ODE_XMIN), mY(y0), 4, 0, 2 * Math.PI);
      this.ctx.fill();
    }
  }

  /** 方向场 RK4 前几步的求解过程 */
  private doOde(): void {
    const r: OdeParseResult = this.buildOde();
    if (!r.ok) {
      this.odeResult = '表达式有误，请检查 dy/dx = f(x,y)。';
      return;
    }
    const y0: number = parseFloat(this.odeY0);
    if (!Number.isFinite(y0)) {
      this.odeResult = '请填写有效的初值 y₀。';
      return;
    }
    const fxy = (x: number, y: number): number => {
      const pm: Map<string, number> = new Map<string, number>();
      pm.set('y', y);
      return ExprEngine.evaluate(r.ast, x, pm);
    };
    const n: number = 200;
    const h: number = (this.ODE_XMAX - this.ODE_XMIN) / n;
    const x0: number = this.ODE_XMIN;
    const k1: number = fxy(x0, y0);
    const k2: number = fxy(x0 + h / 2, y0 + h * k1 / 2);
    const k3: number = fxy(x0 + h / 2, y0 + h * k2 / 2);
    const k4: number = fxy(x0 + h, y0 + h * k3);
    const y1: number = y0 + h * (k1 + 2 * k2 + 2 * k3 + k4) / 6;
    let txt: string = `① 方程：dy/dx = ${this.odeExpr}，初值 y(${fmtNum(x0)}) = ${fmtNum(y0)}\n`;
    txt += `② 步长 h = (${fmtNum(this.ODE_XMAX)} − ${fmtNum(this.ODE_XMIN)}) / ${n} = ${fmtNum(h)}\n`;
    txt += `③ 第 1 步四阶龙格-库塔：\n`;
    txt += `   k₁ = f(x₀, y₀) = ${fmtNum(k1)}\n`;
    txt += `   k₂ = f(x₀+h/2, y₀+h·k₁/2) = ${fmtNum(k2)}\n`;
    txt += `   k₃ = f(x₀+h/2, y₀+h·k₂/2) = ${fmtNum(k3)}\n`;
    txt += `   k₄ = f(x₀+h, y₀+h·k₃) = ${fmtNum(k4)}\n`;
    txt += `   y₁ = y₀ + h/6·(k₁+2k₂+2k₃+k₄) = ${fmtNum(y1)}\n`;
    const curve: number[][] = NumericKit.rk4(fxy, this.ODE_XMIN, y0, this.ODE_XMAX, n);
    if (curve.length > 0) {
      const end: number[] = curve[curve.length - 1];
      txt += `④ 共迭代 ${n} 步，数值解在 x = ${fmtNum(end[0])} 处 y ≈ ${fmtNum(end[1])}\n`;
      txt += '⑤ 红色曲线为数值解，灰色短线为斜率场';
    }
    this.odeResult = txt;
  }

  // ---------------- 极限（数值逼近） ----------------
  private doLimit(): void {
    let ast: Object;
    try {
      ast = ExprEngine.parseWithParams(this.limExpr).ast;
    } catch (e) {
      this.limResult = `表达式有误：${e instanceof Error ? e.message : ''}`;
      return;
    }
    const f = (x: number): number => ExprEngine.evaluate(ast, x, new Map<string, number>());
    const raw: string = this.limX.trim().toLowerCase();
    const toPosInf: boolean = raw === 'inf' || raw === '+inf' || raw === '∞' || raw === '+∞' || raw === 'infinity';
    const toNegInf: boolean = raw === '-inf' || raw === '-∞' || raw === '-infinity';
    let txt: string = `① 表达式：f(x) = ${this.limExpr}\n`;

    if (toPosInf || toNegInf) {
      const sgn: number = toNegInf ? -1 : 1;
      txt += `② 考察点：x → ${toNegInf ? '−∞' : '+∞'}\n`;
      txt += `③ 取 |x| 逐级增大的采样点，观察 f(x) 的走向\n\n`;
      const mags: number[] = [1e1, 1e2, 1e3, 1e4, 1e5, 1e6, 1e7, 1e8];
      const vals: number[] = [];
      for (let i: number = 0; i < mags.length; i++) {
        const xv: number = sgn * mags[i];
        const yv: number = f(xv);
        vals.push(yv);
        txt += `x = ${fmtNum(xv)}  →  f(x) = ${fmtNum(yv)}\n`;
      }
      const a1: number = vals[vals.length - 3];
      const a2: number = vals[vals.length - 2];
      const a3: number = vals[vals.length - 1];
      txt += '\n【判定】\n';
      if (Number.isFinite(a1) && Number.isFinite(a2) && Number.isFinite(a3)) {
        const scale: number = Math.max(1, Math.abs(a3));
        const d2: number = Math.abs(a3 - a2);
        if (Math.abs(a3) > 1e8 && Math.abs(a3) > Math.abs(a2)) {
          txt += `函数值随 |x| 增大而发散，极限为 ${a3 > 0 ? '+∞' : '−∞'}`;
        } else if (d2 / scale < 1e-3 && Math.abs(a2 - a1) / Math.max(1, Math.abs(a2)) < 1e-2) {
          txt += `后三个采样点已稳定，极限 ≈ ${fmtNum(a3)}`;
        } else {
          txt += `采样值仍在变化（相邻差 ${fmtNum(d2)}），极限未收敛或不存在`;
        }
      } else {
        txt += '采样中出现无定义值，无法判定极限';
      }
      txt += '\n\n算法：逐级增大 |x| 采样 + 相对变化量收敛判定';
      this.limResult = txt;
      return;
    }

    const x0: number = parseFloat(raw);
    if (!Number.isFinite(x0)) {
      this.limResult = '趋近点请填写数字，或填 inf / -inf 表示趋于正 / 负无穷';
      return;
    }
    txt += `② 考察点：x₀ = ${fmtNum(x0)}（左右两侧同时逼近）\n`;
    txt += `③ h 依次缩小，分别计算 f(x₀−h) 与 f(x₀+h)\n\n`;
    const hs: number[] = [1e-1, 1e-2, 1e-3, 1e-4, 1e-5, 1e-6];
    const lefts: number[] = [];
    const rights: number[] = [];
    for (let i: number = 0; i < hs.length; i++) {
      const h: number = hs[i];
      const lv: number = f(x0 - h);
      const rv: number = f(x0 + h);
      lefts.push(lv);
      rights.push(rv);
      txt += `h = ${fmtNum(h)}：f(x₀−h) = ${fmtNum(lv)}，f(x₀+h) = ${fmtNum(rv)}\n`;
    }
    const f0: number = f(x0);
    const L: number = lefts[lefts.length - 1];
    const Lp: number = lefts[lefts.length - 2];
    const R: number = rights[rights.length - 1];
    const Rp: number = rights[rights.length - 2];
    const convL: boolean = Number.isFinite(L) && Number.isFinite(Lp) &&
      Math.abs(L - Lp) < 1e-3 * Math.max(1, Math.abs(L));
    const convR: boolean = Number.isFinite(R) && Number.isFinite(Rp) &&
      Math.abs(R - Rp) < 1e-3 * Math.max(1, Math.abs(R));
    txt += `\n【判定】\n`;
    txt += `左极限存在性：${convL ? '收敛' : '未收敛'}；右极限存在性：${convR ? '收敛' : '未收敛'}\n`;
    if (convL && convR) {
      const diff: number = Math.abs(L - R);
      const tol: number = 1e-3 * Math.max(1, Math.abs(L));
      if (diff <= tol) {
        const lim: number = (L + R) / 2;
        txt += `左右极限一致，极限 ≈ ${fmtNum(lim)}\n`;
        if (Number.isFinite(f0)) {
          txt += `f(x₀) = ${fmtNum(f0)}，与极限${Math.abs(f0 - lim) <= 1e-3 * Math.max(1, Math.abs(lim)) ? '相同，函数在该点连续' : '不同，该点为可去间断点'}`;
        } else {
          txt += 'f(x₀) 无定义，但极限存在（可去间断点）';
        }
      } else {
        txt += `左右极限不等（左 ≈ ${fmtNum(L)}，右 ≈ ${fmtNum(R)}），极限不存在（跳跃间断）`;
      }
    } else if (Number.isFinite(R) && Number.isFinite(Rp) && Math.abs(R) > 10 * Math.abs(Rp) && Math.abs(R) > 1e4) {
      txt += `函数值随 h 减小而急剧增大，右极限为 ${R > 0 ? '+∞' : '−∞'}，极限发散`;
    } else {
      txt += '采样未收敛，极限可能不存在（振荡或发散），可换趋近点或用更小 h 复测';
    }
    txt += '\n\n算法：双侧数值逼近（h=1e-1…1e-6）+ 相对变化量收敛判定';
    this.limResult = txt;
  }

  // ---------------- 极值（驻点扫描 + 二阶导判别） ----------------
  private doExtremum(): void {
    const a: number = parseFloat(this.extA);
    const b: number = parseFloat(this.extB);
    if (!Number.isFinite(a) || !Number.isFinite(b)) {
      this.extResult = '请填写有效的区间端点';
      return;
    }
    const lo: number = Math.min(a, b);
    const hi: number = Math.max(a, b);
    if (hi - lo < 1e-9) {
      this.extResult = '区间长度不能为 0，请输入不同的左右端点。';
      return;
    }
    let ast: Object;
    try {
      ast = ExprEngine.parseWithParams(this.extExpr).ast;
    } catch (e) {
      this.extResult = `表达式有误：${e instanceof Error ? e.message : ''}`;
      return;
    }
    const f = (x: number): number => ExprEngine.evaluate(ast, x, new Map<string, number>());
    const df = (x: number): number => NumericKit.deriv(f, x, 1e-6);
    const d2f = (x: number): number => NumericKit.deriv(df, x, 1e-4);

    const n: number = 2000;
    const step: number = (hi - lo) / n;
    const stations: number[] = [];
    let xPrev: number = lo;
    let dPrev: number = df(xPrev);
    const signChanges: number[][] = [];
    for (let i: number = 1; i <= n; i++) {
      const xCur: number = lo + i * step;
      const dCur: number = df(xCur);
      if (Number.isFinite(dPrev) && Number.isFinite(dCur) && dPrev * dCur < 0) {
        signChanges.push([xPrev, xCur]);
      }
      xPrev = xCur;
      dPrev = dCur;
    }
    for (let k: number = 0; k < signChanges.length; k++) {
      let l: number = signChanges[k][0];
      let r: number = signChanges[k][1];
      let dl: number = df(l);
      for (let it: number = 0; it < 60; it++) {
        const mid: number = (l + r) / 2;
        const dm: number = df(mid);
        if (!Number.isFinite(dm) || r - l < 1e-7) {
          break;
        }
        if (dl * dm <= 0) {
          r = mid;
        } else {
          l = mid;
          dl = dm;
        }
      }
      const root: number = (l + r) / 2;
      let dup: boolean = false;
      for (let j: number = 0; j < stations.length; j++) {
        if (Math.abs(root - stations[j]) < 1e-4) {
          dup = true;
          break;
        }
      }
      if (!dup) {
        stations.push(root);
      }
    }

    let txt: string = `① 函数：f(x) = ${this.extExpr}\n`;
    txt += `② 搜索区间：[${fmtNum(lo)}, ${fmtNum(hi)}]，等分为 ${n} 段\n`;
    txt += `③ 计算 f'(x)，扫描其变号点（驻点候选）\n`;
    txt += `④ 对每个变号区间用二分法细化到 |f'| 的变号精度 1e-7\n`;
    txt += `⑤ 用二阶导 f''(x) 的符号判别极大 / 极小\n\n`;
    const baseTxt: string = txt;

    if (stations.length === 0) {
      this.extResult = baseTxt + `扫描结果：区间内没有 f'(x) 的变号点，无内部极值。\n` +
        `端点值：f(a) = ${fmtNum(f(lo))}，f(b) = ${fmtNum(f(hi))}`;
      return;
    }
    txt += `【内部驻点】共 ${stations.length} 个\n`;
    for (let i: number = 0; i < stations.length; i++) {
      const xs: number = stations[i];
      const ys: number = f(xs);
      const sec: number = d2f(xs);
      let kind: string = '无法判别（二阶导为 0，需更高阶判别）';
      if (Number.isFinite(sec)) {
        if (sec < -1e-6) {
          kind = '极大值点（f\'\' < 0）';
        } else if (sec > 1e-6) {
          kind = '极小值点（f\'\' > 0）';
        }
      }
      txt += `x = ${fmtNum(xs)}：f(x) = ${fmtNum(ys)}，f''(x) = ${fmtNum(sec)} → ${kind}\n`;
    }

    // 端点与驻点比较，给出区间上的最值
    const fa: number = f(lo);
    const fb: number = f(hi);
    let maxX: number = lo;
    let maxV: number = fa;
    let minX: number = lo;
    let minV: number = fa;
    if (Number.isFinite(fb)) {
      if (!Number.isFinite(maxV) || fb > maxV) {
        maxV = fb;
        maxX = hi;
      }
      if (!Number.isFinite(minV) || fb < minV) {
        minV = fb;
        minX = hi;
      }
    }
    for (let i: number = 0; i < stations.length; i++) {
      const xs: number = stations[i];
      const ys: number = f(xs);
      if (!Number.isFinite(ys)) {
        continue;
      }
      if (!Number.isFinite(maxV) || ys > maxV) {
        maxV = ys;
        maxX = xs;
      }
      if (!Number.isFinite(minV) || ys < minV) {
        minV = ys;
        minX = xs;
      }
    }
    txt += `\n【区间内最值】\n`;
    txt += `最大值：f(${fmtNum(maxX)}) = ${fmtNum(maxV)}\n`;
    txt += `最小值：f(${fmtNum(minX)}) = ${fmtNum(minV)}\n`;
    txt += `端点值：f(a) = ${fmtNum(fa)}，f(b) = ${fmtNum(fb)}\n`;
    txt += '\n算法：2000 段扫描 f\' 变号 + 二分细化 + 二阶导判别 + 端点比较';
    this.extResult = txt;
  }

  // ---------------- UI ----------------
  /** 结果区容器统一样式（不接收参数，避免 @Builder 值传递不触发刷新） */
  @Styles
  panelStyle() {
    .width('100%')
    .layoutWeight(1)
    .align(Alignment.TopStart)
    .padding(10)
    .backgroundColor(Theme.bgSoft())
    .borderRadius(10)
  }

  @Builder
  varCanvas() {
    Canvas(this.ctx)
      .width('100%')
      .layoutWeight(1)
      .backgroundColor(Theme.bg())
      .onReady(() => {
        this.varDraw();
      })
      .onAreaChange((o: Area, n: Area) => {
        this.scheduleVarDraw();
      })
  }

  @Builder
  odeCanvas() {
    Canvas(this.ctx)
      .width('100%')
      .layoutWeight(1)
      .backgroundColor(Theme.bg())
      .onReady(() => {
        this.odeDraw();
      })
      .onAreaChange((o: Area, n: Area) => {
        this.scheduleOdeDraw();
      })
  }

  build() {
    Column() {
      // 宽屏（平板 / PC）下限制计算区宽度并居中
      Column({ space: 8 }) {
      // 分栏切换
      Scroll() {
        Row({ space: 6 }) {
          this.tabBtn('求根', 0)
          this.tabBtn('定积分', 1)
          this.tabBtn('不定积分', 2)
          this.tabBtn('变限积分', 3)
          this.tabBtn('级数', 4)
          this.tabBtn('无穷级数', 5)
          this.tabBtn('曲线积分', 6)
          this.tabBtn('曲面积分', 7)
          this.tabBtn('方向场', 8)
          this.tabBtn('导数值', 9)
          this.tabBtn('极限/极值', 10)
        }
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
      .padding({ top: 6 })

      if (this.tab === 0) {
        Column({ space: 8 }) {
          Text('求 f(x)=0 的实根（二分法 + 区间扫描）').fontSize(13).fontColor(Theme.textSub())
          Row({ space: 6 }) {
            Text('f(x) =').fontSize(12).fontColor(Theme.textDim())
            TextInput({ text: this.rootExpr, placeholder: '如 x^2-2、sin(x)-0.5' })
              .layoutWeight(1)
              .onChange((v: string) => { this.rootExpr = v; })
          }
          Row({ space: 8 }) {
            Text('区间 a =').fontSize(12).fontColor(Theme.textDim())
            TextInput({ text: this.rootA, placeholder: 'a' })
              .layoutWeight(1).onChange((v: string) => { this.rootA = v; })
            Text('b =').fontSize(12).fontColor(Theme.textDim())
            TextInput({ text: this.rootB, placeholder: 'b' })
              .layoutWeight(1).onChange((v: string) => { this.rootB = v; })
            Button('计算').fontSize(14).backgroundColor(Theme.primary())
              .onClick(() => { this.doRoot(); })
          }
          Scroll() {
            Text(this.rootResult)
              .fontSize(13).lineHeight(20).fontColor(Theme.textMain())
              .width('100%').textAlign(TextAlign.Start)
          }
          .scrollBar(BarState.Auto).panelStyle()
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding(12)
        .backgroundColor(Theme.card())
        .borderRadius(12)
        .layoutWeight(1)
      }

      if (this.tab === 1) {
        Column({ space: 8 }) {
          Text('∫[a,b] f(x)dx（自适应辛普森，含步骤）').fontSize(13).fontColor(Theme.textSub())
          Row({ space: 6 }) {
            Text('f(x) =').fontSize(12).fontColor(Theme.textDim())
            TextInput({ text: this.intExpr, placeholder: '如 x^2、sin(x)' })
              .layoutWeight(1)
              .onChange((v: string) => { this.intExpr = v; })
          }
          Row({ space: 8 }) {
            Text('下限 a =').fontSize(12).fontColor(Theme.textDim())
            TextInput({ text: this.intA, placeholder: '0' })
              .layoutWeight(1).onChange((v: string) => { this.intA = v; })
            Text('上限 b =').fontSize(12).fontColor(Theme.textDim())
            TextInput({ text: this.intB, placeholder: '1' })
              .layoutWeight(1).onChange((v: string) => { this.intB = v; })
            Button('计算').fontSize(14).backgroundColor(Theme.primary())
              .onClick(() => { this.doIntegral(); })
          }
          Scroll() {
            Text(this.intResult.length > 0 ? this.intResult : '（点击「计算」查看积分步骤与误差估计）')
              .fontSize(13).lineHeight(20).fontColor(Theme.textMain())
              .width('100%').textAlign(TextAlign.Start)
          }
          .scrollBar(BarState.Auto).panelStyle()
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding(12)
        .backgroundColor(Theme.card())
        .borderRadius(12)
        .layoutWeight(1)
      }

      if (this.tab === 9) {
        Column({ space: 8 }) {
          Text('f\'(x₀) 数值导数（中心差分）').fontSize(13).fontColor(Theme.textSub())
          Row({ space: 6 }) {
            Text('f(x) =').fontSize(12).fontColor(Theme.textDim())
            TextInput({ text: this.derExpr, placeholder: '如 sin(x)、x^3' })
              .layoutWeight(1)
              .onChange((v: string) => { this.derExpr = v; })
          }
          Row({ space: 8 }) {
            Text('x₀ =').fontSize(12).fontColor(Theme.textDim())
            TextInput({ text: this.derX, placeholder: '求导点' })
              .layoutWeight(1).onChange((v: string) => { this.derX = v; })
            Button('计算').fontSize(14).backgroundColor(Theme.primary())
              .onClick(() => { this.doDeriv(); })
          }
          Scroll() {
            Text(this.derResult.length > 0 ? this.derResult : '（点击「计算」查看差分步骤与切线方程）')
              .fontSize(13).lineHeight(20).fontColor(Theme.textMain())
              .width('100%').textAlign(TextAlign.Start)
          }
          .scrollBar(BarState.Auto).panelStyle()
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding(12)
        .backgroundColor(Theme.card())
        .borderRadius(12)
        .layoutWeight(1)
      }

      if (this.tab === 2) {
        Column({ space: 8 }) {
          Text('∫ f(x)dx 原函数表匹配（符号公式 + 数值抽查）').fontSize(13).fontColor(Theme.textSub())
          Row({ space: 6 }) {
            Text('f(x) =').fontSize(12).fontColor(Theme.textDim())
            TextInput({ text: this.indefExpr, placeholder: '如 sin(x)、x^3、1/x、ln(x)、sqrt(x)' })
              .layoutWeight(1)
              .onChange((v: string) => { this.indefExpr = v; })
          }
          Button('匹配原函数').fontSize(14).backgroundColor(Theme.primary())
            .onClick(() => { this.doIndef(); })
          Scroll() {
            Text(this.indefResult)
              .fontSize(13).lineHeight(20).fontColor(Theme.textMain())
              .width('100%').textAlign(TextAlign.Start)
          }
          .scrollBar(BarState.Auto).panelStyle()
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding(12)
        .backgroundColor(Theme.card())
        .borderRadius(12)
        .layoutWeight(1)
      }

      if (this.tab === 3) {
        Column({ space: 8 }) {
          Text('F(x)=∫[a,x] f(t)dt 变限积分（原函数数值图像）').fontSize(13).fontColor(Theme.textSub())
          Row({ space: 8 }) {
            Text('f(t) =').fontSize(11).fontColor(Theme.textDim())
            TextInput({ text: this.varExpr, placeholder: '用 x 表示 t，如 x^2' })
              .layoutWeight(1).onChange((v: string) => { this.varExpr = v; this.scheduleVarDraw(); })
            Text('下限 a').fontSize(11).fontColor(Theme.textDim())
            TextInput({ text: this.varA, placeholder: 'a' }).width(64)
              .onChange((v: string) => { this.varA = v; this.scheduleVarDraw(); })
          }
          Row({ space: 8 }) {
            Text('F(x₀) x₀=').fontSize(11).fontColor(Theme.textDim())
            TextInput({ text: this.varX, placeholder: 'x₀' }).layoutWeight(1)
              .onChange((v: string) => { this.varX = v; })
            Button('计算').fontSize(14).backgroundColor(Theme.primary())
              .onClick(() => { this.doVar(); })
          }
          if (this.darkMode) {
            this.varCanvas()
          } else {
            this.varCanvas()
          }
          Scroll() {
            Text(this.varResult.length > 0 ? this.varResult : '（修改表达式会自动重绘原函数图像）')
              .fontSize(12).lineHeight(19).fontColor(Theme.textMain()).width('100%')
          }
          .width('100%')
          .height(120)
          .align(Alignment.TopStart)
          .padding(8)
          .backgroundColor(Theme.bgSoft())
          .borderRadius(10)
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding(12)
        .backgroundColor(Theme.card())
        .borderRadius(12)
        .layoutWeight(1)
      }

      if (this.tab === 4) {
        Column({ space: 8 }) {
          Text('Σ f(n) 级数部分和（通项用 x 表示 n，如 1/x^2）').fontSize(13).fontColor(Theme.textSub())
          Row({ space: 6 }) {
            Text('f(n) =').fontSize(12).fontColor(Theme.textDim())
            TextInput({ text: this.serExpr, placeholder: '如 1/x^2、1/x' })
              .layoutWeight(1)
              .onChange((v: string) => { this.serExpr = v; })
          }
          Row({ space: 8 }) {
            Text('起始 n').fontSize(11).fontColor(Theme.textDim())
            TextInput({ text: this.serStart, placeholder: 'n₀' }).layoutWeight(1)
              .onChange((v: string) => { this.serStart = v; })
            Text('项数').fontSize(11).fontColor(Theme.textDim())
            TextInput({ text: this.serCount, placeholder: 'N' }).width(64)
              .onChange((v: string) => { this.serCount = v; })
            Button('求和').fontSize(14).backgroundColor(Theme.primary())
              .onClick(() => { this.doSeries(); })
          }
          Scroll() {
            Text(this.serResult.length > 0 ? this.serResult : '（点击「求和」查看各项与部分和）')
              .fontSize(13).lineHeight(20).fontColor(Theme.textMain())
              .width('100%').textAlign(TextAlign.Start)
          }
          .scrollBar(BarState.Auto).panelStyle()
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding(12)
        .backgroundColor(Theme.card())
        .borderRadius(12)
        .layoutWeight(1)
      }

      if (this.tab === 5) {
        Column({ space: 8 }) {
          Text('Σ f(n) 无穷级数收敛粗判（部分和估计）').fontSize(13).fontColor(Theme.textSub())
          Row({ space: 6 }) {
            Text('f(n) =').fontSize(12).fontColor(Theme.textDim())
            TextInput({ text: this.infExpr, placeholder: '如 1/x^2、1/x、2^(-x)' })
              .layoutWeight(1)
              .onChange((v: string) => { this.infExpr = v; })
          }
          Row({ space: 8 }) {
            Text('起始 n').fontSize(11).fontColor(Theme.textDim())
            TextInput({ text: this.infStart, placeholder: 'n₀' }).layoutWeight(1)
              .onChange((v: string) => { this.infStart = v; })
            Text('最大项').fontSize(11).fontColor(Theme.textDim())
            TextInput({ text: this.infMax, placeholder: 'M' }).width(72)
              .onChange((v: string) => { this.infMax = v; })
            Button('判定').fontSize(14).backgroundColor(Theme.primary())
              .onClick(() => { this.doInfSeries(); })
          }
          Scroll() {
            Text(this.infResult.length > 0 ? this.infResult : '（点击「判定」估计无穷级数的收敛性）')
              .fontSize(13).lineHeight(20).fontColor(Theme.textMain())
              .width('100%').textAlign(TextAlign.Start)
          }
          .scrollBar(BarState.Auto).panelStyle()
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding(12)
        .backgroundColor(Theme.card())
        .borderRadius(12)
        .layoutWeight(1)
      }

      if (this.tab === 6) {
        Column({ space: 8 }) {
          Text('曲线积分 ∫_C [P(x,y)dx + Q(x,y)dy]（沿参数曲线）').fontSize(13).fontColor(Theme.textSub())
          Row({ space: 8 }) {
            Text('P').fontSize(12).fontColor(Theme.textDim())
            TextInput({ text: this.liP, placeholder: 'P(x,y)' }).layoutWeight(1)
              .onChange((v: string) => { this.liP = v; })
            Text('Q').fontSize(12).fontColor(Theme.textDim())
            TextInput({ text: this.liQ, placeholder: 'Q(x,y)' }).layoutWeight(1)
              .onChange((v: string) => { this.liQ = v; })
          }
          Row({ space: 8 }) {
            Text('x(t)').fontSize(12).fontColor(Theme.textDim())
            TextInput({ text: this.liXt, placeholder: 'x(t)' }).layoutWeight(1)
              .onChange((v: string) => { this.liXt = v; })
            Text('y(t)').fontSize(12).fontColor(Theme.textDim())
            TextInput({ text: this.liYt, placeholder: 'y(t)' }).layoutWeight(1)
              .onChange((v: string) => { this.liYt = v; })
          }
          Row({ space: 8 }) {
            Text('t∈[').fontSize(12).fontColor(Theme.textDim())
            TextInput({ text: this.liT0, placeholder: 't0' }).width(70)
              .onChange((v: string) => { this.liT0 = v; })
            Text(',').fontSize(12).fontColor(Theme.textDim())
            TextInput({ text: this.liT1, placeholder: 't1' }).width(70)
              .onChange((v: string) => { this.liT1 = v; })
            Text(']').fontSize(12).fontColor(Theme.textDim())
            Button('计算').fontSize(14).backgroundColor(Theme.primary())
              .onClick(() => { this.doLine(); })
          }
          Scroll() {
            Text(this.liResult.length > 0 ? this.liResult : '（点击「计算」查看参数化与取样过程）')
              .fontSize(13).lineHeight(20).fontColor(Theme.textMain())
              .width('100%').textAlign(TextAlign.Start)
          }
          .scrollBar(BarState.Auto).panelStyle()
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding(12)
        .backgroundColor(Theme.card())
        .borderRadius(12)
        .layoutWeight(1)
      }

      if (this.tab === 7) {
        Column({ space: 8 }) {
          Text('曲面积分 ∬_S g(x,y,z) dS（曲面 z=f(x,y)，S 是 z=f 的曲面块）').fontSize(13).fontColor(Theme.textSub())
          Row({ space: 8 }) {
            Text('g').fontSize(12).fontColor(Theme.textDim())
            TextInput({ text: this.sfG, placeholder: 'g(x,y,z)' }).layoutWeight(1)
              .onChange((v: string) => { this.sfG = v; })
            Text('z=').fontSize(12).fontColor(Theme.textDim())
            TextInput({ text: this.sfZ, placeholder: 'f(x,y)' }).layoutWeight(1)
              .onChange((v: string) => { this.sfZ = v; })
          }
          Row({ space: 8 }) {
            Text('x 区间').fontSize(12).fontColor(Theme.textDim())
            TextInput({ text: this.sfX0, placeholder: 'x0' }).layoutWeight(1)
              .onChange((v: string) => { this.sfX0 = v; })
            Text('~').fontSize(12).fontColor(Theme.textDim())
            TextInput({ text: this.sfX1, placeholder: 'x1' }).layoutWeight(1)
              .onChange((v: string) => { this.sfX1 = v; })
          }
          .width('100%')
          Row({ space: 8 }) {
            Text('y 区间').fontSize(12).fontColor(Theme.textDim())
            TextInput({ text: this.sfY0, placeholder: 'y0' }).layoutWeight(1)
              .onChange((v: string) => { this.sfY0 = v; })
            Text('~').fontSize(12).fontColor(Theme.textDim())
            TextInput({ text: this.sfY1, placeholder: 'y1' }).layoutWeight(1)
              .onChange((v: string) => { this.sfY1 = v; })
            Button('计算').fontSize(14).backgroundColor(Theme.primary())
              .onClick(() => { this.doSurface(); })
          }
          .width('100%')
          Scroll() {
            Text(this.sfResult.length > 0 ? this.sfResult : '（点击「计算」查看面积元素与取样过程）')
              .fontSize(13).lineHeight(20).fontColor(Theme.textMain())
              .width('100%').textAlign(TextAlign.Start)
          }
          .scrollBar(BarState.Auto).panelStyle()
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding(12)
        .backgroundColor(Theme.card())
        .borderRadius(12)
        .layoutWeight(1)
      }

      if (this.tab === 10) {
        Column({ space: 8 }) {
          Text('极限：双侧 / 趋于无穷 的数值逼近').fontSize(13).fontColor(Theme.textSub())
          Row({ space: 6 }) {
            Text('f(x) =').fontSize(12).fontColor(Theme.textDim())
            TextInput({ text: this.limExpr, placeholder: '如 sin(x)/x、(1+1/x)^x' })
              .layoutWeight(1)
              .onChange((v: string) => { this.limExpr = v; })
          }
          Row({ space: 8 }) {
            Text('x →').fontSize(12).fontColor(Theme.textDim())
            TextInput({ text: this.limX, placeholder: '0 或 inf / -inf' })
              .layoutWeight(1).onChange((v: string) => { this.limX = v; })
            Button('求极限').fontSize(14).backgroundColor(Theme.primary())
              .onClick(() => { this.doLimit(); })
          }
          Scroll() {
            Text(this.limResult.length > 0 ? this.limResult : '（输入表达式与趋近点，点击「求极限」）')
              .fontSize(13).lineHeight(19).fontColor(Theme.textMain())
              .width('100%').textAlign(TextAlign.Start)
          }
          .scrollBar(BarState.Auto).panelStyle()

          Divider().strokeWidth(1).color(Theme.border())

          Text('极值：区间驻点扫描 + 二阶导判别').fontSize(13).fontColor(Theme.textSub())
          Row({ space: 6 }) {
            Text('f(x) =').fontSize(12).fontColor(Theme.textDim())
            TextInput({ text: this.extExpr, placeholder: '如 x^3-3*x' })
              .layoutWeight(1)
              .onChange((v: string) => { this.extExpr = v; })
          }
          Row({ space: 8 }) {
            Text('区间').fontSize(12).fontColor(Theme.textDim())
            TextInput({ text: this.extA, placeholder: 'a' })
              .layoutWeight(1).onChange((v: string) => { this.extA = v; })
            Text('~').fontSize(12).fontColor(Theme.textDim())
            TextInput({ text: this.extB, placeholder: 'b' })
              .layoutWeight(1).onChange((v: string) => { this.extB = v; })
            Button('求极值').fontSize(14).backgroundColor(Theme.primary())
              .onClick(() => { this.doExtremum(); })
          }
          Scroll() {
            Text(this.extResult.length > 0 ? this.extResult : '（输入表达式与区间，点击「求极值」）')
              .fontSize(13).lineHeight(19).fontColor(Theme.textMain())
              .width('100%').textAlign(TextAlign.Start)
          }
          .scrollBar(BarState.Auto).panelStyle()
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding(12)
        .backgroundColor(Theme.card())
        .borderRadius(12)
        .layoutWeight(1)
      }

      if (this.tab === 8) {
        Column({ space: 8 }) {
          Text('y\' = f(x,y) 方向场与 RK4 数值解').fontSize(13).fontColor(Theme.textSub())
          Row({ space: 8 }) {
            Text('dy/dx =').fontSize(11).fontColor(Theme.textDim())
            TextInput({ text: this.odeExpr, placeholder: 'f(x,y)，如 x+y、-y*sin(x)' })
              .layoutWeight(1).onChange((v: string) => { this.odeExpr = v; this.scheduleOdeDraw(); })
            Text('y(初值)').fontSize(11).fontColor(Theme.textDim())
            TextInput({ text: this.odeY0, placeholder: 'y₀' }).width(64)
              .onChange((v: string) => { this.odeY0 = v; this.scheduleOdeDraw(); })
          }
          if (this.darkMode) {
            this.odeCanvas()
          } else {
            this.odeCanvas()
          }
          Scroll() {
            Text(this.odeResult.length > 0 ? this.odeResult : '（修改表达式或初值即可查看 RK4 求解步骤）')
              .fontSize(12).lineHeight(19).fontColor(Theme.textMain()).width('100%')
          }
          .width('100%')
          .height(150)
          .align(Alignment.TopStart)
          .padding(8)
          .backgroundColor(Theme.bgSoft())
          .borderRadius(10)
          Text('红色曲线 = RK4 数值解（x 从 -6 到 6）；短线 = 斜率场').fontSize(11).fontColor(Theme.textDim())
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding(12)
        .backgroundColor(Theme.card())
        .borderRadius(12)
        .layoutWeight(1)
      }
    }
    .width('100%')
    .constraintSize({ maxWidth: Responsive.MAX_CALC })
    .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
    .padding({ left: 12, right: 12, top: 8, bottom: 6 })
    .backgroundColor(Theme.bg())
  }

  @Builder
  tabBtn(label: string, idx: number) {
    Text(label)
      .fontSize(13)
      .fontColor(this.tab === idx ? '#FFFFFF' : Theme.chipText())
      .backgroundColor(this.tab === idx ? Theme.primary() : Theme.chipBg())
      .padding({ left: 12, right: 12, top: 4, bottom: 4 })
      .borderRadius(14)
      .onClick(() => {
        this.tab = idx;
        if (idx === 3) {
          this.scheduleVarDraw();
        }
        if (idx === 8) {
          this.scheduleOdeDraw();
        }
      })
  }
}
