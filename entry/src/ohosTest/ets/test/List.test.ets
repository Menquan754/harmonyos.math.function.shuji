/**
 * @file List.test.ets
 * @brief Entry point that registers every instrumented test suite.
 *
 * Responsibilities
 *   - Imports each on-device suite and calls it, so `ohosTest` runs discover
 *     all cases from one file.
 *   - Add a new import plus a call here whenever another suite is added.
 *
 * Consumers
 *   - The instrumented test runner, which needs an emulator or a real device.
 *
 * @author Menquan754
 * @date 2026-10-31
 */
import abilityTest from './Ability.test';

export default function testsuite() {
  abilityTest();
}