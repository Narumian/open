# Changelog

All notable changes to OpenVJ and the **OpenUI** scene DSL are documented here.

## Unreleased

### macOS app

- **`OpenVJApp`** defaults to `OpenVJSourceBrowserMixerScene` so the main window mixes catalog-selected video with the generative layer; **View → Source Browser…** (⇧⌘B) lists Movies-folder media via `MacSourceCatalog`.
- Deferred **`VJPlayer` / `Sequence` / `SequencePlayer`** from the `OpenUI` build (sources kept under `Sources/OpenUI/Deferred/`).

## 0.1.0 — 2026-10-17

First tagged milestone: declarative scene graph, WGPU renderer, macOS app shell, and headless PNG export.

### OpenUI.View DSL

- **`View`** protocol with `@ViewBuilder`, `ViewRenderContext`, and `ViewRepresentable` tree flattening.
- **Compositing:** `Add`, `Mixer`, `GroupView`, `EmptyView`, `AnyView`.
- **Generative leaves:** `SinBody`, `TanBody`, `ShaderView`, `SomeVisual` / `Some`.
- **`Video`** leaf (local file URLs; host-backed decode).
- **`SourceBrowser`** leaf plus `SourceCatalog` / selection model (UI hosted in app; headless chrome in `OpenVJRender`).
- **`Output { }`** grouping for export sinks.
- **Inter-app texture I/O:** `InterAppTextureOutput`, `InterAppTextureInput` (Syphon when optional `OpenVJSyphon` is linked).
- **Output stubs (register only, no backend yet):** `EncodedStream`, `MuxedBroadcastStream`, `VirtualCamera`, `MatrixSwitcher`.

### Renderer and tooling

- **`VisualRenderer`** abstraction with default **`WGPUVisualRenderer`** (wgpu-native + Metal `CAMetalLayer`).
- **`OpenVJApp`** — resizable / fullscreen macOS window, optional inter-app publish menu.
- **`OpenVJRender`** — headless offscreen render to PNG (`OPEN_VJ_SCENE`, multi-frame option, source-browser mixer chrome compositor).

### Playback

- **`SourcePlaybackContext`** on `ViewRenderContext` for per-source transport and selection.
- **`VideoPlayer`** protocol; OpenVJ provides **`AVVideoPlayer`** / `VideoFrameSource`.
- **`VJPlayer`**, **`LoopPlayer`**, **`SequencePlayer`** — DSL and tree-walk scaffolding (loop/sequence timing still minimal in v0.1).

### Known limits (v0.1)

- Video: local files only, CPU texture upload, no drag-and-drop picker in app.
- Stream outputs and virtual camera are API stubs.
- `SequencePlayer` does not yet drive multi-clip timelines end-to-end.
- Syphon requires `Scripts/fetch-syphon.sh` and rebuild.
