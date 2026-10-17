import { tokenize } from "./tokenize.js";
import { parse } from "./parse.js";
import { codegen } from "./codegen.js";
import { JSwiftError } from "./errors.js";

/** @param {string} source Open DSL source */
export function compile(source) {
  const tokens = tokenize(source);
  const ast = parse(tokens);
  return codegen(ast);
}

/**
 * @param {string} source
 * @returns {{ ok: true; js: string } | { ok: false; error: JSwiftError }}
 */
export function compileSafe(source) {
  try {
    const js = compile(source);
    return { ok: true, js };
  } catch (err) {
    if (err instanceof JSwiftError) {
      return { ok: false, error: err };
    }
    return {
      ok: false,
      error: new JSwiftError(err instanceof Error ? err.message : String(err)),
    };
  }
}

export { tokenize, parse, codegen, JSwiftError };
export { createRuntime } from "./runtime.js";
