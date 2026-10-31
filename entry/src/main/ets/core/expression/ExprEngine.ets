/**
 * @file ExprEngine.ets
 * @brief Recursive-descent parser and evaluator for mathematical expressions.
 * @author Menquan754
 * @date 2026-10-31
 *
 * Supports implicit multiplication, pi/e constants, parameters and scientific functions.
 * Pure ArkTS, no third-party dependencies, fully offline.
 */

enum TokKind {
  NUMBER,
  IDENT,
  OP,
  LPAREN,
  RPAREN,
  COMMA,
  END
}

class Token {
  kind: TokKind = TokKind.END;
  text: string = '';
  value: number = 0;
}

class NumNode {
  value: number = 0;
}

class VarNode {
  name: string = '';
}

class BinNode {
  left: Object = new NumNode();
  right: Object = new NumNode();
  op: string = '';
}

class UnNode {
  operand: Object = new NumNode();
  op: string = '';
}

class CallNode {
  fname: string = '';
  arg: Object = new NumNode();
}

export class ParseError extends Error {
  constructor(msg: string) {
    super(msg);
    this.name = 'ParseError';
  }
}

export class ParseResult {
  ast: Object = new NumNode();
  params: string[] = [];
}

const FUNC_NAMES: string[] = [
  'sqrt', 'abs', 'sin', 'cos', 'tan', 'asin', 'acos', 'atan', 'sinh',
  'cosh', 'tanh', 'exp', 'ln', 'log', 'lg', 'floor', 'ceil', 'sign', 'sgn',
  'cot', 'sec', 'csc', 'log2', 'cbrt', 'asinh', 'acosh', 'atanh', 'gamma', 'fact'
];

export class ExprEngine {
  private expr: string = '';
  private pos: number = 0;
  private cur: Token = new Token();
  private params: string[] = [];

  /** 解析并返回 AST 根节点 */
  parseAst(input: string): Object {
    // 规范化常见数学符号，便于直接粘贴公式
    let expr: string = input;
    expr = expr.replace(/π/g, 'pi');
    expr = expr.replace(/×/g, '*');
    expr = expr.replace(/÷/g, '/');
    expr = expr.replace(/−/g, '-');
    this.expr = expr;
    this.pos = 0;
    this.params = [];
    this.cur = this.nextToken();
    const root: Object = this.parseExpr();
    if (this.cur.kind !== TokKind.END) {
      throw new ParseError(`意外的字符 "${this.cur.text}"（位置 ${this.pos}）`);
    }
    return root;
  }

  /** 收集表达式中用到的参数名（不含 x） */
  static collectParams(root: Object, out: string[]): void {
    if (root instanceof NumNode) {
      return;
    }
    if (root instanceof VarNode) {
      const n: string = (root as VarNode).name;
      if (n !== 'x' && n !== 'pi' && n !== 'e' && out.indexOf(n) < 0) {
        out.push(n);
      }
      return;
    }
    if (root instanceof BinNode) {
      ExprEngine.collectParams((root as BinNode).left, out);
      ExprEngine.collectParams((root as BinNode).right, out);
      return;
    }
    if (root instanceof UnNode) {
      ExprEngine.collectParams((root as UnNode).operand, out);
      return;
    }
    if (root instanceof CallNode) {
      ExprEngine.collectParams((root as CallNode).arg, out);
      return;
    }
  }

  /** 求值 AST，env 提供 x 与参数值 */
  static evalNode(node: Object, x: number, params: Map<string, number>): number {
    if (node instanceof NumNode) {
      return (node as NumNode).value;
    }
    if (node instanceof VarNode) {
      const name: string = (node as VarNode).name;
      if (name === 'x') {
        return x;
      }
      if (name === 'pi') {
        return Math.PI;
      }
      if (name === 'e') {
        return Math.E;
      }
      if (params.has(name)) {
        const v: number | undefined = params.get(name);
        if (v !== undefined) {
          return v;
        }
      }
      throw new ParseError(`未定义符号 "${name}"`);
    }
    if (node instanceof BinNode) {
      const b: BinNode = node as BinNode;
      const l: number = ExprEngine.evalNode(b.left, x, params);
      const r: number = ExprEngine.evalNode(b.right, x, params);
      switch (b.op) {
        case '+': return l + r;
        case '-': return l - r;
        case '*': return l * r;
        case '/': return l / r;
        case '^': return Math.pow(l, r);
        default: throw new ParseError(`不支持的运算符 ${b.op}`);
      }
    }
    if (node instanceof UnNode) {
      const u: UnNode = node as UnNode;
      const v: number = ExprEngine.evalNode(u.operand, x, params);
      if (u.op === '+') {
        return v;
      }
      if (u.op === '-') {
        return -v;
      }
      throw new ParseError(`不支持的运算符 ${u.op}`);
    }
    if (node instanceof CallNode) {
      const c: CallNode = node as CallNode;
      const a: number = ExprEngine.evalNode(c.arg, x, params);
      return ExprEngine.applyFunc(c.fname, a);
    }
    throw new ParseError('未知节点类型');
  }

