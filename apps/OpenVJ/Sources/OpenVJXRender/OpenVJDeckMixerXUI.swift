import Foundation
import XRender
import XShader
import XUI
import XUIHost

/// Full-screen deck layer inside an X3D `Camera` (rasterised as a plane per frame).
struct OpenVJDeckLayerView: XView {
    @EnvironmentObject private var frameContext: OpenVJFrameContext
    let deck: String

    var body: some XView {
        SceneDraw { rect, builder, _ in
            frameContext.onPresentSourceBrowser?(deck)
            frameContext.drawDeck?(deck, &builder, rect.render)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// `Mixer { Deck A; Deck B } → OffscreenTexture("mix") → swapchain` as native X3D.
struct OpenVJDeckMixerGraph: X3DProgram {
    var body: some X3DProgram {
        Texture("mix", format: .rgba8Unorm, size: .target)
        Pass(into: "mix", load: .clear(SIMD4(0, 0, 0, 1))) {
            Camera(position: SIMD3(0, 0, 2.5), fieldOfView: .pi / 3) {
                OpenVJDeckLayerView(deck: "A")
                OpenVJDeckLayerView(deck: "B")
            }
        }
        Pass(into: .output, load: .clear(SIMD4(0, 0, 0, 1))) {
            Blit("mix")
        }
    }
}

/// Root XView: one full-window `X3DView` hosting the deck mixer graph.
struct OpenVJDeckMixerXUIView: XView {
    var body: some XView {
        X3DView {
            OpenVJDeckMixerGraph()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

enum OpenVJXUITextureCatalog {
    /// Maps `Texture("name")` resources from a compiled scene to their `X3DResourceID`s.
    static func textureIDs(in scene: Scene) -> [String: X3DResourceID] {
        var map: [String: X3DResourceID] = [:]
        for command in scene.commands {
            guard case .x3d(let x3d) = command else { continue }
            for resource in x3d.graph.resources {
                if case .texture(let id, _, _) = resource {
                    map[id.name] = id
                }
            }
        }
        return map
    }
}
