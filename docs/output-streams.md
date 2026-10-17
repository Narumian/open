# Output streams

OpenUI groups **export sinks** under `Output { }`. Visual layers stay in `Add` / `Mixer`. Syphon is never referenced in OpenUI — GPU texture publish uses `InterAppTextureOutput` → `InterAppTextureRegistry` → optional `OpenVJSyphon`.

## OpenUI surface

| Leaf | Role | Status |
|------|------|--------|
| `InterAppTextureOutput("name")` | GPU texture bus out (inter-app) | **Implemented** (Syphon when `OpenVJSyphon` linked) |
| `InterAppTextureInput("name")` | GPU texture bus in (draw layer) | **Implemented** |
| `VirtualCamera("name")` | macOS virtual camera publish | **Stub** (`OpenVJVirtualCam` when linked) |
| `EncodedStream(preset:)` | H.264/HEVC encoded stream | **Stub** |
| `FileRecording("path")` | Disk recording | **Stub** |
| `RawSampleBuffer()` | CPU sample buffer tap | **Stub** |
| `MuxedBroadcastStream("endpoint")` | RTMP/SRT/WebRTC mux | **Stub** |

## Example scene

```swift
Output {
    InterAppTextureOutput("OpenVJ")
    // VirtualCamera("OpenVJ")
    // EncodedStream(preset: .h264)
}
Add {
    Mixer {
        SinBody()
        TanBody().time(OpenVJSceneTime.current)
    }
}
```

Incoming remote frames use `InterAppTextureInput("name")` inside `Mixer`, not inside `Output`.

## OpenVJ protocols (target shape)

| Protocol / type | Purpose | Status |
|-----------------|---------|--------|
| `OutputStream` | `attach(renderer:)`, `submitFrame(CompositedFrame)` | Planned |
| `OutputSink` | Lifecycle + resize on renderer | Planned |
| `GPUTextureStream` | Composited BGRA8 WGPU texture fan-out | **Partial** (inter-app publish path today) |
| `VideoEncoderStream` | VTCompressionSession / encoder | **Stub** |
| `AudioStream` | Audio bus | **Stub** |
| `MuxedBroadcastStream` | Mux + network | **Stub** |

`CompositedFrame` is designed to carry GPU texture handles, CPU buffers, or encoded packets over time; only the GPU texture path is wired for publish today.

## Naming (parallel branches)

- **Out:** `InterAppTextureOutput` (was `InterAppTexture`)
- **In:** `InterAppTextureInput` (unchanged)
- Subscribe factory: `InterAppTextureInput.subscribe("Server")` (was `InterAppTexture.subscribe`)

See also [inter-app-texture.md](inter-app-texture.md).