  private static applyFunc(name: string, a: number): number {
    switch (name) {
      case 'sqrt': return Math.sqrt(a);
      case 'abs': return Math.abs(a);
      case 'sin': return Math.sin(a);
      case 'cos': return Math.cos(a);
      case 'tan': return Math.tan(a);
      case 'asin': return Math.asin(a);
      case 'acos': return Math.acos(a);
      case 'atan': return Math.atan(a);
      case 'sinh': return (Math.exp(a) - Math.exp(-a)) / 2;
      case 'cosh': return (Math.exp(a) + Math.exp(-a)) / 2;
      case 'tanh': return (Math.exp(a) - Math.exp(-a)) / (Math.exp(a) + Math.exp(-a));
      case 'exp': return Math.exp(a);
      case 'ln': return Math.log(a);
      case 'log': return Math.log10(a);
      case 'lg': return Math.log10(a);
      case 'floor': return Math.floor(a);
      case 'ceil': return Math.ceil(a);
      case 'sign':
      case 'sgn': return a > 0 ? 1 : (a < 0 ? -1 : 0);
      case 'cot': return Math.cos(a) / Math.sin(a);
      case 'sec': return 1 / Math.cos(a);
      case 'csc': return 1 / Math.sin(a);
      case 'log2': return Math.log(a) / Math.LN2;
      case 'cbrt': return a < 0 ? -Math.pow(-a, 1 / 3) : Math.pow(a, 1 / 3);
      case 'asinh': return Math.log(a + Math.sqrt(a * a + 1));
      case 'acosh': return Math.log(a + Math.sqrt(a * a - 1));
      case 'atanh': return 0.5 * Math.log((1 + a) / (1 - a));
      case 'gamma': return ExprEngine.gammaFn(a);
      case 'fact': return ExprEngine.gammaFn(a + 1);
      default: throw new ParseError(`未知函数 ${name}`);
    }
  }

  /** Lanczos 近似 Γ 函数（支持小数阶乘与 Gamma） */
  private static gammaFn(z: number): number {
    if (z < 0.5) {
      return Math.PI / (Math.sin(Math.PI * z) * ExprEngine.gammaFn(1 - z));
    }
    const coef: number[] = [
      0.99999999999980993, 676.5203681218851, -1259.1392167224028,
      771.32342877765313, -176.61502916214059, 12.507343278686905,
      -0.13857109526572012, 9.9843695780195716e-6, 1.5056327351493116e-7
    ];
    const y: number = z - 1;
    let sum: number = coef[0];
    for (let i: number = 1; i < 9; i++) {
      sum += coef[i] / (y + i);
    }
    const t: number = y + 7.5;
    return Math.sqrt(2 * Math.PI) * Math.pow(t, y + 0.5) * Math.exp(-t) * sum;
  }

  /** 便捷方法：给定表达式与参数映射，在 x 处求值；非有限值返回 NaN */
  static evaluate(ast: Object, x: number, params: Map<string, number>): number {
    try {
      const v: number = ExprEngine.evalNode(ast, x, params);
      if (!Number.isFinite(v)) {
        return NaN;
      }
      return v;
    } catch (e) {
      return NaN;
    }
  }

  // ---------- 词法分析 ----------
  private nextToken(): Token {
    const s: string = this.expr;
    const len: number = s.length;
    while (this.pos < len) {
      const ch: string = s.charAt(this.pos);
      if (ch === ' ' || ch === '\t' || ch === '\n' || ch === '\r') {
        this.pos++;
        continue;
      }
      break;
    }
    const t: Token = new Token();
    if (this.pos >= len) {
      t.kind = TokKind.END;
      return t;
    }
    const ch: string = s.charAt(this.pos);
    if (ch >= '0' && ch <= '9' || ch === '.') {
      let num: string = '';
      let hasDot: boolean = false;
      while (this.pos < len) {
        const c: string = s.charAt(this.pos);
        if (c >= '0' && c <= '9') {
          num += c;
          this.pos++;
        } else if (c === '.' && !hasDot) {
          num += c;
          hasDot = true;
          this.pos++;
        } else {
          break;
        }
      }
      if (num === '.' || num === '') {
        throw new ParseError(`无效数字（位置 ${this.pos}）`);
      }
      t.kind = TokKind.NUMBER;
      t.value = parseFloat(num);
      t.text = num;
      return t;
    }
    if (ch >= 'a' && ch <= 'z' || ch >= 'A' && ch <= 'Z' || ch === '_') {
      let id: string = '';
      while (this.pos < len) {
        const c: string = s.charAt(this.pos);
        if (c >= 'a' && c <= 'z' || c >= 'A' && c <= 'Z' || c === '_' || (c >= '0' && c <= '9')) {
          id += c;
          this.pos++;
        } else {
          break;
        }
      }
      t.kind = TokKind.IDENT;
      t.text = id;
      return t;
    }
    this.pos++;
    t.text = ch;
    switch (ch) {
      case '+':
      case '-':
      case '*':
      case '/':
      case '^':
        t.kind = TokKind.OP;
        return t;
      case '(':
        t.kind = TokKind.LPAREN;
        return t;
      case ')':
        t.kind = TokKind.RPAREN;
        return t;
      case ',':
        t.kind = TokKind.COMMA;
        return t;
      default:
        throw new ParseError(`无法识别的字符 "${ch}"`);
    }
  }

