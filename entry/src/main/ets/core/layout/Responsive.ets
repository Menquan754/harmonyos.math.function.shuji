/**
 * @file Responsive.ets
 * @brief Single source of truth for phone, tablet and PC breakpoints.
 *
 * Responsibilities
 *   - Defines the width thresholds that choose a navigation shape: PHONE_MAX
 *     (600vp), PC_MIN (1200vp), and SPLIT_MIN (1000vp) for side-by-side views.
 *   - Defines reading limits MAX_TEXT (900vp) and MAX_CALC (1120vp) so forms do
 *     not stretch across very wide windows.
 *   - `level(width)` returns 0 for phone, 1 for tablet and 2 for PC; changing a
 *     number here updates every page at once.
 *
 * Consumers
 *   - pages/Index.ets chooses the tab bar from `level`, PlotPage decides when
 *     to show its formula panel beside the canvas, and every page caps its
 *     content width with MAX_TEXT or MAX_CALC.
 *
 * @author Menquan754
 * @date 2026-10-31
 */
export class Responsive {
  /** 手机上限（vp），小于该值使用底部导航 */
  static readonly PHONE_MAX: number = 600;
  /** PC（2in1）起始宽度（vp），达到后使用宽侧栏与 PC 版比例 */
  static readonly PC_MIN: number = 1200;
  /** 绘图页左右分栏的最小宽度（vp），平板横屏 / PC 使用并排布局 */
  static readonly SPLIT_MIN: number = 1000;
  /** 文本/聊天/设置类内容的最大阅读宽度 */
  static readonly MAX_TEXT: number = 900;
  /** 计算页输入与结果卡片的最大宽度 */
  static readonly MAX_CALC: number = 1120;

  /** 0=手机 1=平板 2=PC */
  static level(w: number): number {
    if (w >= Responsive.PC_MIN) {
      return 2;
    }
    if (w >= Responsive.PHONE_MAX) {
      return 1;
    }
    return 0;
  }
}
