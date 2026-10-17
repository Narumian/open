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

/** Mirrors OpenUI `SourcePlaybackContext` + `SequenceTransportState` (host advances clip index). */
export type SequenceTransportState = {
  clips: string[];
  loops: boolean;
  clipIndex: number;
  elapsedInClip: number;
};

export type SourcePlaybackContext = {
  selection: SourceSelection;
  sequence?: SequenceTransportState;
};

export const DEFAULT_CLIP_DURATION_SEC = 10;

/**
 * Mirrors OpenUI `VideoPlayer` (host implements decode + `drawCurrentFrame`).
 * Separate from `PlaybackHost` duration probes / `makeVideoPlayer` injection on the render context.
 */
export type VideoPlayer = {
  fileURL: string;
  loops: boolean;
  isPlaying: boolean;
  currentTimeSeconds: number;
  durationSeconds?: number;
  play(): void;
  pause(): void;
  seek(toSeconds: number): void;
  drawCurrentFrame(layerAlpha: number): void;
};

export function tickSequenceTransport(
  state: SequenceTransportState,
  deltaSec: number,
  resolveDuration: (url: string) => number | undefined,
): SequenceTransportState {
  if (state.clips.length === 0 || deltaSec <= 0) return state;
  let { clipIndex, elapsedInClip, clips, loops } = state;
  elapsedInClip += deltaSec;
  let duration =
    resolveDuration(clips[clipIndex]) ?? DEFAULT_CLIP_DURATION_SEC;
  if (duration <= 0) duration = DEFAULT_CLIP_DURATION_SEC;

  while (elapsedInClip >= duration) {
    elapsedInClip -= duration;
    const next = clipIndex + 1;
    if (next < clips.length) {
      clipIndex = next;
    } else if (loops) {
      clipIndex = 0;
    } else {
      clipIndex = clips.length - 1;
      elapsedInClip = duration;
      break;
    }
    duration = resolveDuration(clips[clipIndex]) ?? DEFAULT_CLIP_DURATION_SEC;
    if (duration <= 0) duration = DEFAULT_CLIP_DURATION_SEC;
  }

  return { clips, loops, clipIndex, elapsedInClip };
}
