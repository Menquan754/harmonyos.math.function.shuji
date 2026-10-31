/**
 * @file PlotPage.ets
 * @brief Multi-curve function plotter with pan, zoom, sliders and split views.
 * @author Menquan754
 * @date 2026-10-31
 */
import { ExprEngine } from '../../core/expression/ExprEngine';
import { PlotEngine, Viewport, PlotPoint } from '../../core/renderer/PlotEngine';
import { AppStore } from '../../core/storage/AppStore';
import { Theme } from '../../core/theme/Theme';
import { Responsive } from '../../core/layout/Responsive';
import { fileIo as fs, picker } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { image } from '@kit.ImageKit';
import { common } from '@kit.AbilityKit';

class FunctionItem {
  id: number = 0;
  raw: string = '';
  ast: Object = ExprEngine.parseWithParams('x').ast;
  color: string = '#02743B';
  width: number = 2;
  visible: boolean = true;
}

class ParamInfo {
  name: string = '';
  min: number = -10;
  max: number = 10;
  step: number = 0.1;
  value: number = 1;
}

class InspectData {
  active: boolean = false;
  x: number = 0;
  y: number = 0;
}

class InspectVal {
  id: number = 0;
  yv: number = 0;
  color: string = '';
}

/** 动态函数预设（同族函数参数动画） */
class DynPreset {
  label: string = '';
  expr: string = '';
  param: string = '';
  min: number = -3;
  max: number = 3;
  def: number = 1;
}

/** 可序列化的函数条目（用于多页保存） */
class PageFnItem {
  raw: string = '';
  color: string = '#02743B';
  width: number = 2;
  visible: boolean = true;
}

/** 可序列化的参数条目（用于多页保存） */
class PageParamItem {
  name: string = '';
  min: number = -10;
  max: number = 10;
  step: number = 0.1;
  value: number = 1;
}

/** 绘图页数据（视图 + 函数集 + 参数集） */
class PlotPageData {
  name: string = '';
  funcs: PageFnItem[] = [];
  params: PageParamItem[] = [];
  xMin: number = -10;
  xMax: number = 10;
  yMin: number = -6;
  yMax: number = 6;
}

const COLOR_POOL: string[] = [
  '#D22B2B', '#0267C1', '#02743B', '#8A4BFE', '#E88001', '#B64242', '#0F766E', '#7B3F00'
];

const WIDTH_POOL: number[] = [1, 2, 3, 4];

const ANIM_SPEEDS: number[] = [0.5, 1, 2, 3];

/** 绘图页命名 / 重命名弹窗 */
@CustomDialog
struct PageNameDialog {
  controller?: CustomDialogController;
  @State name: string = '';
  onOk: (n: string) => void = (n: string): void => {
  };

  build() {
    Column({ space: 12 }) {
      Text('绘图页名称').fontSize(17).fontWeight(FontWeight.Bold).fontColor(Theme.textMain())
      TextInput({ text: this.name, placeholder: '例如：三角函数对比' })
        .fontColor(Theme.textMain())
        .backgroundColor(Theme.inputBg())
        .borderRadius(8)
        .onChange((v: string) => {
          this.name = v;
        })
      Row({ space: 10 }) {
        Button('取消')
          .fontSize(14)
          .backgroundColor(Theme.chipBg())
          .fontColor(Theme.textMain())
          .layoutWeight(1)
          .onClick(() => {
            this.controller?.close();
          })
        Button('确定')
          .fontSize(14)
          .backgroundColor(Theme.primary())
          .layoutWeight(1)
          .onClick(() => {
            this.onOk(this.name);
            this.controller?.close();
          })
      }
      .width('100%')
    }
    .padding(20)
    .width('86%')
    .backgroundColor(Theme.card())
    .borderRadius(16)
  }
}

const SAMPLES: string[] = ['sin(x)', 'x^2', 'e^x', '1/x', 'a*x*sin(x)', 'x*sin(1/x)', 'x^2 + n', 'sin(x)/x'];

function mkDyn(label: string, expr: string, param: string, min: number, max: number, def: number): DynPreset {
  const p: DynPreset = new DynPreset();
  p.label = label;
  p.expr = expr;
  p.param = param;
  p.min = min;
  p.max = max;
  p.def = def;
  return p;
}

const DYN_PRESETS: DynPreset[] = [
  mkDyn('一次 y=kx+b', 'k*x+b', 'k', -3, 3, 1),
  mkDyn('二次 y=ax²', 'a*x^2', 'a', -3, 3, 1),
  mkDyn('反比例 y=k/x', 'k/x', 'k', -3, 3, 1),
  mkDyn('正弦 y=A sin x', 'A*sin(x)', 'A', -3, 3, 1),
  mkDyn('指数 y=a^x', 'a^x', 'a', 0.2, 3, 2),
  mkDyn('对数 y=log_a x', 'ln(x)/ln(a)', 'a', 0.2, 3, 2)
];

let FN_ID: number = 1;

function fmtNum(v: number): string {
  if (!Number.isFinite(v)) {
    return '∞';
  }
  const a: number = Math.abs(v);
  if (a !== 0 && (a >= 1e6 || a < 1e-4)) {
    return v.toExponential(3);
  }
  return Math.round(v * 100000) / 100000 + '';
}

@Component
export struct PlotPage {
  @State darkMode: boolean = AppStorage.get<boolean>('darkMode') === true;
  @State inputText: string = 'a*sin(x)';
  @State funcs: FunctionItem[] = [];
  @State errorMsg: string = '';
  @State params: ParamInfo[] = [];
  @State splitMode: number = 1; // 0=仅图形 1=图形+公式 2=仅公式
  @State inspect: InspectData = new InspectData();
  @State inspectVals: InspectVal[] = [];
  @State animParam: string = '';
  @State animOn: boolean = false;
  @State animSpeed: number = 1;
  @State pages: PlotPageData[] = [];
  @State curPage: number = 0;
  @State saveTip: string = '';
  @State selColor: string = COLOR_POOL[0];
  @State selWidth: number = 2;
  @State activeFnId: number = -1;
  @State winW: number = 0;
  @State showExport: boolean = false;
  @State exportPm: image.PixelMap | null = null;
  @State exportPath: string = '';

  private vp: Viewport = new Viewport();
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private animTimer: number = -1;
  private inertiaTimer: number = -1;
  private touchData: Map<number, number[]> = new Map<number, number[]>();
  private pinchDist: number = 0;
  private moveAcc: number = 0;
  private lastX: number = 0;
  private lastY: number = 0;
  private lastMoveT: number = 0;
  private vxPx: number = 0;
  private vyPx: number = 0;
  private lastDxP: number = 0;
  private lastDyP: number = 0;
  private totalDxP: number = 0;
  private totalDyP: number = 0;
  private gestureT: number = 0;
  private lastDrawT2: number = 0;
  private resizeTimer: number = -1;
  private nameCtrl: CustomDialogController | null = null;

