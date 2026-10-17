/** Mirrors OpenUI `Source*` types for a future browser host (file input v0). */

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

export function sourceId(kind: SourceKind): string {
  switch (kind.type) {
    case "localFile":
      return `file:${kind.url}`;
    case "interAppInput":
      return `inter-app:${kind.serverName}`;
    case "url":
      return `url:${kind.url}`;
    case "captureDevice":
      return `capture:${kind.deviceId ?? "default"}`;
  }
}

/** v0: wrap a user-picked file as the only supported web source. */
export function localFileFromFile(file: File): SourceDescriptor {
  const url = URL.createObjectURL(file);
  const kind: SourceKind = { type: "localFile", url };
  return {
    id: sourceId(kind),
    displayName: file.name,
    kind,
  };
}
