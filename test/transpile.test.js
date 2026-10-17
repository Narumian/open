import test from "node:test";
import assert from "node:assert/strict";
import { compile } from "../src/jswift/index.js";

test("let and print", () => {
  const js = compile("let x = 1\nprint(x)");
  assert.equal(js, "let x = 1;\nconsole.log(x);");
});

test("arithmetic", () => {
  const js = compile("print(2 + 3 * 4)");
  assert.equal(js, "console.log((2 + (3 * 4)));");
});
