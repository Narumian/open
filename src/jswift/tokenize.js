import { JSwiftError, syntaxError } from "./errors.js";

const KEYWORDS = new Set([
  "let",
  "var",
  "print",
  "if",
  "else",
  "func",
]);

export function tokenize(source) {
  const tokens = [];
  let i = 0;
  let line = 1;
  let column = 1;

  const at = () => ({ line, column });
  const peek = () => source[i] ?? "";
  const advance = () => {
    const ch = source[i++];
    if (ch === "\n") {
      line += 1;
      column = 1;
    } else {
      column += 1;
    }
    return ch;
  };

  while (i < source.length) {
    const start = at();
    const ch = peek();

    if (ch === " " || ch === "\t" || ch === "\r") {
      advance();
      continue;
    }

    if (ch === "\n") {
      tokens.push({ type: "newline", value: "\n", ...start });
      advance();
      continue;
    }

    if (ch === "/" && source[i + 1] === "/") {
      while (i < source.length && source[i] !== "\n") advance();
      continue;
    }

    if (ch === "(" || ch === ")" || ch === "=" || ch === "{" || ch === "}" || ch === "," || ch === ":") {
      tokens.push({ type: ch, value: ch, ...start });
      advance();
      continue;
    }

    const two = ch + (source[i + 1] ?? "");
    if (two === "==" || two === "!=" || two === "<=" || two === ">=") {
      tokens.push({ type: "op", value: two, ...start });
      advance();
      advance();
      continue;
    }

    if (ch === "+" || ch === "-" || ch === "*" || ch === "/" || ch === "<" || ch === ">") {
      tokens.push({ type: "op", value: ch, ...start });
      advance();
      continue;
    }

    if (ch === '"' || ch === "'") {
      const quote = advance();
      let value = "";
      while (i < source.length && peek() !== quote) {
        if (peek() === "\n") {
          throw new JSwiftError("Unterminated string", { ...start, phase: "tokenize" });
        }
        value += advance();
      }
      if (peek() !== quote) {
        throw new JSwiftError("Unterminated string", { ...start, phase: "tokenize" });
      }
      advance();
      tokens.push({ type: "string", value, ...start });
      continue;
    }

    if (/[0-9]/.test(ch)) {
      let value = "";
      while (i < source.length && /[0-9]/.test(peek())) {
        value += advance();
      }
      tokens.push({ type: "number", value: Number(value), ...start });
      continue;
    }

    if (/[A-Za-z_]/.test(ch)) {
      let value = "";
      while (i < source.length && /[A-Za-z0-9_]/.test(peek())) {
        value += advance();
      }
      if (KEYWORDS.has(value)) {
        tokens.push({ type: value, value, ...start });
      } else {
        tokens.push({ type: "ident", value, ...start });
      }
      continue;
    }

    throw new JSwiftError(`Unexpected character: ${ch}`, { ...start, phase: "tokenize" });
  }

  tokens.push({ type: "eof", value: "", line, column });
  return tokens;
}

export { syntaxError };
