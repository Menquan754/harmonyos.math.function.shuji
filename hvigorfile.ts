/**
 * @file hvigorfile.ts
 * @brief Project-level Hvigor build script.
 *
 * Responsibilities
 *   - Registers the built-in `appTasks` plugin, which assembles every module of
 *     the project; `plugins` is where custom build extensions would be added.
 *   - Keeps no build options of its own: products, signing and build modes live
 *     in build-profile.json5, while runtime options live in hvigor/hvigor-config.json5.
 *
 * Consumers
 *   - Invoked by hvigor (through DevEco Studio or the bundled CLI) before any
 *     module is built.
 *
 * @author Menquan754
 * @date 2026-10-31
 */
import { appTasks } from '@ohos/hvigor-ohos-plugin';

export default {
  system: appTasks, /* Built-in plugin of Hvigor. It cannot be modified. */
  plugins: []       /* Custom plugin to extend the functionality of Hvigor. */
}