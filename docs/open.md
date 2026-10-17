# Open — monorepo overview

**Open** ([Narumian/open](https://github.com/Narumian/open)) groups two products that share naming and a “small surface, big capability” philosophy:

1. **OpenVJ** — native macOS generative visuals (WebGPU).
2. **Open** — browser-hosted **Swift-like DSL** that transpiles to JavaScript and runs in a REPL.

They are separate runtimes; **OpenUI** is the Swift module name inside OpenVJ’s declarative scene graph, not the browser DSL.

---

## OpenVJ + OpenUI

- **OpenVJ** (`apps/OpenVJ`, **v0.1.0**): resizable/fullscreen window, `VisualRenderer` abstraction, default **WGPU** backend.
- **OpenUI** (`apps/OpenVJ/Sources/OpenUI`): SwiftUI-free `View` protocol, `@ViewBuilder`, leaves like `SinBody`, `Mixer`, `Video`, inter-app texture I/O.

Entry: [apps/OpenVJ/README.md](../apps/OpenVJ/README.md).

---

## Open (browser DSL)

A **curated Swift-shaped language** for scripts that must run where the host only executes JavaScript (browser tab, Node, embedded WebView). Pipeline:

```text
Open source (Swift-like DSL)
  → parse / light semantics
  → JavaScript
  → host runtime (Open.* drivers + console)
```

- **Grammar (v0.1):** [SPEC.md](./SPEC.md)
- **Implementation package (short-term path):** `src/jswift/`
- **REPL:** root `npm run dev` → `public/index.html`

The host injects an **`Open`** object for builtins (`Open.sleep`, `Open.now`, …). `print(...)` maps to `console.log` in the REPL.

---

## Naming

| Name | Meaning |
|------|---------|
| **Open** | Project / monorepo brand |
| **OpenVJ** | macOS VJ application target |
| **OpenUI** | Declarative scene-graph module (Swift) |
| **Open** (language) | Browser DSL track (this doc’s second section) |

When “Open” alone is ambiguous in conversation, say **Open browser DSL** vs **OpenVJ**.

---

## History

**JSwift** was the working title for the browser DSL engine (and older aliases like BrowserSwift / JSwf). User-facing branding is now **Open**; internal paths such as `src/jswift/` and the `JSwiftError` type may remain until a mechanical rename.
