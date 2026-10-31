/**
 * @file Responsive.ets
 * @brief Breakpoints and layout limits for phone, tablet and PC screens.
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
