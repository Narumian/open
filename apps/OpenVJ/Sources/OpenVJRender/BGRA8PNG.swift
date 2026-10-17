import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum BGRA8PNG {
    static func write(_ bgra: Data, width: Int, height: Int, to url: URL) throws {
        let bytesPerRow = width * 4
        guard width > 0, height > 0, bgra.count >= bytesPerRow * height else {
            throw NSError(domain: "OpenVJRender", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid BGRA buffer size"])
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Little.union(
            CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)
        )
        guard let provider = CGDataProvider(data: bgra as CFData) else {
            throw NSError(domain: "OpenVJRender", code: 2, userInfo: [NSLocalizedDescriptionKey: "CGDataProvider failed"])
        }
        guard let image = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ) else {
            throw NSError(domain: "OpenVJRender", code: 3, userInfo: [NSLocalizedDescriptionKey: "CGImage failed"])
        }

        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw NSError(domain: "OpenVJRender", code: 4, userInfo: [NSLocalizedDescriptionKey: "PNG destination failed"])
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw NSError(domain: "OpenVJRender", code: 5, userInfo: [NSLocalizedDescriptionKey: "PNG finalize failed"])
        }
    }
}
