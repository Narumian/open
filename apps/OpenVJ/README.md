# OpenVJ

Standalone macOS generative visuals via **WebGPU** ([wgpu-native](https://github.com/gfx-rs/wgpu-native) + Swift). ~60fps in a resizable window or fullscreen.

Rendering uses a `CAMetalLayer` surface with wgpu’s Metal backend — not a direct `MTKView` Metal renderer.

## Renderer abstraction

The app depends on **`VisualRenderer`**, not on WebGPU types directly. Backends are created through **`VisualRender.makeRenderer(attachment:)`** (same registry pattern as `InterAppTextureRegistry`).

| Type | Role |
|------|------|
| `VisualRenderer` | Protocol: `configure`, `render(frameTime:)`, `setInterAppPublisher` |
| `VisualFrameStatus` | Backend-agnostic frame outcome |
| `VisualSurfaceAttachment` | Surface handle (`metalLayer` on macOS) |
| `VisualRender` | Factory + optional `registerRendererFactory` override |
| `WGPUVisualRenderer` | Default WebGPU implementation (registered automatically) |

`OpenVJApp` / `VisualView` hold a `VisualRenderer?` and pass a `VisualSurfaceAttachment` from the view’s `CAMetalLayer`. Syphon publishing attaches an `InterAppTexturePublisher` on that protocol. A future non-WGPU backend can register its own factory without changing the app shell.

## OpenUI / `body` (declarative scene graph)

Generative content is described with the **`OpenUI`** module: a SwiftUI-free **`View`** protocol with recursive **`associatedtype Body: View`**, **`@ViewBuilder var body`**, and leaf types with **`Body == Never`**. Tree walk uses **`renderLeaf`** and **`ViewRenderContext`** (backend-agnostic draw hooks; WGPU lives in `OpenVJ`).

| Type | Role |
|------|------|
| `View` | Scene graph protocol (`import OpenUI`) |
| `ViewBuilder` | `@resultBuilder` for tuples, optionals, `if`/`else` |
| `ViewRenderContext` | Backend-neutral draw / publish commands during traversal |
| `Add` | Stack multiple leaves in tree order (first opaque, later ~55% alpha) |
| `Mixer` | Equal-weight VJ mix (`1 / N` alpha per child, same render pass) |
| `MatrixSwitcher` | One active bus at a time (hard cut); children are inputs |
| `MatrixSwitcherBus` | Shared mutable bus index (`selection:` on `MatrixSwitcher`) |
| `SinBody` / `TanBody` | Wave-domain generative leaves (`waveMode` WGSL uniform) |
| `TanBody.time(_:)` | Pin tan warp time (`Float` or `CFTimeInterval`) |
| `OpenVJSceneTime.current` | Frame time written by the renderer (for `.time(...)` at call site) |
| `ShaderView` | Legacy full-screen generative WGSL leaf |
| `Video` | Local file video leaf (AVFoundation → WGPU texture) |
| `OpenVJVideoScene` | `Add { Video(...); SinBody() }` example |
| `GroupView` | Transparent container for builder content |
| `EmptyView` | No-op leaf |
| `AnyView` | Type erasure for renderer storage |
| `InterAppTexture` | Leaf: request inter-app publish (`InterAppTexture("OpenVJ")`) — no draw |
| `SomeVisual` | Demo sin wave leaf for publish examples |
| `OpenVJDefaultScene` | Built-in root scene (`Add { SinBody(); TanBody().time(...) }`) |
| `OpenVJInterAppTextureScene` | `Add { InterAppTexture("OpenVJ"); SomeVisual() }` |
| `OpenVJLiveScene` | `Add { InterAppTexture("OpenVJ"); Mixer { SinBody(); TanBody() } }` — used when Syphon is on at launch |
| `OpenVJLiveVideoScene` | Publish + `Mixer { SinBody(); Video(path:) }` |
| `OpenVJTimedDemoScene` | Same stack with an explicit `time` parameter |
| `ViewSceneHosting` | `VisualRenderer` + `rootView` (`WGPUVisualRenderer`) |

**`Add` vs `Mixer` vs `MatrixSwitcher` (v0):** `Add` and `Mixer` draw **every** child each frame (same pass, different alphas). `MatrixSwitcher` draws **only** the active bus (hard cut, full opacity).

| | `Add` | `Mixer` | `MatrixSwitcher` |
|---|--------|---------|------------------|
| Feel | Stack / overlay | Crossfade / equal mix | Bus / matrix switch |
| Children per frame | All | All | One (`activeIndex`) |
| First child | 100% alpha | `1 / N` | 100% when selected |
| Later children | ~55% alpha each | `1 / N` each | Hidden until selected |
| `ViewNode` | `.group([...])` | `.mixer([...])` | `.matrixSwitcher(..., activeIndex:)` |

Not GPU additive blend modes yet — src-alpha layering with different weights (`Add` / `Mixer` only).

Example (default scene shape — stacked sin + tan):

```swift
Add {
    SinBody()
    TanBody().time(t)
}
```

Equal-weight mix (three layers at `1/3` opacity each):

```swift
Mixer {
    SinBody()
    TanBody().time(t)
    Video(path: "/path/to/clip.mov")
}
```

Matrix bus switch (one input visible; default bus `0`):

```swift
MatrixSwitcher {
    Video(path: "a.mov")
    SinBody()
    InterAppTextureInput("Resolume")
}
```

Drive the bus from your app (`MatrixSwitcherBus` is the SwiftUI-free stand-in for `Binding<Int>`):

```swift
let bus = MatrixSwitcherBus(activeIndex: 0)
// bus.activeIndex = 1  // keyboard / OSC / UI
MatrixSwitcher(selection: bus) {
    Video(path: "a.mov")
    SinBody()
    InterAppTextureInput("Resolume")
}
```

Use `OpenVJSceneTime.current` for `t` when you want the renderer’s frame clock, or pass your own `Float` (see `OpenVJTimedDemoScene`).

Local video playback (macOS, `file://` only in v0):

```swift
Add {
    Video(path: "/path/to/clip.mov")
    SinBody()
}
```

Assign `AnyView(OpenVJVideoScene(videoAt: url))` on `WGPUVisualRenderer.rootView` to swap in a video scene. Frames are decoded with `AVPlayer` + `AVPlayerItemVideoOutput`, copied to a BGRA8 WGPU texture each frame, and drawn as a full-screen textured triangle (same layered blend rules as `Add` generative leaves). **v0 limits:** local file URLs only (no HTTP/HLS), no drag-and-drop UI yet, loops on end-of-file, CPU `queue.writeTexture` upload (not zero-copy Metal interop).

Inter-app publish from the scene graph (backend-agnostic; Syphon only when `OpenVJSyphon` is linked):

```swift
Add {
    InterAppTexture("OpenVJ")
    Mixer {
        SinBody()
        Video(path: "/path/to/clip.mov")
    }
}
```

During tree walk, `InterAppTexture` configures `InterAppTexturePublisher` via `InterAppTextureRegistry.makePublisher(configuration:)` — the renderer does not call Syphon directly. `OpenVJApp` calls `openVJSyphonBootstrap()` when rendering starts (no app-side Syphon setup). Without a linked backend, publish is a no-op and OpenVJ logs once.

Subscribe from another app’s Syphon server:

```swift
Mixer {
    SinBody()
    InterAppTexture.subscribe("OtherApp")
}
```

Syphon-first roadmap and future Spout/NDI backends: [docs/inter-app-texture.md](../../docs/inter-app-texture.md). Virtual camera (`VirtualCamera`, `VirtualCameraRegistry`, optional `OpenVJVirtualCam`): [docs/virtual-camera.md](../../docs/virtual-camera.md).

```swift
Add {
    VirtualCamera("OpenVJ")
    InterAppTexture("OpenVJ")
    Mixer {
        SinBody()
        InterAppTextureInput("OtherApp")
    }
}
```

Built-in `OpenVJVirtualCamMixScene` matches this shape.

`WGPUVisualRenderer.rootView` is traversed each frame; assign `AnyView(yourScene)` on a `ViewSceneHosting` renderer to swap scenes without touching the AppKit shell.

## Requirements

- macOS 13+
- Xcode 15+ (Swift 5.9+)

## One-time: fetch wgpu-native

```bash
cd apps/OpenVJ
bash Scripts/fetch-wgpu.sh
```

Creates `Vendor/CWGPU.xcframework` (gitignored).

## Inter-app texture sharing (optional)

OpenVJ exposes inter-app texture sharing in the `OpenVJ` library:

| Type | Role |
|------|------|
| `InterAppTexture` | OpenUI leaf — publish with a server name |
| `VirtualCamera` | OpenUI leaf — publish composited frames to virtual camera backend |
| `InterAppTextureInput` / `InterAppTexture.subscribe` | OpenUI leaf — receive and draw a remote server |
| `InterAppTextureRegistry` | `makePublisher` / `makeSubscriber` factories |
| `InterAppTexturePublisher` | Publish WGPU frames to other apps |
| `InterAppTextureSubscriber` | Import remote frames into WGPU (Syphon when linked) |
| `OpenVJSyphon` | macOS Syphon publish + subscribe (optional target) |

No Syphon framework is required for a normal build.

### Enable Syphon (macOS)

1. Build the Syphon vendor artifact (once):

   ```bash
   cd apps/OpenVJ
   bash Scripts/fetch-syphon.sh
   ```

   Creates `Vendor/Syphon.xcframework` (gitignored). Re-run `swift build` so `Package.swift` links `OpenVJSyphon`.

2. Include `InterAppTexture("OpenVJ")` (or another name) in your scene — the Syphon server appears automatically when clients connect.

   Optional conveniences:

   - **Environment:** `OPEN_VJ_SYPHON=1 .build/debug/OpenVJApp` (selects `OpenVJLiveScene` at startup)
   - **Menu:** View → **Publish to Syphon** — kill switch for publish leaves (persists in UserDefaults)

Other apps see a server matching the `InterAppTexture` name in Syphon clients (e.g. VDMX, Resolume).

**Resolume:** Sources → Syphon → **OpenVJ**. **VDMX:** Syphon Input → server **OpenVJ**.

### WGPU → Syphon bridge (constraints)

- Requires wgpu’s **Metal** backend on macOS (`wgpuDeviceGetNativeMetalDevice`, `wgpuQueueGetNativeMetalCommandQueue`, `wgpuTextureGetNativeMetalTexture`).
- Each frame: render to the window surface, **GPU-copy** the swapchain image to an internal BGRA8 texture (`CopySrc` on the surface), flush the WGPU queue, then hand the native `MTLTexture` to `SyphonMetalServer`.
- Syphon performs its own IOSurface / client delivery; OpenVJ does not call IOSurface directly.
- Publishing is skipped when no Syphon clients are connected (`hasClients`).

## Build & run

**Swift Package Manager**

```bash
cd apps/OpenVJ
swift build
.build/debug/OpenVJApp
```

**Xcode**

Open `Package.swift` in Xcode → scheme **OpenVJApp** → Run (⌘R). Use the green fullscreen control for fullscreen output.

**Command line (xcodebuild)**

```bash
cd apps/OpenVJ
xcodebuild -scheme OpenVJApp -destination 'platform=macOS' build
```

## Layout

| Target | Role |
|--------|------|
| `OpenUI` | SwiftUI-free `View` declaration layer + `ViewRenderContext` |
| `OpenVJ` | `VisualRenderer` + `WGPUVisualRenderer` + `InterAppTexture` registry |
| `OpenVJApple` | Metal-layer → wgpu surface bridge |
| `OpenVJSyphon` | Syphon publisher backend (when `Vendor/Syphon.xcframework` exists) |
| `OpenVJVirtualCam` | Virtual camera publisher (v0 stub; always buildable, no vendor SDK) |
| `OpenVJApp` | Default **non-常駐** host (`VisualView`, 60Hz timer, optional Syphon menu) |
| `OpenVJAgent` | *(future)* Menu-bar 常駐 host running the same `rootView` — not in repo v0 |

`OpenVJApp` is the default host: virtual camera and Syphon exist only while the app runs and the scene includes the publish leaves. Use a future `OpenVJAgent` only if the camera must stay registered when the main window is closed.
