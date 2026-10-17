import { syntaxError } from "./errors.js";

export function parse(tokens) {
  let pos = 0;

  const peek = () => tokens[pos];
  const advance = () => tokens[pos++];

  const expect = (type, value) => {
    const tok = peek();
    if (!tok || tok.type !== type || (value !== undefined && tok.value !== value)) {
      throw syntaxError(`Expected ${value ?? type}, got ${tok?.type ?? "eof"}`, tok ?? tokens[tokens.length - 1]);
    }
    return advance();
  };

  const skipNewlines = () => {
    while (peek()?.type === "newline") advance();
  };

  const parseExpression = () => {
    let left = parseAdditive();
    while (peek()?.type === "op" && ["==", "!=", "<", ">", "<=", ">="].includes(peek().value)) {
      const op = advance().value;
      const right = parseAdditive();
      left = { kind: "binary", op, left, right };
    }
    return left;
  };

  const parseTerm = (minPrec = 0) => {
    let left = parsePostfix();

    while (peek()?.type === "op" && (peek().value === "*" || peek().value === "/")) {
      const op = peek().value;
      const prec = 2;
      if (prec < minPrec) break;
      advance();
      const right = parseTerm(prec + 1);
      left = { kind: "binary", op, left, right };
    }
    return left;
  };

  const parseAdditive = (minPrec = 0) => {
    let left = parseTerm();

    while (peek()?.type === "op" && (peek().value === "+" || peek().value === "-")) {
      const op = peek().value;
      const prec = 1;
      if (prec < minPrec) break;
      advance();
      const right = parseAdditive(prec + 1);
      left = { kind: "binary", op, left, right };
    }
    return left;
  };

  const parsePostfix = () => {
    let node = parsePrimary();
    while (peek()?.type === "(") {
      advance();
      const args = [];
      if (peek().type !== ")") {
        while (true) {
          args.push(parseExpression());
          if (peek().type === ",") {
            advance();
            continue;
          }
          break;
        }
      }
      expect(")", ")");
      node = { kind: "call", callee: node, args };
    }
    return node;
  };

  const parsePrimary = () => {
    const tok = peek();
    if (!tok) throw syntaxError("Unexpected end of input", tokens[tokens.length - 1]);

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
    throw syntaxError(`Unexpected token: ${tok.type}`, tok);
  };

  const parseBlock = () => {
    expect("{", "{");
    const stmts = [];
    skipNewlines();
    while (peek() && peek().type !== "}" && peek().type !== "eof") {
      if (peek().type === "newline") {
        advance();
        continue;
      }
      const stmt = parseStatement();
      if (stmt) stmts.push(stmt);
    }
    expect("}", "}");
    return stmts;
  };

  const parseStatement = () => {
    skipNewlines();
    const tok = peek();
    if (!tok || tok.type === "}" || tok.type === "eof") return null;

    if (tok.type === "let" || tok.type === "var") {
      const binding = advance().type;
      const name = expect("ident").value;
      expect("=", "=");
      const init = parseExpression();
      skipNewlines();
      return { kind: "let", binding, name, init };
    }

    if (tok.type === "print") {
      advance();
      expect("(", "(");
      const arg = parseExpression();
      expect(")", ")");
      skipNewlines();
      return { kind: "print", arg };
    }

    if (tok.type === "if") {
      advance();
      const cond = parseExpression();
      const thenStmts = parseBlock();
      skipNewlines();
      let elseStmts = null;
      if (peek()?.type === "else") {
        advance();
        elseStmts = parseBlock();
      }
      skipNewlines();
      return { kind: "if", cond, thenStmts, elseStmts };
    }

    if (tok.type === "func") {
      advance();
      const name = expect("ident").value;
      expect("(", "(");
      const params = [];
      if (peek().type !== ")") {
        while (true) {
          if (peek().type === "ident" && peek().value === "_") advance();
          const paramName = expect("ident").value;
          if (peek().type === ":") {
            advance();
            expect("ident");
          }
          params.push(paramName);
          if (peek().type === ",") {
            advance();
            continue;
          }
          break;
        }
      }
      expect(")", ")");
      const body = parseBlock();
      skipNewlines();
      return { kind: "func", name, params, body };
    }

    const expr = parseExpression();
    skipNewlines();
    return { kind: "expr", expr };
  };

  const statements = [];
  skipNewlines();
  while (peek() && peek().type !== "eof") {
    if (peek().type === "newline") {
      advance();
      continue;
    }
    const stmt = parseStatement();
    if (stmt) statements.push(stmt);
  }

  return { kind: "program", statements };
}