  private onTheme: (dark: boolean) => void = (dark: boolean): void => {
    this.darkMode = dark;
  };

  // ---------------- 初始化 ----------------
  aboutToAppear(): void {
    Theme.subscribe(this.onTheme);
    this.darkMode = AppStorage.get<boolean>('darkMode') === true;
    const json: string = AppStore.loadPlotPages();
    if (json.length > 0) {
      try {
        const parsed = JSON.parse(json) as PlotPageData[];
        if (parsed != null && parsed.length > 0) {
          const pages: PlotPageData[] = [];
          for (let i: number = 0; i < parsed.length; i++) {
            const src: PlotPageData = parsed[i];
            const pd: PlotPageData = new PlotPageData();
            pd.name = src.name;
            pd.xMin = src.xMin;
            pd.xMax = src.xMax;
            pd.yMin = src.yMin;
            pd.yMax = src.yMax;
            const fns: PageFnItem[] = [];
            for (let j: number = 0; j < src.funcs.length; j++) {
              const sf: PageFnItem = src.funcs[j];
              const fi: PageFnItem = new PageFnItem();
              fi.raw = sf.raw;
              fi.color = sf.color;
              if (sf.width > 0) {
                fi.width = sf.width;
              }
              fi.visible = sf.visible;
              fns.push(fi);
            }
            pd.funcs = fns;
            const pms: PageParamItem[] = [];
            for (let j: number = 0; j < src.params.length; j++) {
              const sp: PageParamItem = src.params[j];
              const pi: PageParamItem = new PageParamItem();
              pi.name = sp.name;
              pi.min = sp.min;
              pi.max = sp.max;
              pi.step = sp.step;
              pi.value = sp.value;
              pms.push(pi);
            }
            pd.params = pms;
            pages.push(pd);
          }
          this.pages = pages;
          this.curPage = 0;
          this.loadPageState(this.pages[0]);
          return;
        }
      } catch (e) {
        console.error(`plot pages load failed: ${JSON.stringify(e)}`);
      }
    }
    // 首次使用：默认页
    const pd: PlotPageData = new PlotPageData();
    pd.name = '绘图页 1';
    this.pages = [pd];
    this.curPage = 0;
    this.addSample('sin(x)');
    this.addSample('x^2');
  }

  aboutToDisappear(): void {
    Theme.unsubscribe(this.onTheme);
    this.stopAnim();
    this.stopInertia();
    if (this.resizeTimer !== -1) {
      clearTimeout(this.resizeTimer);
      this.resizeTimer = -1;
    }
  }

  /** 窗口尺寸变化（PC 拖拽窗口 / 平板旋转）：防抖后重绘画布 */
  private onResize(): void {
    if (this.resizeTimer !== -1) {
      clearTimeout(this.resizeTimer);
    }
    this.resizeTimer = setTimeout(() => {
      this.resizeTimer = -1;
      this.draw();
    }, 60);
  }

  // ---------------- 多页管理 ----------------
  private loadPageState(pd: PlotPageData): void {
    this.stopAnim();
    this.inspect = new InspectData();
    this.activeFnId = -1;
    const nf: FunctionItem[] = [];
    for (let i: number = 0; i < pd.funcs.length; i++) {
      const pf: PageFnItem = pd.funcs[i];
      try {
        const ast: Object = ExprEngine.parseWithParams(pf.raw).ast;
        const item: FunctionItem = new FunctionItem();
        item.id = FN_ID++;
        item.raw = pf.raw;
        item.ast = ast;
        item.color = pf.color;
        item.width = pf.width;
        item.visible = pf.visible;
        nf.push(item);
      } catch (e) {
        console.error(`page fn parse failed: ${pf.raw}`);
      }
    }
    this.funcs = nf;
    const np: ParamInfo[] = [];
    for (let i: number = 0; i < pd.params.length; i++) {
      const pp: PageParamItem = pd.params[i];
      const pi: ParamInfo = new ParamInfo();
      pi.name = pp.name;
      pi.min = pp.min;
      pi.max = pp.max;
      pi.step = pp.step;
      pi.value = pp.value;
      np.push(pi);
    }
    this.params = np;
    this.vp.xMin = pd.xMin;
    this.vp.xMax = pd.xMax;
    this.vp.yMin = pd.yMin;
    this.vp.yMax = pd.yMax;
    this.draw();
  }

  private switchPage(idx: number): void {
    if (idx < 0 || idx >= this.pages.length || idx === this.curPage) {
      return;
    }
    this.curPage = idx;
    this.loadPageState(this.pages[idx]);
  }

  /** 删除当前绘图页 */
  private deletePage(): void {
    if (this.pages.length <= 1) {
      this.saveTip = '至少保留一个绘图页';
      setTimeout(() => {
        this.saveTip = '';
      }, 1500);
      return;
    }
    const rm: number = this.curPage;
    const pages: PlotPageData[] = [];
    for (let i: number = 0; i < this.pages.length; i++) {
      if (i !== rm) {
        pages.push(this.pages[i]);
      }
    }
    this.pages = pages;
    AppStore.savePlotPages(JSON.stringify(this.pages));
    if (this.curPage >= pages.length) {
      this.curPage = pages.length - 1;
    }
    this.loadPageState(pages[this.curPage]);
    this.saveTip = '已删除绘图页';
    setTimeout(() => {
      this.saveTip = '';
    }, 1500);
  }

  /** 点击函数分栏条目：载入到上方编辑框并高亮，便于继续修改 */
  private selectFn(f: FunctionItem): void {
    this.activeFnId = f.id;
    this.inputText = f.raw;
    this.saveTip = `已载入 y = ${f.raw}，可直接编辑`;
    setTimeout(() => {
      this.saveTip = '';
    }, 1600);
  }

  private cycleColor(id: number): void {
    for (let i: number = 0; i < this.funcs.length; i++) {
      if (this.funcs[i].id === id) {
        const c: FunctionItem = this.funcs[i];
        const idx: number = COLOR_POOL.indexOf(c.color);
        c.color = COLOR_POOL[(idx + 1) % COLOR_POOL.length];
        break;
      }
    }
    this.funcs = this.funcs.slice();
    this.draw();
  }

  /** 循环切换函数线宽（点击线宽标记） */
  private cycleWidth(id: number): void {
    for (let i: number = 0; i < this.funcs.length; i++) {
      if (this.funcs[i].id === id) {
        const c: FunctionItem = this.funcs[i];
        const idx: number = WIDTH_POOL.indexOf(c.width);
        c.width = WIDTH_POOL[(idx + 1) % WIDTH_POOL.length];
        break;
      }
    }
    this.funcs = this.funcs.slice();
    this.draw();
  }

  /** 新建绘图页：先弹窗让用户填写页名 */
  private newPage(): void {
    this.askPageName(this.pages.length + 1, false);
  }

