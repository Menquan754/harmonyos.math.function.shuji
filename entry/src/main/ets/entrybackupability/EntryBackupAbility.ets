/**
 * @file EntryBackupAbility.ets
 * @brief Backup extension that lets the system save and restore app data.
 *
 * Responsibilities
 *   - Implements the BackupExtensionAbility callbacks `onBackup` and
 *     `onRestore`; both log the event and defer to the default file rules in
 *     resources/base/profile/backup_config.json.
 *   - Allows preferences, saved plot pages and other sandbox files to survive
 *     a device migration or a system backup.
 *
 * Consumers
 *   - Registered as an extension ability in entry/src/main/module.json5. It is
 *     invoked by the system only, never by app code.
 *
 * @author Menquan754
 * @date 2026-10-31
 */
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BackupExtensionAbility, BundleVersion } from '@kit.CoreFileKit';

const DOMAIN = 0x0000;

export default class EntryBackupAbility extends BackupExtensionAbility {
  async onBackup() {
    hilog.info(DOMAIN, 'testTag', 'onBackup ok');
    await Promise.resolve();
  }

  async onRestore(bundleVersion: BundleVersion) {
    hilog.info(DOMAIN, 'testTag', 'onRestore ok %{public}s', JSON.stringify(bundleVersion));
    await Promise.resolve();
  }
}