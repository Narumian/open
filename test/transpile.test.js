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

test("if else", () => {
  const js = compile(
    "if x > 0 {\n  print(x)\n} else {\n  print(0)\n}",
  );
  assert.equal(
    js,
    `if ((x > 0)) {
  console.log(x);
} else {
  console.log(0);
}`,
  );
});

test("func with swift-style params", () => {
  const js = compile(
    "func greet(_ name: String) {\n  print(name)\n}\ngreet(\"hi\")",
  );
  assert.equal(
    js,
    `function greet(name) {
  console.log(name);
}
greet("hi");`,
  );
});

test("func call in expression", () => {
  const js = compile(
    "func add(a: Int, b: Int) {\n  print(a + b)\n}\nadd(1, 2)",
  );
  assert.equal(
    js,
    `function add(a, b) {
  console.log((a + b));
}
add(1, 2);`,
  );
});

test("sleep maps to JSwift.sleep", () => {
  const js = compile("sleep(10)");
  assert.equal(js, "await JSwift.sleep(10);");
});
