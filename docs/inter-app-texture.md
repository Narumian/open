# Inter-app texture (Syphon-first)

**Invariant: Syphon is only an implementation of the inter-app texture API (`InterAppTextureOutput` / `InterAppTextureInput`); never touch Syphon directly in OpenUI, scenes, or public API.**

OpenVJ exchanges GPU frames with other macOS apps through a **backend-agnostic** API in `OpenVJ`. The **OpenUI** surface is always `InterAppTextureOutput` / `InterAppTextureInput` — Syphon lives only inside the optional `OpenVJSyphon` module.

## Strategy

1. **Ship on macOS with Syphon** — WGPU → Metal ↔ Syphon publish and subscribe in production VJ tools (Resolume, VDMX).
2. **Keep the abstraction** — `InterAppTextureRegistry.Output` / `.Input` factories + `InterAppTexturePublisher` / `InterAppTextureSubscriber` are the stable seam.
3. **Port later** — Windows Spout, LAN NDI, etc. become additional factories, not scene-graph changes.

## Architecture

| Layer | Responsibility |
|-------|----------------|
| `OpenUI` | `InterAppTextureOutput` (publish), `InterAppTextureInput` (receive) |
| `OpenVJ` | Registry, `WGPUVisualRenderer` copy + publish, `WGPUInterAppTextureInputState` import + draw |
| `OpenVJSyphon` | **Only module that imports Syphon SDK** — `SyphonInterAppTexturePublisher`, `SyphonInterAppTextureSubscriber` |
| `OpenVJApp` | Calls `openVJSyphonBootstrap()` on render start when linked; optional menu kill switch |

### Publish path (out)

1. `InterAppTextureOutput("name")` in the view tree → `InterAppTextureRegistry.Output.makePublisher` (no manual Syphon wiring).
2. Render scene to swapchain (BGRA8, `CopySrc`).
3. GPU `copyTextureToTexture` → internal buffer → `SyphonMetalServer.publishFrameTexture` (when clients connected).

### Subscribe path (in)

1. `InterAppTextureInput("ServerName")` in `Add` / `Mixer`.
2. `InterAppTextureRegistry.Input.makeSubscriber` → `SyphonMetalClient` on the shared wgpu Metal device.
3. Each frame: Metal blit from Syphon `MTLTexture` into a WGPU BGRA8 texture, sampled like `Video`.

`openVJSyphonBootstrap()` registers **both** publisher and subscriber factories. `OpenVJApp` invokes it automatically when `OpenVJSyphon` is linked.

## Scene graph examples

Publish + draw:

```swift
Output { InterAppTextureOutput("OpenVJ") }
Add { SomeVisual() }
```

Publish + equal-weight mix:

```swift
Output { InterAppTextureOutput("OpenVJ") }
Add {
    Mixer {
        SinBody()
        Video(path: "/path/to/clip.mov")
    }
}
```

Subscribe + mix a remote inter-app source with local generative output:

```swift
Output { InterAppTextureOutput("OpenVJ") }
Add {
    Mixer {
        SinBody()
        InterAppTextureInput("OtherApp")
    }
}
```

Built-in scenes (`OpenUI`):

| Scene | Use |
|-------|-----|
| `OpenVJLiveScene` | Publish `OpenVJ` + `Mixer { SinBody(); TanBody() }` |
| `OpenVJInterAppMixScene` | Publish + mix subscribed server (default name `OpenVJ`) |
| `OpenVJLiveVideoScene(path:)` | Publish + `Video` in `Mixer` |
| `OpenVJInterAppTextureScene` | Minimal publish demo |

When `OPEN_VJ_INTER_APP_PUBLISH=1` (or legacy `OPEN_VJ_SYPHON=1`) or View → **Publish Inter-App Texture** was on at last launch, `OpenVJApp` selects `OpenVJLiveScene()` as `rootView`. Publish still works from any scene that includes `InterAppTextureOutput` once an inter-app backend is linked.

Source discovery for the macOS source browser uses `InterAppTextureRegistry.Input.availableServers()` / `availableServerNames()` — not Syphon APIs in OpenUI or `OpenVJApp`.

## Migration

| Before | After |
|--------|-------|
| `InterAppTexture("name")` | `Output { InterAppTextureOutput("name") }` |
| `InterAppTexture.subscribe("name")` | `InterAppTextureInput("name")` |
| `InterAppTextureRegistry.makePublisher` | `InterAppTextureRegistry.Output.makePublisher` |
| `InterAppTextureRegistry.makeSubscriber` | `InterAppTextureRegistry.Input.makeSubscriber` |
| `InterAppTextureRegistry.availableInputServers()` | `InterAppTextureRegistry.Input.availableServers()` |

Aliases: `InterAppTextureOutputRegistry`, `InterAppTextureInputRegistry`.

## Backends

| Backend | Platform | Publish | Subscribe |
|---------|----------|---------|-----------|
| **Syphon** | macOS | `OpenVJSyphon` | `OpenVJSyphon` |
| **Spout** | Windows | Planned | Planned |
| **NDI** | Cross-platform | Planned | Planned |

Register factories with `InterAppTextureRegistry.Output.registerFactory` / `InterAppTextureRegistry.Input.registerSubscriberFactory` from optional targets (same pattern as `openVJSyphonBootstrap()`).

## Developer setup (Syphon)

```bash
cd apps/OpenVJ
bash Scripts/fetch-wgpu.sh    # once
bash Scripts/fetch-syphon.sh  # once → Vendor/Syphon.xcframework
swift build
OPEN_VJ_INTER_APP_PUBLISH=1 .build/debug/OpenVJApp
```

Without `Vendor/Syphon.xcframework`, `Package.swift` omits `OpenVJSyphon`; `swift build` still succeeds. Publish/subscribe leaves log once if requested without a backend.

See also [apps/OpenVJ/README.md](../apps/OpenVJ/README.md).

## Verify in other apps

- **Resolume Arena:** Sources → Syphon → **OpenVJ** (scene must include `InterAppTextureOutput("OpenVJ")`).
- **VDMX:** Syphon Input → server **OpenVJ**.
