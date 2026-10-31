/**
 * @file PlotEngine.ets
 * @brief Samples expressions into screen curves and maps math to screen coordinates.
 * @author Menquan754
 * @date 2026-10-31
 */
import { ExprEngine } from '../expression/ExprEngine';

export class PlotPoint {
  x: number = 0;       // 数学坐标
  y: number = 0;
  visible: boolean = true; // 断点（无定义/无穷）处断线
}

export class Viewport {
  xMin: number = -10;
  xMax: number = 10;
  yMin: number = -6;
  yMax: number = 6;

  width(): number {
    return this.xMax - this.xMin;
  }

  height(): number {
    return this.yMax - this.yMin;
  }
}

export class PlotEngine {
  /** 采样生成曲线点列 */
  static sample(ast: Object, vp: Viewport, count: number, params: Map<string, number>): PlotPoint[] {
    const out: PlotPoint[] = [];
    if (count < 2) {
      return out;
    }
    const step: number = vp.width() / (count - 1);
    for (let i: number = 0; i < count; i++) {
      const x: number = vp.xMin + i * step;
      const y: number = ExprEngine.evaluate(ast, x, params);
      const p: PlotPoint = new PlotPoint();
      p.x = x;
      p.y = y;
      p.visible = Number.isFinite(y) && Math.abs(y) < 1e15;
      out.push(p);
    }
    return out;
  }
}