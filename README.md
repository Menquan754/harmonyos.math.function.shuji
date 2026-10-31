# Shuji (数迹)

**An offline HarmonyOS math app for plotting functions, computing advanced math step by step, and learning on the go.**

Shuji (Chinese: 数迹, "math traces") is a single-module HarmonyOS application built with ArkTS and the Stage model. It targets students and anyone who wants a fast, private math workbench on a phone, tablet, or PC (2-in-1). Everything runs on-device: no network requests, no accounts, no ads, no analytics.

---

## Highlights

- **Function plotting** - multiple curves in one coordinate system, parameter sliders, gestures, point inspection, and parameter animations.
- **Step-by-step calculus** - roots, definite/indefinite integrals, variable-limit integrals, series, line/surface integrals, direction fields, derivatives, limits, and extrema.
- **Offline knowledge assistant (Xiao Pai)** - 120+ built-in math Q&A entries with Chinese/English keyword matching.
- **Three-device responsive layout** - bottom navigation on phones, a compact side rail on tablets, and an expanded side rail with descriptions on PC.
- **Dark mode and local persistence** - theme, floating help button, and multiple named plot pages are stored locally.

---

## Repository structure

```text
.
|-- AppScope/
|   |-- app.json5                        # Bundle name, version, icon and label
|   `-- resources/base/
|       |-- element/string.json          # App display name
|       `-- media/
|           |-- background.png           # Layered icon background
|           |-- foreground.png           # Layered icon foreground
|           `-- layered_image.json       # Layered icon descriptor
|-- entry/
|   |-- build-profile.json5              # Module build options (no signing data)
|   |-- hvigorfile.ts                    # HAP build task definition
|   |-- obfuscation-rules.txt            # Release obfuscation rules
|   |-- oh-package.json5                 # Module dependency manifest
|   `-- src/
|       |-- main/
|       |   |-- module.json5             # Entry module, abilities, device types
|       |   |-- ets/
|       |   |   |-- entryability/
|       |   |   |   `-- EntryAbility.ets            # App entry; loads pages/Index
|       |   |   |-- entrybackupability/
|       |   |   |   `-- EntryBackupAbility.ets      # Backup extension ability
|       |   |   |-- core/
|       |   |   |   |-- agent/AgentCore.ets         # Intent routing and reply building
|       |   |   |   |-- agent/KnowledgeBase.ets     # Built-in offline Q&A entries
|       |   |   |   |-- expression/ExprEngine.ets  # Expression parser and evaluator
|       |   |   |   |-- layout/Responsive.ets       # Phone/tablet/PC breakpoints
|       |   |   |   |-- numeric/NumericKit.ets      # Roots, integrals, series, RK4
|       |   |   |   |-- renderer/PlotEngine.ets     # Curve sampling and transforms
|       |   |   |   |-- storage/AppStore.ets        # Preferences and saved plot pages
|       |   |   |   `-- theme/Theme.ets             # Light/dark color palettes
|       |   |   `-- pages/
|       |   |       |-- Index.ets                   # Root shell and navigation
|       |   |       |-- plot/PlotPage.ets           # Multi-curve function plotter
|       |   |       |-- agent/AgentPage.ets         # Xiao Pai chat screen
|       |   |       |-- calc/CalcPage.ets           # Eleven numeric tools
|       |   |       |-- settings/SettingsPage.ets   # Theme, help, data reset
|       |   |       `-- guide/GuidePage.ets         # Onboarding overlay
|       |   |-- resources/               # Strings, colors, icons, page list
|       |   `-- mock/mock-config.json5   # Mock configuration for local tests
|       |-- test/                        # Local unit tests
|       `-- ohosTest/                    # Instrumented tests
|-- hvigor/
|   `-- hvigor-config.json5              # Hvigor runtime options
|-- hvigorfile.ts                       # Project-level build script
|-- build-profile.json5                 # App products and build modes (unsigned)
|-- oh-package.json5                    # Root dependency manifest
|-- oh-package-lock.json5               # Locked dependency versions (reproducible)
|-- code-linter.json5                   # Static analysis rules
|-- LICENSE                             # Apache License 2.0
`-- .gitignore                          # Build, IDE, signing and cache exclusions
```

---

## Requirements

| Item | Value |
| --- | --- |
| IDE | DevEco Studio 6.1.1 or newer |
| Compatible SDK | HarmonyOS 6.1.1 (API 24) |
| Target SDK | 26.0.0 |
| Language | ArkTS (strict mode) |
| Device types | `phone`, `tablet`, `2in1` |
| Runtime | Stage model, single `entry` HAP, fully offline |

---

## How to Run

The repository intentionally contains **no signing material**. iOS-style "double click to run" does not exist for HarmonyOS; a signature is required.

1. **Open the project** - In DevEco Studio choose `File > Open` and select the repository root (the folder containing `build-profile.json5`). Wait for the project sync to finish.
2. **Enable automatic signing** - Go to `File > Project Structure > Signing Configs`, sign in with your Huawei ID, and tick **Automatically generate signature**. DevEco Studio creates a debug certificate in your local environment. Do not commit the generated `.p12`, `.cer`, or `.p7b` files.
3. **Run** - Select the `entry` module, choose a phone/tablet/2-in-1 emulator or a connected device, and click **Run**.

That is the whole flow: **Open -> Auto-sign -> Run**.

### Dependency sync

`oh-package-lock.json5` is tracked to keep dependency versions reproducible. If the IDE does not sync automatically, run:

```bash
ohpm install
```

### Command-line build

```bash
hvigorw assembleHap --mode module -p product=default -p buildMode=debug --no-daemon
```

The unsigned artifact is written to:

```text
entry/build/default/outputs/default/entry-default-unsigned.hap
```

---

## Responsive layout

| Device | Window width | Navigation | Content layout |
| --- | --- | --- | --- |
| Phone | `< 600vp` | Bottom tabs | Full-width; plot canvas and formula panel stacked 3:2 |
| Tablet | `600-1199vp` | Left rail, 96vp | Centered and width-limited; plot side-by-side when `>= 1000vp` |
| PC / 2-in-1 | `>= 1200vp` | Left rail, 200vp, with descriptions | Plot side-by-side; settings/chat 900vp, calculator 1120vp |

The breakpoints live in `entry/src/main/ets/core/layout/Responsive.ets`. Window resizing and tablet rotation are handled through `window.on('windowSizeChange')` in `Index.ets`.

---

## Calculation tools

The calculator tab provides eleven independent tools, each with a step-by-step explanation:

1. Root finding (interval scan + bisection)
2. Definite integral (composite Simpson + convergence check)
3. Indefinite integral (built-in antiderivative table + numeric spot check)
4. Variable-limit integral (with a plotted accumulation function)
5. Finite series partial sums
6. Infinite series (partial sums and convergence screening)
7. Line integral
8. Surface integral
9. Direction field with RK4 integration
10. Derivative at a point (central difference)
11. Limits and extrema (two-sided sampling, stationary points, second-derivative test)

---

## Privacy

- No `requestPermissions` entries in `entry/src/main/module.json5`.
- No network access, no telemetry, no third-party SDKs.
- Settings and plot pages are stored in the app sandbox only. Users can erase them via **Settings -> Clear data**.

---

## Source header convention

Every `.ets` and `.ts` file starts with a short English header:

```ts
/**
 * @file CalcPage.ets
 * @brief Calculation workspace with eleven numeric tools and step-by-step output.
 * @author Menquan754
 * @date 2026-10-31
 */
```

- `@file` - file name.
- `@brief` - one sentence, at most 15 English words.
- `@author` - maintainer name.
- `@date` - creation or last meaningful update date (`YYYY-MM-DD`).

---

## License

Licensed under the Apache License 2.0. See [LICENSE](LICENSE) for details.
