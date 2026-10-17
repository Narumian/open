import { compile } from "@jswift/index.js";

const sourceEl = document.getElementById("source");
const outputEl = document.getElementById("output");
const runBtn = document.getElementById("run");

const logs = [];

function run() {
  outputEl.textContent = "";
  logs.length = 0;
  const source = sourceEl.value;

  try {
    const js = compile(source);
    outputEl.textContent += `// generated\n${js}\n\n`;
    const fn = new Function(
      "console",
      `"use strict";\n${js}\nreturn undefined;`,
    );
    fn({
      log: (...args) => {
        const line = args.map((a) => String(a)).join(" ");
        logs.push(line);
        outputEl.textContent += `${line}\n`;
      },
    });
  } catch (err) {
    outputEl.textContent += `Error: ${err.message}\n`;
  }
}

runBtn.addEventListener("click", run);
sourceEl.addEventListener("keydown", (e) => {
  if ((e.metaKey || e.ctrlKey) && e.key === "Enter") {
    e.preventDefault();
    run();
  }
});
