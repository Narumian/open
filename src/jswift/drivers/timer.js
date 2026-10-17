/** @typedef {{ sleep: (ms: number) => Promise<void>; now: () => number }} TimerDriver */

/**
 * @param {{ setTimeout?: typeof setTimeout; performance?: Pick<Performance, "now"> }} [host]
 * @returns {TimerDriver}
 */
export function createTimer(host = globalThis) {
  const setTimeoutFn = host.setTimeout ?? setTimeout;
  const performanceObj = host.performance ?? performance;

  return {
    sleep(ms) {
      return new Promise((resolve) => setTimeoutFn(resolve, ms));
    },
    now() {
      return performanceObj.now();
    },
  };
}
