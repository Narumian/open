# Virtual camera (OpenUI `VirtualCamera`)

OpenVJ can expose composited frames as a **macOS system camera** (FaceTime, Zoom, OBS “Camera” source) through a backend-agnostic API in `OpenVJ`. **OpenUI** only exposes `VirtualCamera("label")` as a scene-graph leaf — no CMIO or plugin types in `OpenUI`.

See also [inter-app-texture.md](inter-app-texture.md) for Syphon / `InterAppTexture` (VJ-to-VJ, no system camera).

## When is 常駐 (always-on) needed?

| Output | Who must be running | Separate daemon? |
|--------|---------------------|------------------|
| **Syphon / `InterAppTexture`** | OpenVJ (or any host app) during the performance | **No** — the app’s render loop publishes each frame; quit the app and the server disappears. |
| **Virtual camera / `VirtualCamera`** | A **host process** for the whole time the camera should appear in other apps | **While streaming:** yes — something must feed CMIO (main app or agent). **Optional 常駐:** only if the camera must exist when the main UI is closed. |

### Virtual camera host tradeoffs

| Approach | Camera visible when main window closed? | Complexity | Typical use |
|----------|----------------------------------------|------------|-------------|
| **OpenVJApp only** (default) | No — quitting or closing stops the stream | Lowest | Rehearsal, single-machine VJ + Zoom |
| **Menu-bar agent (`OpenVJAgent`, future)** | Yes — agent keeps `rootView` + render loop alive | Medium — second process, shared scene config | “Always have OpenVJ cam in meeting list” |
| **System-wide CMIO plugin** | Yes — device registered until uninstall | High — DAL bundle, signing, OBS-style lifecycle | Productized virtual cam for all apps |

**Recommendation:** Use **on-demand via OpenVJApp** unless you need the device in the camera list while the main UI is quit; then add a small **常駐 menu-bar agent** that runs the same `OpenUI` scene graph, not a separate “texture daemon” for Syphon.

## Architecture

| Layer | Responsibility |
|-------|----------------|
| `OpenUI` | `VirtualCamera` leaf → `ViewRenderContext.requestVirtualCameraPublish` |
| `OpenVJ` | `VirtualCameraRegistry`, `WGPUVisualRenderer` composited copy + `publish(texture:)` |
| `OpenVJVirtualCam` | v0 **stub** publisher (logs path); future CMIO / shared-memory sink |
| `OpenVJApp` | Default **non-常駐** host; links `OpenVJVirtualCam` and calls `openVJVirtualCamBootstrap()` |

Frame path (same composited BGRA buffer as Syphon when both leaves are present):

1. Render scene to swapchain.
2. GPU copy to internal BGRA8 buffer (when any publish leaf is active).
3. Flush WGPU queue.
4. `VirtualCameraPublisher.publish(texture:)` (stub: validate + log; real: Metal → CMIO extension).

## Scene graph example

Publish to virtual camera, Syphon, and mix a remote inter-app source:

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

Built-in: `OpenVJVirtualCamMixScene(remoteServerName:)` in module `OpenUI`.

## Host apps

| Target | Role |
|--------|------|
| **OpenVJApp** | Default host — window + render loop; virtual cam exists only while the app runs and the scene includes `VirtualCamera`. |
| **OpenVJAgent** (future) | Optional LSUIElement menu-bar host running the same `rootView` / scene for 常駐 camera without the main window. Not shipped in v0; see [apps/OpenVJ/README.md](../apps/OpenVJ/README.md). |

## Backend status (`VirtualCameraPublisher`)

| Backend | Status | Notes |
|---------|--------|-------|
| **OpenVJVirtualCam stub** | **Implemented** | Registers via `openVJVirtualCamBootstrap()`; no CMIO device yet |
| **CMIO DAL plugin** | Planned | OBS Virtual Camera model; IOSurface or shared memory from host |
| **Third-party bridge** | Optional | Document-only integration with existing OBS virtual cam |

Register a backend with `VirtualCameraRegistry.registerPublisherFactory` (same pattern as `InterAppTextureRegistry`).

## Developer setup

```bash
cd apps/OpenVJ
bash Scripts/fetch-wgpu.sh   # once
swift build
.build/debug/OpenVJApp
```

`OpenVJVirtualCam` has no vendor SDK; `swift build` always links the stub when building `OpenVJApp`. Omit the `OpenVJVirtualCam` dependency from custom hosts if you do not need virtual camera (publish leaves will log once).

Without a real CMIO backend, pick **OpenVJ** in a meeting app will not show video yet; stderr shows stub publish lines and the integration note on first attach.
