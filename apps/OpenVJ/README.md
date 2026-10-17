# OpenVJ

Standalone macOS generative visuals via **WebGPU** ([wgpu-native](https://github.com/gfx-rs/wgpu-native) + Swift). ~60fps in a resizable window or fullscreen.

Rendering uses a `CAMetalLayer` surface with wgpu’s Metal backend — not a direct `MTKView` Metal renderer.

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

OpenVJ exposes a small **`InterAppTexture`** API in the `OpenVJ` library:

| Type | Role |
|------|------|
| `InterAppTexture` | Registry + `makePublisher(configuration:)` |
| `InterAppTexturePublisher` | Publish WGPU frames to other apps |
| `InterAppTextureSubscriber` | Stub for future receive path |
| `OpenVJSyphon` | macOS Syphon backend (optional target) |

**Default:** publishing is **off**. No Syphon framework is required for a normal build.

### Enable Syphon publish (macOS)

1. Build the Syphon vendor artifact (once):

   ```bash
   cd apps/OpenVJ
   bash Scripts/fetch-syphon.sh
   ```

   Creates `Vendor/Syphon.xcframework` (gitignored). Re-run `swift build` so `Package.swift` links `OpenVJSyphon`.

2. Turn publishing on:

   - **Environment:** `OPEN_VJ_SYPHON=1 .build/debug/OpenVJApp`
   - **Menu:** View → **Publish to Syphon** (persists in UserDefaults)

Other apps see a server named **OpenVJ** in Syphon clients (e.g. VDMX, Resolume).

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
| `OpenVJ` | WebGPU renderer (`WGPUVisualRenderer`) + `InterAppTexture` protocols |
| `OpenVJApple` | Metal-layer → wgpu surface bridge |
| `OpenVJSyphon` | Syphon publisher backend (when `Vendor/Syphon.xcframework` exists) |
| `OpenVJApp` | AppKit shell (`VisualView`, 60Hz timer, optional Syphon menu) |
