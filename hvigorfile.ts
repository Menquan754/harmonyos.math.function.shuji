/**
 * @file hvigorfile.ts
 * @brief Project-level Hvigor build configuration.
 * @author Menquan754
 * @date 2026-10-31
 */
import { appTasks } from '@ohos/hvigor-ohos-plugin';

export default {
  system: appTasks, /* Built-in plugin of Hvigor. It cannot be modified. */
  plugins: []       /* Custom plugin to extend the functionality of Hvigor. */
}