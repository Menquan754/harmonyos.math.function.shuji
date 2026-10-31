/**
 * @file NumericKit.ets
 * @brief Numerical routines for roots, integrals, derivatives, series and ODEs.
 * @author Menquan754
 * @date 2026-10-31
 */

/** 不定积分匹配结果（符号原函数表 + 数值抽查） */
export class IndefResult {
  matched: boolean = false;
  formula: string = '';
  verifyOk: boolean = false;
  samplePoint: number = 1.3;
  sampleF: number = NaN;
  sampleFp: number = NaN;
}

/** 无穷级数粗判结果 */
export class SeriesResult {
  sum: number = NaN;
  converged: boolean = false;
  judgment: string = '';
  partials: number[] = [];
  lastTerm: number = NaN;
  tailN: number = 1;
}

/** 辛普森积分分解结果（含计算步骤文本） */
export class IntegralSteps {
  ok: boolean = false;
  value: number = NaN;
  n: number = 0;
  h: number = NaN;
  fa: number = NaN;
  fb: number = NaN;
  sumOdd: number = NaN;
  sumEven: number = NaN;
  text: string = '';
}

function fmtStep(v: number): string {
  if (!Number.isFinite(v)) {
    return '∞';
  }
  const a: number = Math.abs(v);
  if (a !== 0 && (a >= 1e6 || a < 1e-4)) {
    return v.toExponential(3);
  }
  return Math.round(v * 100000) / 100000 + '';
}

function noFun(x: number): number {
  return NaN;
}

class IndefEntry {
  keys: string[] = [];
  formula: string = '';
  f: (x: number) => number = noFun;
  F: (x: number) => number = noFun;
}

function mkIndef(keys: string[], formula: string, f: (x: number) => number, F: (x: number) => number): IndefEntry {
  const e: IndefEntry = new IndefEntry();
  e.keys = keys;
  e.formula = formula;
  e.f = f;
  e.F = F;
  return e;
}

const INDEF_TABLE: IndefEntry[] = [
  mkIndef(['sin(x)'], '-cos(x) + C',
    (x: number): number => Math.sin(x),
    (x: number): number => -Math.cos(x)),
  mkIndef(['cos(x)'], 'sin(x) + C',
    (x: number): number => Math.cos(x),
    (x: number): number => Math.sin(x)),
  mkIndef(['exp(x)', 'e^x'], 'e^x + C',
    (x: number): number => Math.exp(x),
    (x: number): number => Math.exp(x)),
  mkIndef(['1/x'], 'ln|x| + C',
    (x: number): number => 1 / x,
    (x: number): number => Math.log(Math.abs(x))),
  mkIndef(['ln(x)'], 'x·ln(x) − x + C',
    (x: number): number => Math.log(x),
    (x: number): number => x * Math.log(x) - x),
  mkIndef(['sqrt(x)'], '(2/3)·x^(3/2) + C',
    (x: number): number => Math.sqrt(x),
    (x: number): number => (2 / 3) * Math.pow(x, 1.5)),
  mkIndef(['1/sqrt(x)'], '2·sqrt(x) + C',
    (x: number): number => 1 / Math.sqrt(x),
    (x: number): number => 2 * Math.sqrt(x)),
  mkIndef(['1/(1+x^2)', '1/(x^2+1)'], 'atan(x) + C',
    (x: number): number => 1 / (1 + x * x),
    (x: number): number => Math.atan(x)),
  mkIndef(['1/(1-x^2)'], '(1/2)·ln|(1+x)/(1−x)| + C',
    (x: number): number => 1 / (1 - x * x),
    (x: number): number => 0.5 * Math.log(Math.abs((1 + x) / (1 - x)))),
  mkIndef(['1/cos(x)^2'], 'tan(x) + C',
    (x: number): number => 1 / (Math.cos(x) * Math.cos(x)),
    (x: number): number => Math.tan(x)),
  mkIndef(['1/sin(x)^2'], '-1/tan(x) + C',
    (x: number): number => 1 / (Math.sin(x) * Math.sin(x)),
    (x: number): number => -1 / Math.tan(x))
];

export class NumericKit {
  /** 二分法求 f(x)=0 在 [a,b] 内的实根（要求 f(a)·f(b)<0） */
  static bisect(f: (x: number) => number, a: number, b: number, maxIter: number = 200): number | undefined {
    let lo: number = a;
    let hi: number = b;
    let fLo: number = f(lo);
    for (let i: number = 0; i < maxIter; i++) {
      const mid: number = (lo + hi) / 2;
      const fM: number = f(mid);
      const span: number = Math.abs(hi - lo);
      if (Math.abs(fM) < 1e-12 || span < 1e-12) {
        return mid;
      }
      if (fM * fLo > 0) {
        lo = mid;
        fLo = fM;
      } else {
        hi = mid;
      }
    }
    return (lo + hi) / 2;
  }