  private askPageName(defIdx: number, rename: boolean): void {
    const defName: string = rename && this.curPage < this.pages.length
      ? this.pages[this.curPage].name
      : `绘图页 ${defIdx}`;
    this.nameCtrl = new CustomDialogController({
      builder: PageNameDialog({
        name: defName,
        onOk: (n: string): void => {
          const t: string = n.trim();
          if (rename) {
            this.renamePage(t.length > 0 ? t : defName);
          } else {
            this.createPage(t.length > 0 ? t : defName);
          }
        }
      }),
      autoCancel: true,
      customStyle: true
    });
    this.nameCtrl.open();
  }

  private renamePage(name: string): void {
    if (this.curPage < 0 || this.curPage >= this.pages.length) {
      return;
    }
    this.pages[this.curPage].name = name;
    this.pages = this.pages.slice();
    AppStore.savePlotPages(JSON.stringify(this.pages));
  }

  private createPage(name: string): void {
    this.stopAnim();
    const pd: PlotPageData = new PlotPageData();
    pd.name = name;
    this.pages = this.pages.concat(pd);
    this.curPage = this.pages.length - 1;
    this.funcs = [];
    this.params = [];
    this.inputText = '';
    this.inspect = new InspectData();
    this.inspectVals = [];
    this.activeFnId = -1;
    this.resetView();
    AppStore.savePlotPages(JSON.stringify(this.pages));
    this.saveTip = '';
  }

  private savePage(): void {
    if (this.curPage < 0 || this.curPage >= this.pages.length) {
      return;
    }
    const pd: PlotPageData = this.pages[this.curPage];
    if (pd === undefined) {
      return;
    }
    const fns: PageFnItem[] = [];
    for (let i: number = 0; i < this.funcs.length; i++) {
      const f: FunctionItem = this.funcs[i];
      const fi: PageFnItem = new PageFnItem();
      fi.raw = f.raw;
      fi.color = f.color;
      fi.width = f.width;
      fi.visible = f.visible;
      fns.push(fi);
    }
    const pms: PageParamItem[] = [];
    for (let i: number = 0; i < this.params.length; i++) {
      const p: ParamInfo = this.params[i];
      const pi: PageParamItem = new PageParamItem();
      pi.name = p.name;
      pi.min = p.min;
      pi.max = p.max;
      pi.step = p.step;
      pi.value = p.value;
      pms.push(pi);
    }
    pd.funcs = fns;
    pd.params = pms;
    pd.xMin = this.vp.xMin;
    pd.xMax = this.vp.xMax;
    pd.yMin = this.vp.yMin;
    pd.yMax = this.vp.yMax;
    this.pages = this.pages.slice();
    AppStore.savePlotPages(JSON.stringify(this.pages));
    this.saveTip = '已保存';
    setTimeout(() => {
      this.saveTip = '';
    }, 1500);
  }

  /** 导出当前画布为 PNG：优先生成用户自选位置的图片文件，失败则落盘到应用沙箱 */
  private exportImage(): void {
    if (this.ctx.width <= 0 || this.ctx.height <= 0) {
      return;
    }
    try {
      const dataUrl: string = this.ctx.toDataURL('image/png');
      const comma: number = dataUrl.indexOf(',');
      const b64: string = comma >= 0 ? dataUrl.substring(comma + 1) : dataUrl;
      const helper: util.Base64Helper = new util.Base64Helper();
      const arr: Uint8Array = helper.decodeSync(b64);
      if (arr == null || arr.length === 0) {
        this.tip('导出失败：图像数据为空');
        return;
      }
      const name: string = 'plot_' + new Date().getTime() + '.png';
      const host: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;

      // 系统文件保存选择器：由用户决定保存位置，无需申请存储权限
      const dp: picker.DocumentViewPicker = new picker.DocumentViewPicker(host);
      const opts: picker.DocumentSaveOptions = new picker.DocumentSaveOptions();
      opts.newFileNames = [name];
      dp.save(opts).then((uris: string[]) => {
        if (uris != null && uris.length > 0) {
          try {
            const f = fs.openSync(uris[0], fs.OpenMode.READ_WRITE);
            fs.writeSync(f.fd, arr.buffer);
            fs.closeSync(f);
            this.exportPath = uris[0];
            this.showPreview(arr);
          } catch (e) {
            this.saveToSandbox(arr, name, host);
          }
        } else {
          this.saveToSandbox(arr, name, host);
        }
      }).catch((e: Object) => {
        // 用户取消或选择器不可用时，退回沙箱保存
        this.saveToSandbox(arr, name, host);
      });
    } catch (e) {
      console.error(`export failed: ${JSON.stringify(e)}`);
      this.tip('导出失败，请重试');
    }
  }

  private tip(msg: string): void {
    this.saveTip = msg;
    setTimeout(() => {
      this.saveTip = '';
    }, 1600);
  }

