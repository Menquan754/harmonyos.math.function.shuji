/**
 * 主题工具：基于 AppStorage 的 darkMode 标志返回深浅两套配色。
 * 全部页面/画布统一从这里取色，深色模式下自动切换。
 */
type ThemeListener = (dark: boolean) => void;

export class Theme {
  private static listeners: ThemeListener[] = [];

  static subscribe(cb: ThemeListener): void {
    Theme.listeners.push(cb);
  }

  static unsubscribe(cb: ThemeListener): void {
    const arr: ThemeListener[] = [];
    for (let i: number = 0; i < Theme.listeners.length; i++) {
      if (Theme.listeners[i] !== cb) {
        arr.push(Theme.listeners[i]);
      }
    }
    Theme.listeners = arr;
  }

  /** 切换主题：写 AppStorage 并广播通知所有页面强制刷新 */
  static broadcast(dark: boolean): void {
    AppStorage.setOrCreate<boolean>('darkMode', dark);
    for (let i: number = 0; i < Theme.listeners.length; i++) {
      Theme.listeners[i](dark);
    }
  }

  private static dark(): boolean {
    const v: boolean | undefined = AppStorage.get<boolean>('darkMode');
    return v === true;
  }

  /** 供无法访问 @StorageLink 的代码直接取当前是否深色 */
  static isDark(): boolean {
    return Theme.dark();
  }

  static bg(): string {
    return Theme.dark() ? '#121212' : '#FFFFFF';
  }

  static bgSoft(): string {
    return Theme.dark() ? '#1E1E1E' : '#F7F7F8';
  }

  static card(): string {
    return Theme.dark() ? '#1E1E1E' : '#FFFFFF';
  }

  static textMain(): string {
    return Theme.dark() ? '#E6E6E6' : '#222222';
  }

  static textSub(): string {
    return Theme.dark() ? '#9A9A9A' : '#555555';
  }

  static textDim(): string {
    return Theme.dark() ? '#777777' : '#999999';
  }

  static grid(): string {
    return Theme.dark() ? '#2A2A2A' : '#ECECEC';
  }

  static axis(): string {
    return Theme.dark() ? '#8A8A8A' : '#333333';
  }

  static axisSoft(): string {
    return Theme.dark() ? '#666666' : '#444444';
  }

  static inputBg(): string {
    return Theme.dark() ? '#242424' : '#FFFFFF';
  }

  static chipBg(): string {
    return Theme.dark() ? '#242424' : '#F0F0F0';
  }

  static chipText(): string {
    return Theme.dark() ? '#E6E6E6' : '#333333';
  }

  static primary(): string {
    return '#02743B';
  }

  static accentBlue(): string {
    return '#0267C1';
  }

  static linkBg(): string {
    return Theme.dark() ? '#1A2F45' : '#EAF2FF';
  }

  static tabBarBg(): string {
    return Theme.dark() ? '#181818' : '#FFFFFF';
  }

  static border(): string {
    return Theme.dark() ? '#333333' : '#E0E0E0';
  }

  static floatBg(): string {
    return Theme.dark() ? 'rgba(30,30,30,0.94)' : 'rgba(255,255,255,0.92)';
  }

  static labelBg(): string {
    return Theme.dark() ? '#222222' : '#FFFFFF';
  }

  static danger(): string {
    return '#D22B2B';
  }

  /** 曲线亮色（浅色模式下也可用；深色下保持高对比） */
  static lineColor(hex: string): string {
    return hex;
  }
}
