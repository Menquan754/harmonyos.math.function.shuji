/**
 * @file hvigorfile.ts
 * @brief Module-level Hvigor build script for the `entry` HAP.
 *
 * Responsibilities
 *   - Registers the `hapTasks` plugin that compiles ArkTS sources, packs
 *     resources and produces the HAP configured in entry/build-profile.json5.
 *   - Stays free of custom plugins, matching the generated project layout.
 *
 * Consumers
 *   - Invoked by hvigor when the entry module is built or installed.
 *
 * @author Menquan754
 * @date 2026-10-31
 */
import { hapTasks } from '@ohos/hvigor-ohos-plugin';

export default {
  system: hapTasks, /* Built-in plugin of Hvigor. It cannot be modified. */
  plugins: []       /* Custom plugin to extend the functionality of Hvigor. */
}