  /** 兜底：写入应用沙箱 files 目录 */
  private saveToSandbox(arr: Uint8Array, name: string, host: common.UIAbilityContext): void {
    try {
      const dir: string = host != null && host.filesDir != null ? host.filesDir : '';
      if (dir.length === 0) {
        this.tip('导出失败：无法获取存储目录');
        return;
      }
      const path: string = dir + '/' + name;
      const file = fs.openSync(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
      fs.writeSync(file.fd, arr.buffer);
      fs.closeSync(file);
      this.exportPath = path;
      this.showPreview(arr);
    } catch (e) {
      this.tip('导出失败，请重试');
    }
  }

  private showPreview(arr: Uint8Array): void {
    const src: image.ImageSource = image.createImageSource(arr.buffer);
    src.createPixelMap().then((pm: image.PixelMap) => {
      if (this.exportPm != null) {
        this.exportPm.release();
      }
      this.exportPm = pm;
      this.showExport = true;
      this.saveTip = '';
    }).catch((e: Object) => {
      this.exportPm = null;
      this.showExport = true;
    });
  }

  private closeExport(): void {
    this.showExport = false;
    if (this.exportPm != null) {
      this.exportPm.release();
      this.exportPm = null;
    }
  }

  // ---------------- 基础函数 ----------------
  private addSample(s: string): void {
    this.inputText = s;
    this.addFn(s);
  }

  private addFn(raw: string): void {
    const trimmed: string = raw.trim();
    this.errorMsg = '';
    if (trimmed.length === 0) {
      return;
    }
    let ast: Object;
    let params: string[];
    try {
      const r = ExprEngine.parseWithParams(trimmed);
      ast = r.ast;
      params = r.params;
    } catch (e) {
      this.errorMsg = `表达式有误：${e instanceof Error ? e.message : '未知错误'}`;
      return;
    }
    const item: FunctionItem = new FunctionItem();
    item.id = FN_ID++;
    item.raw = trimmed;
    item.ast = ast;
    item.color = this.selColor;
    item.width = this.selWidth;
    item.visible = true;
    // 参数面板合并
    const nv: ParamInfo[] = this.params.slice();
    for (let i: number = 0; i < params.length; i++) {
      const name: string = params[i];
      let found: boolean = false;
      for (let j: number = 0; j < nv.length; j++) {
        if (nv[j].name === name) {
          found = true;
          break;
        }
      }
      if (!found) {
        const p: ParamInfo = new ParamInfo();
        p.name = name;
        nv.push(p);
      }
    }
    this.params = nv;
    this.funcs = this.funcs.concat(item);
    this.inspect = new InspectData();
    this.draw();
  }

  /** 动态函数：加载预设并自动播放参数动画 */
  private loadDyn(p: DynPreset): void {
    this.addFn(p.expr);
    for (let i: number = 0; i < this.params.length; i++) {
      if (this.params[i].name === p.param) {
        this.params[i].min = p.min;
        this.params[i].max = p.max;
        this.params[i].value = p.def;
        break;
      }
    }
    this.params = this.params.slice();
    this.playAnim(p.param);
  }

  private removeFn(id: number): void {
    this.funcs = this.funcs.filter((f: FunctionItem): boolean => f.id !== id);
    if (this.activeFnId === id) {
      this.activeFnId = -1;
    }
    if (this.funcs.length === 0) {
      this.inspect = new InspectData();
      this.params = [];
    }
    this.draw();
  }

  private toggleVisible(id: number): void {
    this.funcs = this.funcs.map((f: FunctionItem): FunctionItem => {
      if (f.id === id) {
        f.visible = !f.visible;
      }
      return f;
    });
    this.draw();
  }

  private paramMap(): Map<string, number> {
    const m: Map<string, number> = new Map<string, number>();
    for (let i: number = 0; i < this.params.length; i++) {
      m.set(this.params[i].name, this.params[i].value);
    }
    return m;
  }

  private refreshInspectVals(): void {
    if (!this.inspect.active) {
      this.inspectVals = [];
      return;
    }
    const params: Map<string, number> = this.paramMap();
    const arr: InspectVal[] = [];
    for (let i: number = 0; i < this.funcs.length; i++) {
      const f: FunctionItem = this.funcs[i];
      if (!f.visible) {
        continue;
      }
      const v: InspectVal = new InspectVal();
      v.id = f.id;
      v.color = f.color;
      v.yv = ExprEngine.evaluate(f.ast, this.inspect.x, params);
      arr.push(v);
    }
    this.inspectVals = arr;
  }

  /** 按函数 id 取回表达式文本（数值框标签用） */
  private rawOf(id: number): string {
    for (let i: number = 0; i < this.funcs.length; i++) {
      if (this.funcs[i].id === id) {
        return this.funcs[i].raw;
      }
    }
    return '';
  }

  // ---------------- 动画 ----------------
  private playAnim(name: string): void {
    if (this.animOn && this.animParam === name) {
      this.stopAnim();
      return;
    }
    this.animParam = name;
    this.animOn = true;
    this.restartAnimTimer();
  }

  private restartAnimTimer(): void {
    if (this.animTimer >= 0) {
      clearInterval(this.animTimer);
      this.animTimer = -1;
    }
    const name: string = this.animParam;
    const period: number = Math.max(12, Math.round(40 / this.animSpeed));
    this.animTimer = setInterval(() => {
      for (let i: number = 0; i < this.params.length; i++) {
        if (this.params[i].name === name) {
          let v: number = this.params[i].value + this.params[i].step * 2;
          if (v > this.params[i].max) {
            v = this.params[i].min;
          }
          this.params[i].value = v;
          break;
        }
      }
      this.params = this.params.slice();
      this.draw();
    }, period);
  }

  /** 切换倍速：动画播放中则实时生效 */
  private setAnimSpeed(s: number): void {
    this.animSpeed = s;
    if (this.animOn) {
      this.restartAnimTimer();
    }
  }

  private stopAnim(): void {
    this.animOn = false;
    if (this.animTimer >= 0) {
      clearInterval(this.animTimer);
      this.animTimer = -1;
    }
  }

  // ---------------- 视口 ----------------
  private resetView(): void {
    this.vp.xMin = -10;
    this.vp.xMax = 10;
    this.vp.yMin = -6;
    this.vp.yMax = 6;
    this.inspect = new InspectData();
    this.draw();
  }

  private zoom(factor: number): void {
    const cx: number = this.vp.xMin + this.vp.width() / 2;
    const cy: number = this.vp.yMin + this.vp.height() / 2;
    this.zoomAt(factor, cx, cy);
    this.draw();
  }

  /** 以数据坐标 (ax, ay) 为锚点缩放，双指缩放时对准手指位置 */
  private zoomAt(factor: number, ax: number, ay: number): void {
    const fx: number = this.vp.width() > 0 ? (ax - this.vp.xMin) / this.vp.width() : 0.5;
    const fy: number = this.vp.height() > 0 ? (ay - this.vp.yMin) / this.vp.height() : 0.5;
    const nw: number = this.vp.width() * factor;
    const nh: number = this.vp.height() * factor;
    this.vp.xMin = ax - fx * nw;
    this.vp.xMax = this.vp.xMin + nw;
    this.vp.yMin = ay - fy * nh;
    this.vp.yMax = this.vp.yMin + nh;
  }

  /** 触摸过程中限制刷新频率，避免高频事件拖慢绘制 */
  private drawThrottled(): void {
    const now: number = Date.now();
    if (now - this.lastDrawT2 < 15) {
      return;
    }
    this.lastDrawT2 = now;
    this.draw();
  }

  private autoY(): void {
    const params: Map<string, number> = this.paramMap();
    let yMin: number = Number.POSITIVE_INFINITY;
    let yMax: number = Number.NEGATIVE_INFINITY;
    for (let i: number = 0; i < this.funcs.length; i++) {
      const f: FunctionItem = this.funcs[i];
      const pts: PlotPoint[] = PlotEngine.sample(f.ast, this.vp, this.sampleCount(), params);
      for (let j: number = 0; j < pts.length; j++) {
        if (pts[j].visible) {
          if (pts[j].y < yMin) {
            yMin = pts[j].y;
          }
          if (pts[j].y > yMax) {
            yMax = pts[j].y;
          }
        }
      }
    }
    if (Number.isFinite(yMin) && Number.isFinite(yMax) && yMax > yMin) {
      const pad: number = (yMax - yMin) * 0.12;
      this.vp.yMin = yMin - pad;
      this.vp.yMax = yMax + pad;
      this.draw();
    }
  }

  // ---------------- 画布 ----------------
  private sampleCount(): number {
    return 400;
  }

  private sx(x: number): number {
    const w: number = this.ctx.width;
    const left: number = 44;
    const right: number = 16;
    return left + (x - this.vp.xMin) / this.vp.width() * (w - left - right);
  }

  private sy(y: number): number {
    const h: number = this.ctx.height;
    const top: number = 18;
    const bottom: number = 30;
    return top + (this.vp.yMax - y) / this.vp.height() * (h - top - bottom);
  }

  private xFromS(sxV: number): number {
    const w: number = this.ctx.width;
    const left: number = 44;
    const right: number = 16;
    return this.vp.xMin + (sxV - left) / (w - left - right) * this.vp.width();
  }

  private yFromS(syV: number): number {
    const h: number = this.ctx.height;
    const top: number = 18;
    const bottom: number = 30;
    return this.vp.yMax - (syV - top) / (h - top - bottom) * this.vp.height();
  }

  private niceStep(range: number): number {
    const raw: number = range / 8;
    const pow: number = Math.pow(10, Math.floor(Math.log10(raw)));
    const m: number = raw / pow;
    let nice: number = pow;
    if (m <= 1) {
      nice = pow;
    } else if (m <= 2) {
      nice = 2 * pow;
    } else if (m <= 5) {
      nice = 5 * pow;
    } else {
      nice = 10 * pow;
    }
    return nice;
  }

  private draw(): void {
    this.refreshInspectVals();
    if (this.ctx.width <= 0 || this.ctx.height <= 0) {
      return;
    }
    const w: number = this.ctx.width;
    const h: number = this.ctx.height;
    this.ctx.clearRect(0, 0, w, h);
    // 背景
    this.ctx.fillStyle = Theme.bg();
    this.ctx.fillRect(0, 0, w, h);
    // 网格与刻度
    const xStep: number = this.niceStep(this.vp.width());
    const yStep: number = this.niceStep(this.vp.height());
    this.ctx.lineWidth = 1;
    this.ctx.font = '12px sans-serif';
    this.ctx.textAlign = 'center';
    for (let tx: number = Math.ceil(this.vp.xMin / xStep) * xStep; tx <= this.vp.xMax + 1e-9; tx += xStep) {
      const px: number = this.sx(tx);
      this.ctx.strokeStyle = Theme.grid();
      this.ctx.beginPath();
      this.ctx.moveTo(px, 18);
      this.ctx.lineTo(px, h - 30);
      this.ctx.stroke();
      this.ctx.fillStyle = Theme.textSub();
      this.ctx.fillText(fmtNum(tx), px, h - 14);
    }
    for (let ty: number = Math.ceil(this.vp.yMin / yStep) * yStep; ty <= this.vp.yMax + 1e-9; ty += yStep) {
      const py: number = this.sy(ty);
      this.ctx.strokeStyle = Theme.grid();
      this.ctx.beginPath();
      this.ctx.moveTo(44, py);
      this.ctx.lineTo(w - 16, py);
      this.ctx.stroke();
      this.ctx.fillStyle = Theme.textSub();
      this.ctx.fillText(fmtNum(ty), 40, py + 4);
    }
    // 坐标轴（加粗 + 箭头 + 标签）
    this.ctx.strokeStyle = Theme.axis();
    this.ctx.lineWidth = 1.5;
    const y0: number = this.sy(0);
    const x0: number = this.sx(0);
    const xRight: number = w - 16;
    const yTop: number = 18;
    const inRangeY: boolean = y0 > 18 && y0 < h - 30;
    const inRangeX: boolean = x0 > 44 && x0 < w - 16;
    if (inRangeY) {
      this.ctx.beginPath();
      this.ctx.moveTo(44, y0);
      this.ctx.lineTo(xRight, y0);
      this.ctx.stroke();
      // x 轴箭头
      this.ctx.beginPath();
      this.ctx.moveTo(xRight - 9, y0 - 5);
      this.ctx.lineTo(xRight, y0);
      this.ctx.lineTo(xRight - 9, y0 + 5);
      this.ctx.closePath();
      this.ctx.fillStyle = Theme.axis();
      this.ctx.fill();
      this.ctx.fillStyle = Theme.axis();
      this.ctx.fillText('x', xRight - 2, y0 - 8);
    }
    if (inRangeX) {
      this.ctx.beginPath();
      this.ctx.moveTo(x0, yTop);
      this.ctx.lineTo(x0, h - 30);
      this.ctx.stroke();
      // y 轴箭头
      this.ctx.beginPath();
      this.ctx.moveTo(x0 - 5, yTop + 9);
      this.ctx.lineTo(x0, yTop);
      this.ctx.lineTo(x0 + 5, yTop + 9);
      this.ctx.closePath();
      this.ctx.fillStyle = Theme.axis();
      this.ctx.fill();
      this.ctx.fillStyle = Theme.axis();
      this.ctx.fillText('y', x0 + 8, yTop + 4);
    }
    // 原点标记
    if (inRangeX && inRangeY) {
      this.ctx.fillStyle = Theme.axis();
      this.ctx.fillText('0', x0 - 16, y0 - 6);
    }
    // 曲线
    const params: Map<string, number> = this.paramMap();
    for (let i: number = 0; i < this.funcs.length; i++) {
      const f: FunctionItem = this.funcs[i];
      if (!f.visible) {
        continue;
      }
      const pts: PlotPoint[] = PlotEngine.sample(f.ast, this.vp, this.sampleCount(), params);
      this.ctx.strokeStyle = Theme.lineColor(f.color);
      this.ctx.lineWidth = f.width;
      this.ctx.lineJoin = 'round';
      this.ctx.lineCap = 'round';
      let inSeg: boolean = false;
      this.ctx.beginPath();
      for (let j: number = 0; j < pts.length; j++) {
        if (pts[j].visible) {
          const px: number = this.sx(pts[j].x);
          const py: number = this.sy(pts[j].y);
          if (!inSeg) {
            this.ctx.moveTo(px, py);
            inSeg = true;
          } else {
            this.ctx.lineTo(px, py);
          }
        } else {
          inSeg = false;
        }
      }
      this.ctx.stroke();
    }
    // 选中点光标
    if (this.inspect.active) {
      const cx: number = this.sx(this.inspect.x);
      const cy: number = this.sy(this.inspect.y);
      this.ctx.strokeStyle = Theme.textSub();
      this.ctx.lineWidth = 1;
      this.ctx.setLineDash([4, 3]);
      this.ctx.beginPath();
      this.ctx.moveTo(cx, 18);
      this.ctx.lineTo(cx, h - 30);
      this.ctx.moveTo(44, cy);
      this.ctx.lineTo(w - 16, cy);
      this.ctx.stroke();
      this.ctx.setLineDash([]);
      // 每一条可见函数在该 x 处的点
      for (let i: number = 0; i < this.funcs.length; i++) {
        const f: FunctionItem = this.funcs[i];
        if (!f.visible) {
          continue;
        }
        const yv: number = ExprEngine.evaluate(f.ast, this.inspect.x, params);
        if (Number.isFinite(yv) && yv < 1e8) {
          const px: number = this.sx(this.inspect.x);
          const py: number = this.sy(yv);
          this.ctx.fillStyle = f.color;
          this.ctx.beginPath();
          this.ctx.arc(px, py, 4, 0, 2 * Math.PI);
          this.ctx.fill();
          this.ctx.strokeStyle = Theme.bg();
          this.ctx.lineWidth = 1.5;
          this.ctx.stroke();
        }
      }
      // 坐标浮签（放大字号，框体随文字自适应）
      const label: string = `x = ${fmtNum(this.inspect.x)}  y = ${fmtNum(this.inspect.y)}`;
      this.ctx.font = 'bold 16px sans-serif';
      this.ctx.textAlign = 'left';
      const tw: number = this.ctx.measureText(label).width;
      const bw: number = tw + 20;
      const bh: number = 30;
      const bx: number = Math.min(Math.max(cx - bw / 2, 44), Math.max(44, w - bw - 8));
      const by: number = 18;
      this.ctx.fillStyle = Theme.floatBg();
      this.ctx.fillRect(bx, by, bw, bh);
      this.ctx.strokeStyle = Theme.border();
      this.ctx.strokeRect(bx, by, bw, bh);
      this.ctx.fillStyle = Theme.textMain();
      this.ctx.fillText(label, bx + 10, by + 21);
    }
  }

  // ---------------- 触摸（平移惯性 + 双指缩放 + 点选） ----------------
  private handleTouch(ev: TouchEvent): void {
    // Up 事件可能不带 touches（手指已离开），此时用 lastX/lastY 兜底
    const isUp: boolean = ev.type === TouchType.Up;
    if (!isUp && ev.touches.length < 1) {
      return;
    }
    const t0: TouchObject = ev.touches[0];
    if (ev.type === TouchType.Down) {
      this.stopInertia();
      this.touchData.set(ev.touches.length > 1 ? -1 : 0, [t0.x, t0.y]);
      this.pinchDist = 0;
      this.moveAcc = 0;
      this.lastX = t0.x;
      this.lastY = t0.y;
      this.lastMoveT = Date.now();
      this.gestureT = this.lastMoveT;
      this.vxPx = 0;
      this.vyPx = 0;
      this.lastDxP = 0;
      this.lastDyP = 0;
      this.totalDxP = 0;
      this.totalDyP = 0;
      if (ev.touches.length === 2) {
        const t1: TouchObject = ev.touches[1];
        this.pinchDist = Math.hypot(t0.x - t1.x, t0.y - t1.y);
      }
      return;
    }
    if (ev.type === TouchType.Move) {
      if (ev.touches.length === 2) {
        const t1: TouchObject = ev.touches[1];
        const d: number = Math.hypot(t0.x - t1.x, t0.y - t1.y);
        if (this.pinchDist > 0 && d > 20) {
          // 以两指中点作为缩放锚点，手指指向哪里就放大哪里
          const ratio: number = this.pinchDist / d;
          const mx: number = (t0.x + t1.x) / 2;
          const my: number = (t0.y + t1.y) / 2;
          const ax: number = this.xFromS(mx);
          const ay: number = this.yFromS(my);
          this.zoomAt(ratio, ax, ay);
          this.drawThrottled();
        }
        this.pinchDist = d;
        this.lastX = t0.x;
        this.lastY = t0.y;
        return;
      }
      const prev: number[] | undefined = this.touchData.get(0);
      if (prev !== undefined) {
        const dxP: number = t0.x - prev[0];
        const dyP: number = t0.y - prev[1];
        this.lastDxP = dxP;
        this.lastDyP = dyP;
        this.totalDxP += dxP;
        this.totalDyP += dyP;
        this.moveAcc += Math.abs(dxP) + Math.abs(dyP);
        const w: number = this.ctx.width - 60;
        const h: number = this.ctx.height - 48;
        if (w > 0 && h > 0) {
          const dx: number = -dxP / w * this.vp.width();
          const dy: number = dyP / h * this.vp.height();
          this.vp.xMin += dx;
          this.vp.xMax += dx;
          this.vp.yMin += dy;
          this.vp.yMax += dy;
        }
        // 记录速度（每帧 16ms 归一化），间隔过密时沿用上一次速度，避免数值爆炸
        const now: number = Date.now();
        const dt: number = now - this.lastMoveT;
        if (dt >= 8) {
          const nvx: number = Math.max(-60, Math.min(60, dxP / dt * 16));
          const nvy: number = Math.max(-60, Math.min(60, dyP / dt * 16));
          this.vxPx = this.vxPx * 0.35 + nvx * 0.65;
          this.vyPx = this.vyPx * 0.35 + nvy * 0.65;
          this.lastMoveT = now;
        }
        this.lastX = t0.x;
        this.lastY = t0.y;
        this.touchData.set(0, [t0.x, t0.y]);
        this.drawThrottled();
      }
      return;
    }
    if (ev.type === TouchType.Up) {
      let ux: number = this.lastX;
      let uy: number = this.lastY;
      if (ev.touches.length >= 1) {
        ux = ev.touches[0].x;
        uy = ev.touches[0].y;
      }
      const held: number = Date.now() - this.gestureT;
      if (this.moveAcc < 12 && held < 400) {
        // 视为点选（慢速小幅拖动不触发点选）
        const n: InspectData = new InspectData();
        n.x = this.xFromS(ux);
        n.y = this.yFromS(uy);
        n.active = true;
        this.inspect = n;
        this.draw();
      } else {
        // 平移惯性
        this.startInertia();
      }
      this.touchData.delete(0);
      this.touchData.delete(-1);
      return;
    }
  }

  private startInertia(): void {
    // 慢速拖动直接停住，便于精细对准；只有明确快速滑动才产生惯性
    if (Math.abs(this.vxPx) < 1.5 && Math.abs(this.vyPx) < 1.5) {
      return;
    }
    this.stopInertia();
    this.inertiaTimer = setInterval(() => {
      const w: number = this.ctx.width - 60;
      const h: number = this.ctx.height - 48;
      if (w > 0 && h > 0) {
        const dx: number = -this.vxPx / w * this.vp.width();
        const dy: number = this.vyPx / h * this.vp.height();
        this.vp.xMin += dx;
        this.vp.xMax += dx;
        this.vp.yMin += dy;
        this.vp.yMax += dy;
      }
      // 更柔和的减速：前段滑行更长，尾段自然收住
      this.vxPx *= 0.945;
      this.vyPx *= 0.945;
      this.draw();
      if (Math.abs(this.vxPx) < 0.35 && Math.abs(this.vyPx) < 0.35) {
        this.stopInertia();
      }
    }, 16);
  }

  private stopInertia(): void {
    if (this.inertiaTimer >= 0) {
      clearInterval(this.inertiaTimer);
      this.inertiaTimer = -1;
    }
  }

  // ---------------- UI ----------------
  /** 公式与数值分栏（窄屏在画布下方，宽屏移到右侧） */
  @Builder
  formulaPanel() {
    Column() {
      Row() {
        Text('公式与数值（分栏）').fontSize(13).fontWeight(FontWeight.Medium).fontColor(Theme.textMain())
        Text('拖动平移 · 双指缩放 · 点选读值')
          .fontSize(11)
          .fontColor(Theme.textDim())
          .layoutWeight(1)
          .maxLines(1)
          .textAlign(TextAlign.End)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 6 })

      // 检查点数值表（放在函数列表上方，保证始终可见）
      Column() {
        if (this.inspect.active) {
          Text(`x₀ = ${fmtNum(this.inspect.x)} 处的函数值`).fontSize(12).fontColor(Theme.textSub())
          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
            ForEach(this.inspectVals, (v: InspectVal) => {
              Column({ space: 1 }) {
                Text(this.rawOf(v.id)).fontSize(11).fontColor(Theme.textSub())
                Text(`${fmtNum(v.yv)}`).fontSize(20).fontWeight(FontWeight.Bold).fontColor(v.color)
              }
              .alignItems(HorizontalAlign.Center)
              .padding({ left: 10, right: 10, top: 3, bottom: 4 })
              .backgroundColor(Theme.chipBg())
              .borderRadius(8)
              .margin({ right: 10, top: 6 })
            })
          }
        } else {
          Text('在图上点按任意位置，即可查看该点处所有函数的坐标值').fontSize(12).fontColor(Theme.textDim())
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 12, right: 12, top: 6, bottom: 2 })

      List({ space: 6 }) {
        ForEach(this.funcs, (f: FunctionItem) => {
          ListItem() {
            Row({ space: 8 }) {
              Shape().width(12).height(12).backgroundColor(f.color).borderRadius(6)
                .onClick(() => this.cycleColor(f.id))
              Text(`y = ${f.raw}`).fontSize(13).layoutWeight(1).fontColor(Theme.textMain())
              Text('宽' + f.width).fontSize(10).fontColor(Theme.textDim())
                .padding({ left: 4, right: 4, top: 1, bottom: 1 })
                .backgroundColor(Theme.chipBg())
                .borderRadius(4)
                .onClick(() => this.cycleWidth(f.id))
              Text('●').fontSize(12).fontColor(f.visible ? '#999999' : '#CCCCCC')
                .onClick(() => this.toggleVisible(f.id))
              Text('✕').fontSize(13).fontColor(Theme.danger())
                .onClick(() => this.removeFn(f.id))
            }
            .width('100%')
            .padding({ left: 10, right: 12, top: 5, bottom: 5 })
            .backgroundColor(this.activeFnId === f.id ? Theme.chipBg() : Theme.bgSoft())
            .borderRadius(8)
            .border({
              width: this.activeFnId === f.id ? 1.5 : 0,
              color: Theme.primary()
            })
            .onClick(() => this.selectFn(f))
          }
        })
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .layoutWeight(2)
  }

  @Builder
  plotCanvas() {
    Canvas(this.ctx)
      .width('100%')
      .layoutWeight(this.winW >= Responsive.PHONE_MAX ? 4 : 3)
      .backgroundColor(Theme.bg())
      .onReady(() => {
        this.draw();
      })
      .onAreaChange((o: Area, n: Area) => {
        this.onResize();
      })
      .onTouch((e: TouchEvent) => {
        this.handleTouch(e);
      })
  }

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Column() {
        // 绘图页切换栏
      Row({ space: 6 }) {
        Scroll() {
          Row({ space: 6 }) {
            ForEach(this.pages, (p: PlotPageData, idx: number) => {
              Text(p.name)
                .fontSize(12)
                .fontColor(idx === this.curPage ? '#FFFFFF' : Theme.chipText())
                .backgroundColor(idx === this.curPage ? Theme.primary() : Theme.chipBg())
                .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                .borderRadius(12)
                .onClick(() => {
                  this.switchPage(idx);
                })
            })
          }
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .layoutWeight(1)
        Text('＋').fontSize(16).fontColor(Theme.accentBlue())
          .padding({ left: 6, right: 6 })
          .onClick(() => {
            this.newPage();
          })
        Text('保存').fontSize(12).fontColor(Theme.primary())
          .padding({ left: 6, right: 6 })
          .onClick(() => {
            this.savePage();
          })
        Text('改名').fontSize(12).fontColor(Theme.accentBlue())
          .padding({ left: 6, right: 6 })
          .onClick(() => {
            this.askPageName(this.curPage + 1, true);
          })
        Text('删除页').fontSize(12).fontColor(Theme.danger())
          .padding({ left: 6, right: 6 })
          .onClick(() => {
            this.deletePage();
          })
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 8 })

      if (this.saveTip.length > 0) {
        Text(this.saveTip).fontSize(11).fontColor(Theme.primary()).padding({ left: 12, top: 2 })
      }

      // 输入区
      Row({ space: 8 }) {
        Text('y =').fontSize(14).fontColor(Theme.textSub())
        TextInput({ text: this.inputText, placeholder: '输入函数，如 a*x*sin(x)' })
          .layoutWeight(1)
          .backgroundColor(Theme.inputBg())
          .fontColor(Theme.textMain())
          .onChange((v: string) => {
            this.inputText = v;
          })
          .onSubmit(() => {
            this.addFn(this.inputText);
          })
        Button('添加')
          .fontSize(14)
          .onClick(() => {
            this.addFn(this.inputText);
          })
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 8 })

      // 颜色 / 线宽选择（添加函数时应用，也可在下方列表点色点/线宽循环切换）
      Row({ space: 8 }) {
        Text('颜色').fontSize(12).fontColor(Theme.textDim())
        ForEach(COLOR_POOL, (c: string) => {
          Shape()
            .width(20)
            .height(20)
            .backgroundColor(c)
            .borderRadius(10)
            .border({ width: c === this.selColor ? 2.5 : 1, color: c === this.selColor ? Theme.textMain() : Theme.border() })
            .onClick(() => {
              this.selColor = c;
            })
        })
        Blank()
        Text('线宽').fontSize(12).fontColor(Theme.textDim())
        ForEach(WIDTH_POOL, (wd: number) => {
          Text(`${wd}`)
            .fontSize(12)
            .fontColor(wd === this.selWidth ? '#FFFFFF' : Theme.chipText())
            .backgroundColor(wd === this.selWidth ? Theme.primary() : Theme.chipBg())
            .width(26)
            .height(22)
            .textAlign(TextAlign.Center)
            .borderRadius(6)
            .onClick(() => {
              this.selWidth = wd;
            })
        })
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 8 })

