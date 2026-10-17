/** @typedef {{ log: (...args: unknown[]) => void }} ConsoleDriver */

/**
 * @param {Pick<Console, "log">} [sink]
 * @returns {ConsoleDriver}
 */
export function createConsole(sink = console) {
  return {
    log: (...args) => sink.log(...args),
  };
}
