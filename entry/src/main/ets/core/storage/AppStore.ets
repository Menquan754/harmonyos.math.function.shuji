/**
 * 本地存储封装：设置项（Preferences）。
 * 采用轻量 Preferences（键值）存储，离线单机运行无需外部数据库。
 */
import { preferences } from '@kit.ArkData';
import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { Theme } from '../theme/Theme';

export class AppSettings {
  remoteEnabled: boolean = false;
  showGrid: boolean = true;
  sampleCount: number = 400;
  darkMode: boolean = false;
  firstLaunch: boolean = true;
  plotPages: string = '';
  showHelp: boolean = true;
}

export class AppStore {
  private static prefs: preferences.Preferences | null = null;
  private static abilityCtx: common.UIAbilityContext | null = null;

  static init(context: common.UIAbilityContext): void {
    AppStore.abilityCtx = context;
    if (AppStore.prefs != null) {
      return;
    }
    try {
      AppStore.prefs = preferences.getPreferencesSync(context, { name: 'xp_settings' });
    } catch (e) {
      console.error(`AppStore init failed: ${JSON.stringify(e)}`);
    }
  }

  static loadSettings(): AppSettings {
    const s: AppSettings = new AppSettings();
    try {
      if (AppStore.prefs == null) {
        return s;
      }
      s.remoteEnabled = AppStore.prefs.getSync('remote_enabled', false) as boolean;
      s.showGrid = AppStore.prefs.getSync('show_grid', true) as boolean;
      s.sampleCount = AppStore.prefs.getSync('sample_count', 400) as number;
      s.darkMode = AppStore.prefs.getSync('dark_mode', false) as boolean;
      s.firstLaunch = AppStore.prefs.getSync('first_launch', true) as boolean;
      s.plotPages = AppStore.prefs.getSync('plot_pages', '') as string;
      s.showHelp = AppStore.prefs.getSync('show_help', true) as boolean;
    } catch (e) {
      console.error(`loadSettings failed: ${JSON.stringify(e)}`);
    }
    return s;
  }

  static saveSettings(s: AppSettings): void {
    try {
      if (AppStore.prefs == null) {
        return;
      }
      AppStore.prefs.putSync('remote_enabled', s.remoteEnabled);
      AppStore.prefs.putSync('show_grid', s.showGrid);
      AppStore.prefs.putSync('sample_count', s.sampleCount);
      AppStore.prefs.putSync('dark_mode', s.darkMode);
      AppStore.prefs.putSync('first_launch', s.firstLaunch);
      AppStore.prefs.putSync('plot_pages', s.plotPages);
      AppStore.prefs.putSync('show_help', s.showHelp);
      AppStore.prefs.flush();
    } catch (e) {
      console.error(`saveSettings failed: ${JSON.stringify(e)}`);
    }
  }

  /** 深色模式：同时切换系统级配色（输入框、弹窗等原生组件一并变深） */
  static setDarkMode(v: boolean): void {
    const s: AppSettings = AppStore.loadSettings();
    s.darkMode = v;
    AppStore.saveSettings(s);
    if (AppStore.abilityCtx != null) {
      try {
        AppStore.abilityCtx.getApplicationContext().setColorMode(
          v ? ConfigurationConstant.ColorMode.COLOR_MODE_DARK : ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT
        );
      } catch (e) {
        console.error(`setColorMode failed: ${JSON.stringify(e)}`);
      }
    }
    Theme.broadcast(v);
  }

  /** 冷启动时同步系统配色 */
  static applyColorMode(): void {
    const dark: boolean = AppStore.getDarkMode();
    AppStore.setDarkMode(dark);
  }

  static getDarkMode(): boolean {
    const s: AppSettings = AppStore.loadSettings();
    return s.darkMode;
  }

  /** 首启标记（指引覆盖层只在首次展示一次） */
  static getFirstLaunch(): boolean {
    const s: AppSettings = AppStore.loadSettings();
    return s.firstLaunch;
  }

  static setGuided(): void {
    const s: AppSettings = AppStore.loadSettings();
    s.firstLaunch = false;
    AppStore.saveSettings(s);
  }