  // ---------- 语法分析（递归下降） ----------
  private parseExpr(): Object {
    let left: Object = this.parseTerm();
    while (this.cur.kind === TokKind.OP && (this.cur.text === '+' || this.cur.text === '-')) {
      const op: string = this.cur.text;
      this.cur = this.nextToken();
      const right: Object = this.parseTerm();
      const b: BinNode = new BinNode();
      b.op = op;
      b.left = left;
      b.right = right;
      left = b;
    }
    return left;
  }

  private parseTerm(): Object {
    let left: Object = this.parseFactor();
    while (true) {
      if (this.cur.kind === TokKind.OP && (this.cur.text === '*' || this.cur.text === '/')) {
        const op: string = this.cur.text;
        this.cur = this.nextToken();
        const right: Object = this.parseFactor();
        const b: BinNode = new BinNode();
        b.op = op;
        b.left = left;
        b.right = right;
        left = b;
      } else if (this.startsPrimary()) {
        // 隐式乘法：2x、3sin(x)、(x+1)(x-1)
        const right: Object = this.parseFactor();
        const b: BinNode = new BinNode();
        b.op = '*';
        b.left = left;
        b.right = right;
        left = b;
      } else {
        break;
      }
    }
    return left;
  }

  private parseFactor(): Object {
    // 幂次右结合：-x^2、2^-x、sin(x)^2
    const base: Object = this.parseUnary();
    if (this.cur.kind === TokKind.OP && this.cur.text === '^') {
      this.cur = this.nextToken();
      const power: Object = this.parseFactor();
      const b: BinNode = new BinNode();
      b.op = '^';
      b.left = base;
      b.right = power;
      return b;
    }
    return base;
  }

  private parseUnary(): Object {
    if (this.cur.kind === TokKind.OP && (this.cur.text === '-' || this.cur.text === '+')) {
      const op: string = this.cur.text;
      this.cur = this.nextToken();
      const inner: Object = this.parseUnary();
      const u: UnNode = new UnNode();
      u.op = op;
      u.operand = inner;
      return u;
    }
    return this.parsePrimary();
  }

  private startsPrimary(): boolean {
    if (this.cur.kind === TokKind.NUMBER || this.cur.kind === TokKind.LPAREN) {
      return true;
    }
    if (this.cur.kind === TokKind.IDENT) {
      // 参数/未知标识符 后跟内容 → 视为乘法因子；函数调用 → 也成立（如 xsin(x)）
      return true;
    }
    return false;
  }

  private parsePrimary(): Object {
    const t: Token = this.cur;
    if (t.kind === TokKind.NUMBER) {
      this.cur = this.nextToken();
      const n: NumNode = new NumNode();
      n.value = t.value;
      return n;
    }
    if (t.kind === TokKind.LPAREN) {
      this.cur = this.nextToken();
      const inner: Object = this.parseExpr();
      if (this.cur.kind !== TokKind.RPAREN) {
        throw new ParseError('缺少右括号 ")"');
      }
      this.cur = this.nextToken();
      return inner;
    }
    if (t.kind === TokKind.IDENT) {
      const name: string = t.text;
      this.cur = this.nextToken();
      const low: string = name.toLowerCase();
      if (low === 'pi') {
        const n: NumNode = new NumNode();
        n.value = Math.PI;
        return n;
      }
      if (low === 'e') {
        const n: NumNode = new NumNode();
        n.value = Math.E;
        return n;
      }
      if (low === 'x') {
        const v: VarNode = new VarNode();
        v.name = 'x';
        return v;
      }
      if (FUNC_NAMES.indexOf(low) >= 0) {
        if (this.cur.kind !== TokKind.LPAREN) {
          throw new ParseError(`函数 ${name} 需要参数，如 ${name}(x)`);
        }
        this.cur = this.nextToken();
        const arg: Object = this.parseExpr();
        if (this.cur.kind !== TokKind.RPAREN) {
          throw new ParseError(`函数 ${name} 缺少右括号`);
        }
        this.cur = this.nextToken();
        const c: CallNode = new CallNode();
        c.fname = low;
        c.arg = arg;
        return c;
      }
      // 用户自定义符号参数
      const v: VarNode = new VarNode();
      v.name = name;
      if (this.params.indexOf(name) < 0) {
        this.params.push(name);
      }
      return v;
    }
    throw new ParseError(`意外的词法单元 "${t.text}"`);
  }

  /** 解析得到 AST 并收集参数名（不含 x 与常量） */
  static parseWithParams(exprStr: string): ParseResult {
    const engine: ExprEngine = new ExprEngine();
    const ast: Object = engine.parseAst(exprStr);
    const params: string[] = [];
    ExprEngine.collectParams(ast, params);
    const r: ParseResult = new ParseResult();
    r.ast = ast;
    r.params = params;
    return r;
  }
}