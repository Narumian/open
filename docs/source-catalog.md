# Source catalog

**Invariant: OpenUI describes pickable inputs with `Source*` types only; Syphon and other backends never appear in OpenUI.**

Hosts register a `SourceCatalog` at launch. The `SourceBrowser()` view walks the scene graph, opens the host browser UI when registered, and draws the current `SourceSelection`.

## OpenUI types

| Type | Role |
|------|------|
| `Source` | Protocol: `id`, `displayName`, `kind` |
| `SourceKind` | `.localFile`, `.interAppInput`, `.url` (stub), `.captureDevice` (stub) |
| `SourceDescriptor` | Stable `id` + display metadata for a catalog row |
| `SourceSelection` | `.none` or `.source(SourceDescriptor)` |
| `SourceSelectionState` | Thread-safe shared selection + media folder URL |
| `SourceCatalog` | `refresh()`, `sources`, `selectionState` |
| `SourceCatalogRegistry` | `register(_:)` / `current` — set from the app target |
| `SourceBrowser` | Leaf view: present UI + render selection |

### Render mapping

During tree walk, `SourceBrowser` maps the active selection to existing leaves internally:

- `SourceKind.localFile` → `Video` draw path
- `SourceKind.interAppInput` → `InterAppTextureInput` draw path
- `.url` / `.captureDevice` → no-op on macOS v0

## macOS (`OpenVJApp`)

`MacSourceCatalog` implements `SourceCatalog`:

1. Scans `selectionState.mediaFolderURL` (default: Movies) for video files.
2. Appends `InterAppTextureRegistry.Input.availableServers()` (Syphon discovery lives in `OpenVJSyphon`, not OpenUI).

`VisualView` constructs the catalog, calls `SourceCatalogRegistry.register`, and `SourceBrowserController` drives the same `SourceSelectionState`.

## Web (minimal)

TypeScript mirrors for a future browser host (`apps/open/web/source.ts`):

```ts
export type SourceKind =
  | { type: "localFile"; url: string }
  | { type: "interAppInput"; serverName: string }
  | { type: "url"; url: string }
  | { type: "captureDevice"; deviceId: string | null };

export type SourceDescriptor = {
  id: string;
  displayName: string;
  kind: SourceKind;
};

export type SourceSelection =
  | { type: "none" }
  | { type: "source"; descriptor: SourceDescriptor };
```

v0 Web support: **file input only** — bind a chosen `File` to `localFile` and skip inter-app / capture until a host catalog exists.

## Scene example

```swift
Mixer {
    SourceBrowser()
    Some()
}
```

See also [inter-app-texture.md](./inter-app-texture.md) for subscribe/publish details.
