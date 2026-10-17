import XShader

enum OpenVJX3DGenerativeShader {
    static let key = ShaderKey("openvj.wave")

    /// Fragment-only WGSL (prepended with `x3dPreludeWGSL` in `WGPURenderer`).
    /// Uniforms via `x3dParams`: waveMode @0, layerAlpha @1.
    static let fragmentWGSL = """
    @fragment
    fn openvj_wave_fs(in: X3DFullscreen) -> @location(0) vec4<f32> {
        let time = x3d.time * 0.35;
        let waveMode = x3dParams[0];
        let layerAlpha = x3dParams[1];
        let uv = in.uv;
        let aspect = x3d.resolution.x / max(x3d.resolution.y, 1.0);
        var p = (uv - vec2(0.5)) * vec2(aspect, 1.0);

        let sinWarp = vec2(
            sin(p.y * 3.0 + time) * 0.15,
            cos(p.x * 2.5 - time * 1.1) * 0.15
        );
        let tanWarp = vec2(
            tanh(p.y * 2.2 + time * 1.2) * 0.22,
            tanh(p.x * 1.9 - time * 0.9) * 0.22
        );
        let useTan = waveMode > 0.5;
        let warp = select(sinWarp, tanWarp, useTan);
        let q = p + warp;
        let n = fract(sin(dot(q * 4.0 + time, vec2(127.1, 311.7))) * 43758.5453);
        let bands = sin((length(q) - time * 0.4) * 12.0 + n * 6.0);

        var col = vec3(
            0.45 + 0.35 * sin(time + bands * 2.0 + n),
            0.25 + 0.45 * cos(time * 0.7 + bands),
            0.55 + 0.35 * sin(time * 1.3 - n * 3.0)
        );
        if (useTan) {
            col = vec3(
                0.35 + 0.45 * cos(time * 0.8 + bands * 1.5),
                0.40 + 0.40 * sin(time * 1.1 - n * 4.0),
                0.50 + 0.35 * cos(time * 0.6 + bands)
            );
        }
        col *= 0.65 + 0.35 * bands;
        return vec4(col, layerAlpha);
    }
    """
}