  /** 在区间内扫描符号变化并逐个求根 */
  static findRoots(f: (x: number) => number, a: number, b: number, nScan: number = 400): number[] {
    const roots: number[] = [];
    const step: number = (b - a) / nScan;
    let prevX: number = a;
    let prevY: number = f(prevX);
    let guard: number = 0;
    for (let i: number = 1; i <= nScan; i++) {
      const x: number = a + i * step;
      const y: number = f(x);
      guard++;
      if (guard > 2000) {
        break;
      }
      if (Number.isFinite(prevY) && Number.isFinite(y) && prevY * y <= 0) {
        const r: number | undefined = NumericKit.bisect(f, prevX, x);
        if (r !== undefined) {
          roots.push(r);
        }
      }
      prevX = x;
      prevY = y;
    }
    return roots;
  }

  /** 自适应辛普森积分（近似） */
  static simpson(f: (x: number) => number, a: number, b: number, n: number = 2000): number {
    if (n % 2 !== 0) {
      n++;
    }
    const h: number = (b - a) / n;
    let s: number = f(a) + f(b);
    for (let i: number = 1; i < n; i++) {
      const x: number = a + i * h;
      s += (i % 2 === 0 ? 2 : 4) * f(x);
    }
    return s * h / 3;
  }

  /** 辛普森积分分解结果（含计算步骤文本） */
  static simpsonSteps(f: (x: number) => number, a: number, b: number, n: number = 2000): IntegralSteps {
    const r: IntegralSteps = new IntegralSteps();
    if (!Number.isFinite(a) || !Number.isFinite(b) || !Number.isFinite(f(a)) || !Number.isFinite(f(b))) {
      r.ok = false;
      r.text = '区间端点处函数值无定义，无法积分。';
      return r;
    }
    if (n % 2 !== 0) {
      n++;
    }
    const h: number = (b - a) / n;
    const fa: number = f(a);
    const fb: number = f(b);
    let sumOdd: number = 0;
    let sumEven: number = 0;
    for (let i: number = 1; i < n; i++) {
      const x: number = a + i * h;
      const v: number = f(x);
      if (!Number.isFinite(v)) {
        r.ok = false;
        r.text = `第 ${i} 个采样点 x=${fmtStep(x)} 处函数值无定义，请检查表达式。`;
        return r;
      }
      if (i % 2 === 1) {
        sumOdd += v;
      } else {
        sumEven += v;
      }
    }
    const val: number = h / 3 * (fa + fb + 4 * sumOdd + 2 * sumEven);
    r.ok = Number.isFinite(val);
    r.value = val;
    r.n = n;
    r.h = h;
    r.fa = fa;
    r.fb = fb;
    r.sumOdd = sumOdd;
    r.sumEven = sumEven;
    let txt: string = `∫[${fmtStep(a)}, ${fmtStep(b)}] f(x)dx，辛普森法（n=${n} 等分）：\n`;
    txt += `h = (${fmtStep(b)}−${fmtStep(a)})/${n} = ${fmtStep(h)}\n`;
    txt += `f(a) = ${fmtStep(fa)}，f(b) = ${fmtStep(fb)}\n`;
    txt += `Σ奇数点 f = ${fmtStep(sumOdd)}，Σ偶数点 f = ${fmtStep(sumEven)}\n`;
    txt += `S ≈ h/3·[f(a)+f(b)+4·Σ奇+2·Σ偶] = ${fmtStep(val)}`;
    r.text = txt;
    return r;
  }

  /**
   * 曲线积分 ∫[P(x,y)dx + Q(x,y)dy] 沿参数曲线 r(t)=(xt(t), yt(t))，t∈[t0,t1]。
   * pFn/qFn 已按 (x, y) 求值（由调用方构造）；xt/yt 是 (t)=>number 的参数函数。
   */
  static lineIntegral(pFn: (x: number, y: number) => number,
    qFn: (x: number, y: number) => number,
    xt: (t: number) => number, yt: (t: number) => number,
    t0: number, t1: number, n: number = 800): number {
    const integrand = (t: number): number => {
      const x: number = xt(t);
      const y: number = yt(t);
      const dx: number = NumericKit.deriv(xt, t, 1e-5);
      const dy: number = NumericKit.deriv(yt, t, 1e-5);
      const p: number = pFn(x, y);
      const q: number = qFn(x, y);
      return p * dx + q * dy;
    };
    return NumericKit.simpson(integrand, t0, t1, n);
  }

