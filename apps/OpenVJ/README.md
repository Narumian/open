# OpenVJ

Standalone macOS generative visuals via **WebGPU** ([wgpu-native](https://github.com/gfx-rs/wgpu-native) + Swift). ~60fps in a resizable window or fullscreen. No Syphon / NDI / host hooks.

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
| `OpenVJ` | WebGPU renderer (`WGPUVisualRenderer`) + WGSL generative shader |
| `OpenVJApple` | Metal-layer → wgpu surface bridge |
| `OpenVJApp` | AppKit shell (`VisualView`, 60Hz timer) |
