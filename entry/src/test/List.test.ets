/**
 * @file List.test.ets
 * @brief Entry point that registers every local unit test suite.
 *
 * Responsibilities
 *   - Imports each local suite and calls it, so the test runner can discover
 *     all cases from one file.
 *   - Add a new import plus a call here whenever another local suite is added.
 *
 * Consumers
 *   - The local (on-host) unit test runner of the entry module.
 *
 * @author Menquan754
 * @date 2026-10-31
 */
import localUnitTest from './LocalUnit.test';

export default function testsuite() {
  localUnitTest();
}