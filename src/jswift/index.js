import { tokenize } from "./tokenize.js";
import { parse } from "./parse.js";
import { codegen } from "./codegen.js";

/** @param {string} source JSwift source */
export function compile(source) {
  const tokens = tokenize(source);
  const ast = parse(tokens);
  return codegen(ast);
}

export { tokenize, parse, codegen };
