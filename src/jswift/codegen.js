import { JSwiftError } from "./errors.js";

function emitExpr(node) {
  switch (node.kind) {
    case "number":
      return String(node.value);
    case "string":
      return JSON.stringify(node.value);
    case "ident":
      return node.name;
    case "binary":
      return `(${emitExpr(node.left)} ${node.op} ${emitExpr(node.right)})`;
    case "call": {
      if (node.callee.kind !== "ident") {
        throw new JSwiftError("Only simple calls are supported");
      }
      const args = node.args.map(emitExpr).join(", ");
      if (node.callee.name === "sleep") {
        return `await Open.sleep(${args})`;
      }
      return `${node.callee.name}(${args})`;
    }
    default:
      throw new JSwiftError(`Unknown expr: ${node.kind}`);
  }
}

function emitStmt(stmt, indent = "") {
  const pad = indent;
  const inner = `${indent}  `;

  if (stmt.kind === "let") {
    return `${pad}${stmt.binding} ${stmt.name} = ${emitExpr(stmt.init)};`;
  }
  if (stmt.kind === "print") {
    return `${pad}console.log(${emitExpr(stmt.arg)});`;
  }
  if (stmt.kind === "expr") {
    return `${pad}${emitExpr(stmt.expr)};`;
  }
  if (stmt.kind === "func") {
    const body = stmt.body.map((s) => emitStmt(s, inner)).join("\n");
    return `${pad}function ${stmt.name}(${stmt.params.join(", ")}) {\n${body}\n${pad}}`;
  }
  if (stmt.kind === "if") {
    const thenBody = stmt.thenStmts.map((s) => emitStmt(s, inner)).join("\n");
    let out = `${pad}if (${emitExpr(stmt.cond)}) {\n${thenBody}\n${pad}}`;
    if (stmt.elseStmts) {
      const elseBody = stmt.elseStmts.map((s) => emitStmt(s, inner)).join("\n");
      out += ` else {\n${elseBody}\n${pad}}`;
    }
    return out;
  }
  throw new JSwiftError(`Unknown stmt: ${stmt.kind}`);
}

export function codegen(ast) {
  return ast.statements.map((stmt) => emitStmt(stmt)).join("\n");
}
