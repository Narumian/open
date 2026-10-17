const KEYWORDS = new Set(["let", "var", "print"]);

export function tokenize(source) {
  const tokens = [];
  let i = 0;

  const peek = () => source[i] ?? "";
  const advance = () => source[i++];

  while (i < source.length) {
    const ch = peek();

    if (ch === " " || ch === "\t" || ch === "\r") {
      advance();
      continue;
    }

    if (ch === "\n") {
      tokens.push({ type: "newline", value: "\n" });
      advance();
      continue;
    }

    if (ch === "/" && source[i + 1] === "/") {
      while (i < source.length && source[i] !== "\n") advance();
      continue;
    }

    if (ch === "(" || ch === ")" || ch === "=") {
      tokens.push({ type: ch, value: ch });
      advance();
      continue;
    }

    if ("+-*/".includes(ch)) {
      tokens.push({ type: "op", value: ch });
      advance();
      continue;
    }

    if (ch === '"' || ch === "'") {
      const quote = advance();
      let value = "";
      while (i < source.length && peek() !== quote) {
        value += advance();
      }
      if (peek() !== quote) {
        throw new Error("Unterminated string");
      }
      advance();
      tokens.push({ type: "string", value });
      continue;
    }

    if (/[0-9]/.test(ch)) {
      let value = "";
      while (i < source.length && /[0-9]/.test(peek())) {
        value += advance();
      }
      tokens.push({ type: "number", value: Number(value) });
      continue;
    }

    if (/[A-Za-z_]/.test(ch)) {
      let value = "";
      while (i < source.length && /[A-Za-z0-9_]/.test(peek())) {
        value += advance();
      }
      if (KEYWORDS.has(value)) {
        tokens.push({ type: value, value });
      } else {
        tokens.push({ type: "ident", value });
      }
      continue;
    }

    throw new Error(`Unexpected character: ${ch}`);
  }

  tokens.push({ type: "eof", value: "" });
  return tokens;
}
