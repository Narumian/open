# Open

**Open** is a monorepo for Narumian’s “open surface” stack: declarative visuals on macOS and a **Swift-like browser DSL** that transpiles to JavaScript. Official repo: [github.com/Narumian/open](https://github.com/Narumian/open).

| Track | What it is | Where |
|-------|------------|--------|
| **OpenVJ** / **OpenUI** | macOS generative VJ via WebGPU; declarative `View` scene graph | [`apps/OpenVJ`](./apps/OpenVJ) (**v0.1.0** — see [OpenVJ README](./apps/OpenVJ/README.md)) |
| **Open** (browser DSL) | Parse → JS codegen → REPL; not Apple Swift compatibility | Root npm package, [`docs/SPEC.md`](./docs/SPEC.md), implementation package [`src/jswift/`](./src/jswift/) |

One-page synthesis: [docs/open.md](./docs/open.md).

---

## Open (browser DSL) — quickstart

Swift-style subset (Phase 1): `let` / `var`, `print`, `if` / `else`, `func`, arithmetic, `sleep(ms)`.

```bash
npm install
npm run dev    # Vite → http://localhost:5173 (Open REPL)
npm test       # transpile smoke tests
```

REPL example:

```swift
let x = 1 + 2
print(x)

func greet(_ name: String) {
  print(name)
}
greet("Open")
```

Grammar and runtime: [docs/SPEC.md](./docs/SPEC.md).

---

## OpenVJ — quickstart

macOS app + **OpenUI** module for generative scenes (~60fps WebGPU). **v0.1.0** milestone.

```bash
cd apps/OpenVJ
swift build
swift run OpenVJApp
```

Details, scene examples, and architecture: [apps/OpenVJ/README.md](./apps/OpenVJ/README.md).

---

## Repo layout

```text
apps/OpenVJ/     OpenVJ app, OpenUI, WebGPU renderer
src/jswift/      Open DSL engine (tokenizer, parser, codegen, drivers)
src/repl/        Browser REPL entry
docs/            SPEC, open.md, shared design notes
public/          Static assets for Vite
```

---

## License

TBD
