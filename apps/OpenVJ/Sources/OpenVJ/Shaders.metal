#include <metal_stdlib>
using namespace metal;

struct VisualUniforms {
    float time;
    float2 resolution;
};

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

vertex VertexOut visualVertex(uint vertexID [[vertex_id]]) {
    float2 positions[3] = {
        float2(-1.0, -1.0),
        float2( 3.0, -1.0),
        float2(-1.0,  3.0),
    };
    VertexOut out;
    out.position = float4(positions[vertexID], 0.0, 1.0);
    out.uv = positions[vertexID] * 0.5 + 0.5;
    return out;
}

static float hash21(float2 p) {
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

static float noise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    float a = hash21(i);
    float b = hash21(i + float2(1.0, 0.0));
    float c = hash21(i + float2(0.0, 1.0));
    float d = hash21(i + float2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

fragment float4 visualFragment(VertexOut in [[stage_in]],
                               constant VisualUniforms &u [[buffer(0)]]) {
    float2 uv = in.uv;
    float aspect = u.resolution.x / max(u.resolution.y, 1.0);
    float2 p = (uv - 0.5) * float2(aspect, 1.0);

    float t = u.time * 0.35;
    float2 warp = float2(
        sin(p.y * 3.0 + t) * 0.15,
        cos(p.x * 2.5 - t * 1.1) * 0.15
    );
    float2 q = p + warp;
    float n = noise(q * 4.0 + t);
    float bands = sin((length(q) - t * 0.4) * 12.0 + n * 6.0);

    float3 col = float3(
        0.45 + 0.35 * sin(t + bands * 2.0 + n),
        0.25 + 0.45 * cos(t * 0.7 + bands),
        0.55 + 0.35 * sin(t * 1.3 - n * 3.0)
    );
    col *= 0.65 + 0.35 * bands;
    return float4(col, 1.0);
}