      // 示例快捷按钮
      Row({ space: 6 }) {
        Text('示例:').fontSize(12).fontColor(Theme.textDim())
        Scroll() {
          Row({ space: 6 }) {
            ForEach(SAMPLES, (s: string) => {
              Text(s)
                .fontSize(12)
                .fontColor(Theme.accentBlue())
                .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                .backgroundColor(Theme.linkBg())
                .borderRadius(12)
                .onClick(() => {
                  this.addSample(s);
                })
            })
          }
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 4 })

      // 动态函数
      Row({ space: 6 }) {
        Text('动态:').fontSize(12).fontColor(Theme.textDim())
        Scroll() {
          Row({ space: 6 }) {
            ForEach(DYN_PRESETS, (p: DynPreset) => {
              Text(p.label)
                .fontSize(12)
                .fontColor(this.animOn && this.animParam === p.param ? '#FFFFFF' : Theme.accentBlue())
                .backgroundColor(this.animOn && this.animParam === p.param ? Theme.primary() : Theme.linkBg())
                .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                .borderRadius(12)
                .onClick(() => {
                  this.loadDyn(p);
                })
            })
          }
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 4 })

      if (this.errorMsg.length > 0) {
        Text(this.errorMsg).fontSize(12).fontColor(Theme.danger()).padding({ left: 12, top: 2 })
      }

