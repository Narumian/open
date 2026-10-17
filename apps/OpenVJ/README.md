# OpenVJ

Standalone macOS generative visuals: **Metal** (`MTKView`), ~60fps, window or fullscreen. No Syphon / NDI / host hooks.

## Requirements

- macOS 13+
- Xcode 15+

## Open & run

```bash
cd apps/OpenVJ
xcodegen generate
open OpenVJ.xcodeproj
```

In Xcode: select **OpenVJApp** scheme → **Run** (⌘R). Use the green fullscreen control on the window title bar for fullscreen output.

## Command-line build

```bash
cd apps/OpenVJ
xcodegen generate
xcodebuild -scheme OpenVJApp -project OpenVJ.xcodeproj -configuration Debug build
```

Built app: `~/Library/Developer/Xcode/DerivedData/**/Build/Products/Debug/OpenVJApp.app`

## Layout

| Target | Role |
|--------|------|
| `OpenVJ` | Framework: `MetalVisualRenderer` + Metal shaders |
| `OpenVJApp` | macOS app shell (`MTKView` in a resizable window) |
