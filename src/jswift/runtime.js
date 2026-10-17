import { createConsole } from "./drivers/console.js";
import { createTimer } from "./drivers/timer.js";

/**
 * Runtime surface injected into generated JS as `Open`.
 * @param {{ console?: ReturnType<typeof createConsole> }} [parts]
 */
export function createRuntime(parts = {}) {
  const timer = createTimer();
  const consoleDriver = parts.console ?? createConsole();

  return {
    ...consoleDriver,
    sleep: (ms) => timer.sleep(ms),
    now: () => timer.now(),
  };
}
