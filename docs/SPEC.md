# JSwift grammar subset v0

Phase 1: line-oriented statements, expressions with literals and `+` `-` `*` `/`.

```text
program     ::= statement*
statement   ::= letDecl | printStmt
letDecl     ::= ('let' | 'var') IDENT '=' expression
printStmt   ::= 'print' '(' expression ')'
expression  ::= term (('+' | '-') term)*
term        ::= factor (('*' | '/') factor)*
factor      ::= NUMBER | STRING | IDENT | '(' expression ')'
IDENT       ::= [A-Za-z_][A-Za-z0-9_]*
NUMBER      ::= [0-9]+
STRING      ::= '"' [^"]* '"' | "'" [^']* "'"
```

Semantics: `let`/`var` bind in JS scope; `print(e)` → `console.log(e)`. Comments (`//`) and blank lines are ignored.
