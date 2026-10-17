# Deferred OpenUI playback DSL

`VJPlaybackDSL.swift` holds `VJPlayer`, `Sequence`, and `SequencePlayer` scaffolding. It is **excluded** from the `OpenUI` target in `Package.swift` until multi-clip transport is implemented.

Restore by removing the `exclude` entry and re-adding sequence hooks on `SourcePlaybackContext` / `ViewRenderContext`.
