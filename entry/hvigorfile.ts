/**
 * @file hvigorfile.ts
 * @brief HAP module-level Hvigor build configuration.
 * @author Menquan754
 * @date 2026-10-31
 */
import { hapTasks } from '@ohos/hvigor-ohos-plugin';

export default {
  system: hapTasks, /* Built-in plugin of Hvigor. It cannot be modified. */
  plugins: []       /* Custom plugin to extend the functionality of Hvigor. */
}