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
    default:
      throw new Error(`Unknown expr: ${node.kind}`);
  }
}

export function codegen(ast) {
  const lines = ast.statements.map((stmt) => {
    if (stmt.kind === "let") {
      return `${stmt.binding} ${stmt.name} = ${emitExpr(stmt.init)};`;
    }
    if (stmt.kind === "print") {
      return `console.log(${emitExpr(stmt.arg)});`;
    }
    throw new Error(`Unknown stmt: ${stmt.kind}`);
  });
  return lines.join("\n");
}
