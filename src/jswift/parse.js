export function parse(tokens) {
  let pos = 0;
  const statements = [];

  const peek = () => tokens[pos];
  const advance = () => tokens[pos++];

  const skipNewlines = () => {
    while (peek()?.type === "newline") advance();
  };

  const expect = (type, value) => {
    const tok = peek();
    if (!tok || tok.type !== type || (value !== undefined && tok.value !== value)) {
      throw new Error(`Expected ${value ?? type}, got ${tok?.type ?? "eof"}`);
    }
    return advance();
  };

  const parseExpression = (minPrec = 0) => {
    let left = parseFactor();

    while (peek()?.type === "op") {
      const op = peek().value;
      const prec = op === "+" || op === "-" ? 1 : 2;
      if (prec < minPrec) break;
      advance();
      const right = parseExpression(prec + 1);
      left = { kind: "binary", op, left, right };
    }
    return left;
  };

  const parseFactor = () => {
    const tok = peek();
    if (!tok) throw new Error("Unexpected end of input");

    if (tok.type === "number") {
      advance();
      return { kind: "number", value: tok.value };
    }
    if (tok.type === "string") {
      advance();
      return { kind: "string", value: tok.value };
    }
    if (tok.type === "ident") {
      advance();
      return { kind: "ident", name: tok.value };
    }
    if (tok.type === "(") {
      advance();
      const expr = parseExpression();
      expect(")", ")");
      return expr;
    }
    throw new Error(`Unexpected token: ${tok.type}`);
  };

  skipNewlines();
  while (peek() && peek().type !== "eof") {
    if (peek().type === "newline") {
      advance();
      continue;
    }

    if (peek().type === "let" || peek().type === "var") {
      const kind = advance().type;
      const name = expect("ident").value;
      expect("=", "=");
      const init = parseExpression();
      skipNewlines();
      statements.push({ kind: "let", binding: kind, name, init });
      continue;
    }

    if (peek().type === "print") {
      advance();
      expect("(", "(");
      const arg = parseExpression();
      expect(")", ")");
      skipNewlines();
      statements.push({ kind: "print", arg });
      continue;
    }

    throw new Error(`Unexpected token: ${peek().type}`);
  }

  return { kind: "program", statements };
}
