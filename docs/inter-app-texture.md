# Inter-app texture (Syphon-first)

OpenVJ sends rendered frames to other macOS apps through a **backend-agnostic** API in `OpenVJ`. The **OpenUI** layer only exposes `InterAppTexture("serverName")` as a scene-graph leaf — no Syphon types in `OpenUI`.

## Strategy

1. **Ship on macOS with Syphon** — prove WGPU → Metal → Syphon end-to-end in production VJ tools (Resolume, VDMX).
2. **Keep the abstraction** — `InterAppTextureRegistry` + `InterAppTexturePublisher` are the stable seam.
3. **Port later** — Windows Spout, LAN NDI, etc. become additional publisher factories, not changes to scene graphs.

## Architecture

| Layer | Responsibility |
|-------|----------------|
| `OpenUI` | `InterAppTexture` leaf → `ViewRenderContext.requestInterAppPublish` |
| `OpenVJ` | `InterAppTextureRegistry`, `WGPUVisualRenderer` copy + `publish(texture:)` |
| `OpenVJSyphon` | `SyphonInterAppTexturePublisher` (`SyphonMetalServer`) |
| `OpenVJApp` | Menu / `OPEN_VJ_SYPHON`, optional `OpenVJLiveScene` when publish is on |

Frame path (macOS + Syphon linked):

1. Render scene into the window swapchain (BGRA8, `CopySrc` on surface).
2. GPU `copyTextureToTexture` into an internal BGRA8 buffer.
3. Flush the WGPU queue.
4. `wgpuTextureGetNativeMetalTexture` → `SyphonMetalServer.publishFrameTexture` (skipped when `hasClients` is false).

## Scene graph examples

Publish + stacked layers (`Add`):

```swift
Add {
    InterAppTexture("OpenVJ")
    SomeVisual()
}
```

Publish + equal-weight mix (`Mixer`):

```swift
Add {
    InterAppTexture("OpenVJ")
    Mixer {
        SinBody()
        Video(path: "/path/to/clip.mov")
    }
}
```

Built-in scenes (module `OpenUI`):

| Scene | Use |
|-------|-----|
| `OpenVJLiveScene` | `InterAppTexture("OpenVJ")` + `Mixer { SinBody(); TanBody() }` |
| `OpenVJLiveVideoScene(path:)` | Same publish leaf + `Mixer { SinBody(); Video }` |
| `OpenVJInterAppTextureScene` | Minimal demo with `SomeVisual` |

When `OPEN_VJ_SYPHON=1` or View → **Publish to Syphon** is on at launch, `OpenVJApp` sets `rootView` to `OpenVJLiveScene()` automatically.

## Future backends (`InterAppTexturePublisher`)

| Backend | Platform | Status | Notes |
|---------|----------|--------|-------|
| **Syphon** | macOS | **Implemented** (`OpenVJSyphon`) | Metal texture from wgpu-native |
| **Spout** | Windows | Planned | Same publisher protocol; D3D11/12 shared handle from WGPU |
| **NDI** | Cross-platform | Planned | CPU or GPU encode path; separate from Syphon IOSurface model |
| **Receiver** | macOS / Windows | Stub | `InterAppTextureSubscriber` not implemented |

Register a backend with `InterAppTextureRegistry.registerPublisherFactory` from an optional target (same pattern as `openVJSyphonBootstrap()`).

## Developer setup (Syphon)

```bash
cd apps/OpenVJ
bash Scripts/fetch-wgpu.sh    # once
bash Scripts/fetch-syphon.sh  # once → Vendor/Syphon.xcframework
swift build
OPEN_VJ_SYPHON=1 .build/debug/OpenVJApp
```

Without `Vendor/Syphon.xcframework`, `Package.swift` omits `OpenVJSyphon`; `swift build` still succeeds and inter-app publish logs once if requested.

See also [apps/OpenVJ/README.md](../apps/OpenVJ/README.md) for renderer and OpenUI details.

## Verify in other apps

- **Resolume Arena:** Sources → Syphon → select **OpenVJ** (enable publish first).
- **VDMX:** Workspace → Syphon Input → choose server **OpenVJ**.
