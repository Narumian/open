# JSwift grammar subset v0.1

Phase 1: statements with blocks, Swift-style `func`, conditionals, and arithmetic.

## Statements

```text
program     ::= statement*
statement   ::= letDecl | printStmt | ifStmt | funcDecl | exprStmt
letDecl     ::= ('let' | 'var') IDENT '=' expression
printStmt   ::= 'print' '(' expression ')'
ifStmt      ::= 'if' expression block ('else' block)?
funcDecl    ::= 'func' IDENT '(' paramList? ')' block
exprStmt    ::= expression
block       ::= '{' statement* '}'
paramList   ::= param (',' param)*
param       ::= '_'? IDENT (':' IDENT)?
```

Parameter types (`: Int`, `: String`, …) are **syntax only** in v0.1; codegen ignores them. External argument labels (`_`) are accepted and ignored.

## Expressions

```text
expression  ::= comparison
comparison  ::= additive (('==' | '!=' | '<' | '>' | '<=' | '>=') additive)*
additive    ::= term (('+' | '-') term)*
term        ::= factor (('*' | '/') factor)*
factor      ::= call
call        ::= primary ('(' argList? ')')*
primary     ::= NUMBER | STRING | IDENT | '(' expression ')'
argList     ::= expression (',' expression)*
```

## Built-ins

| JSwift | Generated JS | Notes |
|--------|----------------|-------|
| `print(e)` | `console.log(e)` | REPL captures output |
| `sleep(ms)` | `await JSwift.sleep(ms)` | Timer driver (`setTimeout`) |

## Runtime (`JSwift`)

Host injects a `JSwift` object into generated code:

| API | Driver | Behavior |
|-----|--------|----------|
| `JSwift.sleep(ms)` | `src/jswift/drivers/timer.js` | Promise; resolves after `ms` milliseconds |
| `JSwift.now()` | same | `performance.now()` |
| `JSwift.log(...)` | `src/jswift/drivers/console.js` | Optional; `print` uses `console.log` directly |

REPL wraps emitted JS in an `async` IIFE so `await` is valid when `sleep` is used.

## Lexical

```text
IDENT       ::= [A-Za-z_][A-Za-z0-9_]*
NUMBER      ::= [0-9]+
STRING      ::= '"' [^"]* '"' | "'" [^']* "'"
```

Keywords: `let`, `var`, `print`, `if`, `else`, `func`.

Comments (`//` to end of line) and blank lines are ignored. Compile errors include **line:column** (1-based).

## Examples

```swift
func double(_ n: Int) {
  print(n * 2)
}
let x = 3
double(x)

if x > 2 {
  print("big")
} else {
  print("small")
}
```
