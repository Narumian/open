import Foundation

enum BGRA8Stats {
    struct Summary: CustomStringConvertible {
        let maxR: Int
        let maxG: Int
        let maxB: Int
        let meanR: Double
        let meanG: Double
        let meanB: Double

        var maxRGB: Int { max(maxR, maxG, maxB) }

        var description: String {
            String(
                format: "maxRGB=%d (R=%d G=%d B=%d) meanRGB=(%.1f, %.1f, %.1f)",
                maxRGB,
                maxR,
                maxG,
                maxB,
                meanR,
                meanG,
                meanB
            )
        }
    }

    static func summarize(_ bgra: Data, width: Int, height: Int) -> Summary? {
        let expected = width * height * 4
        guard bgra.count == expected, expected > 0 else { return nil }
        var maxR = 0
        var maxG = 0
        var maxB = 0
        var sumR: UInt64 = 0
        var sumG: UInt64 = 0
        var sumB: UInt64 = 0
        let pixels = width * height
        bgra.withUnsafeBytes { raw in
            let base = raw.bindMemory(to: UInt8.self)
            for index in 0 ..< pixels {
                let offset = index * 4
                let b = Int(base[offset])
                let g = Int(base[offset + 1])
                let r = Int(base[offset + 2])
                maxB = max(maxB, b)
                maxG = max(maxG, g)
                maxR = max(maxR, r)
                sumB += UInt64(b)
                sumG += UInt64(g)
                sumR += UInt64(r)
            }
        }
        let denom = Double(pixels)
        return Summary(
            maxR: maxR,
            maxG: maxG,
            maxB: maxB,
            meanR: Double(sumR) / denom,
            meanG: Double(sumG) / denom,
            meanB: Double(sumB) / denom
        )
    }
}
