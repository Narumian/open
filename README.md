# JSwift

**JSwift** は JavaScript 上で Swift 風 DSL を動かすエンジン（パーサ → JS 生成 → ブラウザ/Node で実行）です。Apple Swift の互換実行ではなく、**厳選した Swift 風セマンティクス**を ECMAScript に載せるプロジェクトです。

- 構想・アーキテクチャ・フェーズ: [docs/SPEC.md](./docs/SPEC.md)（文法 v0）。全体コンセプトは Open Project の `jswift.md`。
- 公式リポ: https://github.com/Narumian/open

## Phase 1（このリポ）

- `src/jswift/` — トークナイザ・パーサ・JS コード生成（`let` / `var`、`print(...)`、四則演算）
- `public/index.html` — ブラウザ REPL
- `docs/SPEC.md` — 文法サブセット v0

## ローカルで動かす

```bash
npm install
npm run dev    # Vite → http://localhost:5173
npm test       # トランスパイルのスモークテスト
```

REPL で例:

```swift
let x = 1 + 2
print(x)
```

## ライセンス

TBD
