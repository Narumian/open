import { compileSafe, JSwiftError } from "@jswift/index.js";
import { createRuntime } from "@jswift/runtime.js";
import { createConsole } from "@jswift/drivers/console.js";

const sourceEl = document.getElementById("source");
const outputEl = document.getElementById("output");
const runBtn = document.getElementById("run");

const logs = [];

function formatError(err) {
  if (err instanceof JSwiftError) {
    return err.format();
  }
  return `runtime error: ${err.message}`;
}

async function run() {
  outputEl.textContent = "";
  logs.length = 0;
  const source = sourceEl.value;

  const result = compileSafe(source);
  if (!result.ok) {
    outputEl.textContent = `${result.error.format()}\n`;
    return;
  }

  const js = result.js;
  outputEl.textContent += `// generated\n${js}\n\n`;

  const JSwift = createRuntime({
    console: createConsole({
      log: (...args) => {
        const line = args.map((a) => String(a)).join(" ");
        logs.push(line);
        outputEl.textContent += `${line}\n`;
      },
    }),
  });

  try {
    const fn = new Function(
      "JSwift",
      "console",
      `"use strict";\nreturn (async () => {\n${js}\n})();`,
    );
    await fn(JSwift, console);
  } catch (err) {
    outputEl.textContent += `${formatError(err)}\n`;
  }
}

runBtn.addEventListener("click", () => {
  void run();
});
sourceEl.addEventListener("keydown", (e) => {
  if ((e.metaKey || e.ctrlKey) && e.key === "Enter") {
    e.preventDefault();
    void run();
  }
});