  /**
   * 曲面积分 ∬_S g(x,y,z) dS，其中曲面 z = zFn(x,y)，投影区域 [x0,x1]×[y0,y1]。
   * dS = sqrt(1 + (∂z/∂x)² + (∂z/∂y)²) dxdy。
   */
  static surfaceIntegral(gFn: (x: number, y: number, z: number) => number,
    zFn: (x: number, y: number) => number,
    x0: number, x1: number, y0: number, y1: number, nx: number = 40, ny: number = 40): number {
    const inner = (x: number): number => {
      const innerInt = (y: number): number => {
        const z: number = zFn(x, y);
        const fx: number = NumericKit.deriv((xx: number): number => zFn(xx, y), x, 1e-5);
        const fy: number = NumericKit.deriv((yy: number): number => zFn(x, yy), y, 1e-5);
        const dS: number = Math.sqrt(1 + fx * fx + fy * fy);
        return gFn(x, y, z) * dS;
      };
      return NumericKit.simpson(innerInt, y0, y1, Math.max(4, ny));
    };
    return NumericKit.simpson(inner, x0, x1, Math.max(4, nx));
  }

  /** 中心差分数值导数 */
  static deriv(f: (x: number) => number, x: number, h: number = 1e-6): number {
    return (f(x + h) - f(x - h)) / (2 * h);
  }

  /** 四阶龙格-库塔：y' = f(x, y)，返回 (x, y) 序列 */
  static rk4(fxy: (x: number, y: number) => number, x0: number, y0: number, xEnd: number, n: number): number[][] {
    const out: number[][] = [];
    const h: number = (xEnd - x0) / n;
    let x: number = x0;
    let y: number = y0;
    out.push([x, y]);
    for (let i: number = 0; i < n; i++) {
      const k1: number = fxy(x, y);
      const k2: number = fxy(x + h / 2, y + h * k1 / 2);
      const k3: number = fxy(x + h / 2, y + h * k2 / 2);
      const k4: number = fxy(x + h, y + h * k3);
      y = y + h * (k1 + 2 * k2 + 2 * k3 + k4) / 6;
      x = x + h;
      out.push([x, y]);
    }
    return out;
  }

  /** 方向场网格：返回每个网格点上的斜率 dx/dy */
  static directionField(fxy: (x: number, y: number) => number,
    xMin: number, xMax: number, yMin: number, yMax: number, nx: number, ny: number): number[][][] {
    const cells: number[][][] = [];
    const hx: number = (xMax - xMin) / (nx - 1);
    const hy: number = (yMax - yMin) / (ny - 1);
    for (let i: number = 0; i < nx; i++) {
      const col: number[][] = [];
      const x: number = xMin + i * hx;
      for (let j: number = 0; j < ny; j++) {
        const y: number = yMin + j * hy;
        let s: number = fxy(x, y);
        if (!Number.isFinite(s)) {
          s = 0;
        }
        col.push([x, y, s]);
      }
      cells.push(col);
    }
    return cells;
  }

  private static det3(m: number[][]): number {
    return m[0][0] * (m[1][1] * m[2][2] - m[1][2] * m[2][1])
      - m[0][1] * (m[1][0] * m[2][2] - m[1][2] * m[2][0])
      + m[0][2] * (m[1][0] * m[2][1] - m[1][1] * m[2][0]);
  }

  /** 矩阵行列式（2x2 / 3x3） */
  static determinant(m: number[][]): number {
    if (m.length === 2 && m[0].length === 2) {
      return m[0][0] * m[1][1] - m[0][1] * m[1][0];
    }
    if (m.length === 3 && m[0].length === 3) {
      return NumericKit.det3(m);
    }
    return NaN;
  }

  /** 3x3 伴随矩阵求逆（返回 null 表示不可逆） */
  static inverse3(m: number[][]): number[][] | null {
    const d: number = NumericKit.det3(m);
    if (Math.abs(d) < 1e-12) {
      return null;
    }
    const inv: number[][] = [
      [0, 0, 0],
      [0, 0, 0],
      [0, 0, 0]
    ];
    const cof = (r: number, c: number): number => {
      const rows: number[] = [0, 1, 2].filter((v: number): boolean => v !== r);
      const cols: number[] = [0, 1, 2].filter((v: number): boolean => v !== c);
      return m[rows[0]][cols[0]] * m[rows[1]][cols[1]] - m[rows[0]][cols[1]] * m[rows[1]][cols[0]];
    };
    for (let r: number = 0; r < 3; r++) {
      for (let c: number = 0; c < 3; c++) {
        const sign: number = (r + c) % 2 === 0 ? 1 : -1;
        inv[c][r] = sign * cof(r, c) / d;
      }
    }
    return inv;
  }