  /** 绘图页数据文件路径（文件存储不受 Preferences 单值长度限制） */
  private static pagesPath(): string {
    if (AppStore.abilityCtx == null) {
      return '';
    }
    return `${AppStore.abilityCtx.filesDir}/plot_pages.json`;
  }

  /** 绘图页组持久化（JSON 字符串）：优先写文件，失败时回退 Preferences */
  static savePlotPages(json: string): void {
    const p: string = AppStore.pagesPath();
    if (p.length > 0) {
      try {
        const f: fs.File = fs.openSync(p, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
        fs.writeSync(f.fd, json);
        fs.closeSync(f);
        return;
      } catch (e) {
        console.error(`savePlotPages(file) failed: ${JSON.stringify(e)}`);
      }
    }
    const s: AppSettings = AppStore.loadSettings();
    s.plotPages = json;
    AppStore.saveSettings(s);
  }

  static loadPlotPages(): string {
    const p: string = AppStore.pagesPath();
    if (p.length > 0) {
      try {
        if (fs.accessSync(p)) {
          const t: string = fs.readTextSync(p);
          if (t.length > 0) {
            return t;
          }
        }
      } catch (e) {
        console.error(`loadPlotPages(file) failed: ${JSON.stringify(e)}`);
      }
    }
    const s: AppSettings = AppStore.loadSettings();
    return s.plotPages;
  }

  /** 悬浮帮助按钮显示状态 */
  static getShowHelp(): boolean {
    return AppStore.loadSettings().showHelp;
  }

  /** 帮助按钮显隐监听（设置页开关 → 主页悬浮按钮实时同步） */
  private static helpCbs: Array<(v: boolean) => void> = [];

  static subscribeHelp(cb: (v: boolean) => void): void {
    if (AppStore.helpCbs.indexOf(cb) < 0) {
      AppStore.helpCbs.push(cb);
    }
  }

  static unsubscribeHelp(cb: (v: boolean) => void): void {
    const i: number = AppStore.helpCbs.indexOf(cb);
    if (i >= 0) {
      AppStore.helpCbs.splice(i, 1);
    }
  }

  static setShowHelp(v: boolean): void {
    const s: AppSettings = AppStore.loadSettings();
    s.showHelp = v;
    AppStore.saveSettings(s);
    for (let i: number = 0; i < AppStore.helpCbs.length; i++) {
      AppStore.helpCbs[i](v);
    }
  }

  /** 悬浮按钮上次拖动位置（-1 表示未设置） */
  static getHelpX(): number {
    if (AppStore.prefs == null) {
      return -1;
    }
    return AppStore.prefs.getSync('help_x', -1) as number;
  }

  static getHelpY(): number {
    if (AppStore.prefs == null) {
      return -1;
    }
    return AppStore.prefs.getSync('help_y', -1) as number;
  }

  static setHelpPos(x: number, y: number): void {
    if (AppStore.prefs == null) {
      return;
    }
    AppStore.prefs.putSync('help_x', x);
    AppStore.prefs.putSync('help_y', y);
    AppStore.prefs.flush();
  }

  /** 一键清空所有应用数据：恢复出厂默认（含绘图页、深色模式、首启指引） */
  static clearAllData(): void {
    const s: AppSettings = AppStore.loadSettings();
    s.remoteEnabled = false;
    s.showGrid = true;
    s.sampleCount = 400;
    s.darkMode = false;
    s.firstLaunch = true;
    s.plotPages = '';
    s.showHelp = true;
    AppStore.saveSettings(s);
    if (AppStore.prefs != null) {
      AppStore.prefs.putSync('help_x', -1);
      AppStore.prefs.putSync('help_y', -1);
      AppStore.prefs.flush();
    }
    const p: string = AppStore.pagesPath();
    if (p.length > 0) {
      try {
        if (fs.accessSync(p)) {
          fs.unlinkSync(p);
        }
      } catch (e) {
        console.error(`clearAllData(pages) failed: ${JSON.stringify(e)}`);
      }
    }
    if (AppStore.abilityCtx != null) {
      try {
        AppStore.abilityCtx.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
      } catch (e) {
        console.error(`clearAllData(colorMode) failed: ${JSON.stringify(e)}`);
      }
    }
    Theme.broadcast(false);
  }
}