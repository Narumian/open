# Inter-app texture (Syphon-first)

OpenVJ exchanges GPU frames with other macOS apps through a **backend-agnostic** API in `OpenVJ`. The **OpenUI** surface is always `InterAppTexture*` types — **Syphon is an implementation detail** inside the optional `OpenVJSyphon` module.

**Syphon publish does not need a separate 常駐 daemon** — run OpenVJ (or your host) during the performance and the server exists for that session. For **system virtual camera** output (`VirtualCamera`), host-process and optional menu-bar 常駐 tradeoffs, see [virtual-camera.md](virtual-camera.md).

## Strategy

1. **Ship on macOS with Syphon** — WGPU → Metal ↔ Syphon publish and subscribe in production VJ tools (Resolume, VDMX).
2. **Keep the abstraction** — `InterAppTextureRegistry` factories + `InterAppTexturePublisher` / `InterAppTextureSubscriber` are the stable seam.
3. **Port later** — Windows Spout, LAN NDI, etc. become additional factories, not scene-graph changes.

## Architecture

| Layer | Responsibility |
|-------|----------------|
| `OpenUI` | `InterAppTexture` (publish), `InterAppTextureInput` / `InterAppTexture.subscribe` (receive) |
| `OpenVJ` | Registry, `WGPUVisualRenderer` copy + publish, `WGPUInterAppTextureInputState` import + draw |
| `OpenVJSyphon` | **Only module that imports Syphon SDK** — `SyphonInterAppTexturePublisher`, `SyphonInterAppTextureSubscriber` |
| `OpenVJApp` | Calls `openVJSyphonBootstrap()` on render start when linked; optional menu kill switch |

### Publish path (out)

1. `InterAppTexture("name")` in the view tree → `InterAppTextureRegistry.makePublisher` (no manual Syphon wiring).
2. Render scene to swapchain (BGRA8, `CopySrc`).
3. GPU `copyTextureToTexture` → internal buffer → `SyphonMetalServer.publishFrameTexture` (when clients connected).

### Subscribe path (in)

1. `InterAppTextureInput("ServerName")` or `InterAppTexture.subscribe("ServerName")` in `Add` / `Mixer`.
2. `InterAppTextureRegistry.makeSubscriber` → `SyphonMetalClient` on the shared wgpu Metal device.
3. Each frame: Metal blit from Syphon `MTLTexture` into a WGPU BGRA8 texture, sampled like `Video`.

`openVJSyphonBootstrap()` registers **both** publisher and subscriber factories. `OpenVJApp` invokes it automatically when `OpenVJSyphon` is linked.

## Scene graph examples

Publish + draw:

```swift
Add {
    InterAppTexture("OpenVJ")
    SomeVisual()
}
```

Publish + equal-weight mix:

```swift
Add {
    InterAppTexture("OpenVJ")
    Mixer {
        SinBody()
        Video(path: "/path/to/clip.mov")
    }
}
```

Subscribe + mix remote Syphon with local generative output:

```swift
Add {
    InterAppTexture("OpenVJ")
    Mixer {
        SinBody()
        InterAppTexture.subscribe("OtherApp")
    }
}
```

Built-in scenes (`OpenUI`):

| Scene | Use |
|-------|-----|
| `OpenVJLiveScene` | Publish `OpenVJ` + `Mixer { SinBody(); TanBody() }` |
| `OpenVJSyphonMixScene` | Publish + mix subscribed server (default name `OpenVJ`) |
| `OpenVJLiveVideoScene(path:)` | Publish + `Video` in `Mixer` |
| `OpenVJInterAppTextureScene` | Minimal publish demo |

When `OPEN_VJ_SYPHON=1` or View → **Publish to Syphon** was on at last launch, `OpenVJApp` selects `OpenVJLiveScene()` as `rootView`. Publish still works from any scene that includes `InterAppTexture` once the Syphon backend is linked.

## Backends

| Backend | Platform | Publish | Subscribe |
|---------|----------|---------|-----------|
| **Syphon** | macOS | `OpenVJSyphon` | `OpenVJSyphon` |
| **Spout** | Windows | Planned | Planned |
| **NDI** | Cross-platform | Planned | Planned |

Register factories with `InterAppTextureRegistry.registerPublisherFactory` / `registerSubscriberFactory` from optional targets (same pattern as `openVJSyphonBootstrap()`).

## Developer setup (Syphon)

```bash
cd apps/OpenVJ
bash Scripts/fetch-wgpu.sh    # once
bash Scripts/fetch-syphon.sh  # once → Vendor/Syphon.xcframework
swift build
OPEN_VJ_SYPHON=1 .build/debug/OpenVJApp
```

Without `Vendor/Syphon.xcframework`, `Package.swift` omits `OpenVJSyphon`; `swift build` still succeeds. Publish/subscribe leaves log once if requested without a backend.

See also [apps/OpenVJ/README.md](../apps/OpenVJ/README.md).

## Verify in other apps

- **Resolume Arena:** Sources → Syphon → **OpenVJ** (scene must include `InterAppTexture("OpenVJ")`).
- **VDMX:** Syphon Input → server **OpenVJ**.