      // 工具栏：图形 / 图形+公式 / 公式  分栏切换
      Row({ space: 10 }) {
        this.modeBtn('仅图形', 0)
        this.modeBtn('图形+公式', 1)
        this.modeBtn('仅公式', 2)
        Blank()
        Text('导出').fontSize(13).fontColor(Theme.primary())
          .onClick(() => {
            this.exportImage();
          })
        Text('➖').fontSize(18).onClick(() => this.zoom(1.35))
        Text('➕').fontSize(18).onClick(() => this.zoom(0.75))
        Text('⤒').fontSize(16).onClick(() => this.autoY())
        Text('重置').fontSize(13).onClick(() => this.resetView())
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 6 })

      // 参数滑条（位于画布上方，动画播放时始终可见）
      if (this.params.length > 0) {
        Column({ space: 4 }) {
          Row() {
            Text('参数调节').fontSize(13).fontWeight(FontWeight.Medium).fontColor(Theme.textMain())
            Blank()
            if (this.animOn) {
              Text(`动画播放中（${this.animParam}）…`).fontSize(11).fontColor(Theme.primary())
            }
          }
          .width('100%')
          .padding({ left: 12, right: 12 })

          // 动画倍速控制
          Row({ space: 6 }) {
            Text('倍速').fontSize(11).fontColor(Theme.textDim())
            ForEach(ANIM_SPEEDS, (s: number) => {
              Text(`${s}×`)
                .fontSize(11)
                .fontColor(this.animSpeed === s ? '#FFFFFF' : Theme.chipText())
                .backgroundColor(this.animSpeed === s ? Theme.primary() : Theme.chipBg())
                .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                .borderRadius(9)
                .onClick(() => {
                  this.setAnimSpeed(s);
                })
            })
            Blank()
            if (this.animOn) {
              Text('暂停')
                .fontSize(11)
                .fontColor(Theme.danger())
                .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                .backgroundColor(Theme.chipBg())
                .borderRadius(9)
                .onClick(() => {
                  this.stopAnim();
                })
            }
          }
          .width('100%')
          .padding({ left: 12, right: 12 })

          ForEach(this.params, (p: ParamInfo) => {
            Row({ space: 8 }) {
              Text(p.name).fontSize(13).fontColor(Theme.accentBlue()).width(24)
              Slider({
                value: p.value,
                min: p.min,
                max: p.max,
                step: 0.1
              })
                .layoutWeight(1)
                .onChange((v: number) => {
                  if (this.animOn) {
                    return;
                  }
                  p.value = v;
                  this.params = this.params.slice();
                  this.draw();
                })
              Text(fmtNum(p.value)).fontSize(12).fontColor(Theme.textSub()).width(44)
              Text(this.animOn && this.animParam === p.name ? '⏸' : '▶')
                .fontSize(14)
                .fontColor(Theme.primary())
                .onClick(() => {
                  if (this.animOn && this.animParam === p.name) {
                    this.stopAnim();
                  } else {
                    this.playAnim(p.name);
                  }
                })
            }
            .width('100%')
            .padding({ left: 12, right: 12 })
          })
        }
        .padding({ top: 6, bottom: 4 })
        .backgroundColor(Theme.bgSoft())
      }

      // 画布 + 公式分栏：宽屏（平板横屏 / PC）左右并排，窄屏上下堆叠
      if (this.splitMode === 1 && this.winW >= Responsive.SPLIT_MIN) {
        Row({ space: 10 }) {
          Column() {
            if (this.darkMode) {
              this.plotCanvas()
            } else {
              this.plotCanvas()
            }
          }
          .layoutWeight(1)
          .height('100%')

          Column() {
            this.formulaPanel()
          }
          .width(this.winW >= Responsive.PC_MIN ? 380 : 320)
          .height('100%')
          .backgroundColor(Theme.card())
          .borderRadius(10)
          .border({ width: 1, color: Theme.border() })
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 12, right: 12, top: 6 })
      } else {
        if (this.splitMode !== 2) {
          if (this.darkMode) {
            this.plotCanvas()
          } else {
            this.plotCanvas()
          }
        }
        if (this.splitMode !== 0) {
          this.formulaPanel()
        }
      }

      Blank().height(16)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Theme.bg())
      .onAreaChange((o: Area, n: Area) => {
        this.winW = Number(n.width);
        this.onResize();
      })
      // 导出图像预览覆盖层
      if (this.showExport) {
        Column() {
          Text('图像已导出').fontSize(17).fontWeight(FontWeight.Bold).fontColor('#FFFFFF').margin({ bottom: 10 })
          if (this.exportPm != null) {
            Image(this.exportPm)
              .width('82%')
              .height('58%')
              .constraintSize({ maxWidth: 900, maxHeight: 620 })
              .objectFit(ImageFit.Contain)
              .borderRadius(10)
              .backgroundColor('#FFFFFF')
          } else {
            Text('（预览不可用，图片已保存到沙箱）').fontSize(13).fontColor('#BBBBBB')
          }
          Text(this.exportPath)
            .fontSize(11)
            .fontColor('#BBBBBB')
            .textAlign(TextAlign.Center)
            .padding({ left: 20, right: 20, top: 10 })
            .maxLines(2)
          Row({ space: 10 }) {
            Button('关闭')
              .fontSize(14)
              .backgroundColor(Theme.primary())
              .onClick(() => {
                this.closeExport();
              })
          }
          .margin({ top: 12 })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor('rgba(10,10,12,0.72)')
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  modeBtn(label: string, mode: number) {
    Text(label)
      .fontSize(13)
      .fontColor(this.splitMode === mode ? '#FFFFFF' : Theme.chipText())
      .backgroundColor(this.splitMode === mode ? Theme.primary() : Theme.chipBg())
      .padding({ left: 10, right: 10, top: 4, bottom: 4 })
      .borderRadius(14)
      .onClick(() => {
        this.splitMode = mode;
        setTimeout(() => {
          this.draw();
        }, 20);
      })
  }
}