  // ---------------- 不定积分（符号原函数表 + 数值抽查） ----------------
  private static verifyIndef(r: IndefResult, f: (x: number) => number, F: (x: number) => number): void {
    const s: number = r.samplePoint;
    const fv: number = f(s);
    const fp: number = NumericKit.deriv(F, s);
    r.sampleF = fv;
    r.sampleFp = fp;
    r.verifyOk = Number.isFinite(fv) && Number.isFinite(fp) &&
      Math.abs(fp - fv) <= 1e-4 * Math.max(1, Math.abs(fv));
  }

  /** 匹配常见函数的不定积分；未命中时 matched=false */
  static indefIntegral(expr: string): IndefResult {
    const r: IndefResult = new IndefResult();
    const norm: string = expr.replace(/\s+/g, '').toLowerCase();
    const pm: RegExpMatchArray | null = norm.match(/^x\^(-?\d+(\.\d+)?)$/);
    if (pm != null) {
      const n: number = parseFloat(norm.substring(2));
      let fX: (x: number) => number;
      let fF: (x: number) => number;
      if (Math.abs(n + 1) < 1e-9) {
        r.formula = 'ln|x| + C';
        fX = (x: number): number => 1 / x;
        fF = (x: number): number => Math.log(Math.abs(x));
      } else {
        r.formula = `x^(${n + 1})/(${n + 1}) + C`;
        fX = (x: number): number => Math.pow(x, n);
        fF = (x: number): number => Math.pow(x, n + 1) / (n + 1);
      }
      r.matched = true;
      NumericKit.verifyIndef(r, fX, fF);
      return r;
    }
    for (let i: number = 0; i < INDEF_TABLE.length; i++) {
      const e: IndefEntry = INDEF_TABLE[i];
      for (let j: number = 0; j < e.keys.length; j++) {
        if (norm === e.keys[j]) {
          r.matched = true;
          r.formula = e.formula;
          NumericKit.verifyIndef(r, e.f, e.F);
          return r;
        }
      }
    }
    return r;
  }

  // ---------------- 级数 ----------------
  /** 部分和序列：S_k = Σ_{i=a}^{a+k-1} f(i)，返回前 count 个部分和 */
  static seriesPartialSums(term: (n: number) => number, a: number, count: number): number[] {
    const sums: number[] = [];
    let s: number = 0;
    for (let i: number = 0; i < count; i++) {
      const t: number = term(a + i);
      if (Number.isFinite(t)) {
        s += t;
      }
      sums.push(s);
    }
    return sums;
  }

  /** 无穷级数收敛粗判：对 Σ f(n) 计算部分和并给出收敛性估计 */
  static infiniteSeries(term: (n: number) => number, a: number, maxN: number): SeriesResult {
    const r: SeriesResult = new SeriesResult();
    let sum: number = 0;
    let lastT: number = NaN;
    let tailN: number = a;
    let diverged: boolean = false;
    let exact: boolean = false;
    for (let i: number = 0; i < maxN; i++) {
      const n: number = a + i;
      const t: number = term(n);
      if (!Number.isFinite(t)) {
        diverged = true;
        break;
      }
      if (Math.abs(t) < 1e-13) {
        sum += t;
        lastT = t;
        tailN = n;
        exact = true;
        break;
      }
      sum += t;
      lastT = t;
      tailN = n;
      if (r.partials.length < 8) {
        r.partials.push(sum);
      }
      if (!Number.isFinite(sum)) {
        diverged = true;
        break;
      }
    }
    r.sum = sum;
    r.lastTerm = lastT;
    r.tailN = tailN;
    if (diverged) {
      r.converged = false;
      r.judgment = '部分和超出数值范围或通项出现无定义点，无法继续求和。';
      return r;
    }
    if (exact) {
      r.converged = true;
      r.judgment = '通项迅速趋于 0，部分和已稳定，判定为收敛。';
      return r;
    }
    // 粗判：尾部 |a_n|·n 明显 ≥ 1 时与调和级数同阶或更慢，疑似发散
    const prod: number = Math.abs(lastT) * Math.max(1, tailN);
    if (prod >= 0.5) {
      r.converged = false;
      r.judgment = '粗判：疑似发散（尾部 |a_n|·n ≥ 0.5，通项衰减速度不高于 1/n）。';
    } else {
      r.converged = true;
      r.judgment = '粗判：通项衰减明显快于 1/n，级数可能收敛（数值估计仅供参考）。';
    }
    return r;
  }
}