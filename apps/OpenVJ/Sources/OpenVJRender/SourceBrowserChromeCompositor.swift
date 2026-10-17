import AppKit
import CoreGraphics
import CoreText
import Foundation
import OpenUI

/// CPU-drawn Sources panel for headless PNG export (matches `SourceBrowserController` chrome).
enum SourceBrowserChromeCompositor {
    static let panelWidth = 360
    private static let background = (r: 26, g: 26, b: 26)
    private static let headerBar = (r: 34, g: 34, b: 38)
    private static let panelBorder = (r: 48, g: 48, b: 52)
    private static let folderGlyphFace = (r: 96, g: 168, b: 255)
    private static let folderGlyphTab = (r: 72, g: 132, b: 210)
    private static let titleText = (r: 238, g: 238, b: 238)
    private static let bodyText = (r: 238, g: 238, b: 238)
    private static let mutedText = (r: 170, g: 170, b: 175)
    private static let rowAlt = (r: 34, g: 34, b: 38)
    private static let rowSelected = (r: 10, g: 132, b: 255)
    private static let rowSelectedText = (r: 255, g: 255, b: 255)
    private static let divider = (r: 56, g: 56, b: 60)

    static let rowHeight = 28
    static let titleBarHeight = 44
    static let listTopPadding = 4

    /// Places mixer GPU output in the right pane and draws the Sources list on the left.
    static func composite(
        bgra: inout Data,
        width: Int,
        height: Int,
        rows: [SourceBrowserListModel.Row],
        selectedIndex: Int
    ) {
        guard width > panelWidth, height > 0 else { return }
        let bytesPerRow = width * 4
        guard bgra.count == bytesPerRow * height else { return }

        let gpuSnapshot = bgra
        let previewX = panelWidth
        let previewW = width - panelWidth
        blitScale(
            source: gpuSnapshot,
            sourceWidth: width,
            sourceHeight: height,
            into: &bgra,
            destWidth: width,
            destHeight: height,
            destX: previewX,
            destY: 0,
            regionWidth: previewW,
            regionHeight: height
        )

        bgra.withUnsafeMutableBytes { raw in
            guard let base = raw.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            fillRect(
                base,
                width: width,
                height: height,
                x: 0,
                y: 0,
                w: panelWidth,
                h: height,
                r: background.r,
                g: background.g,
                b: background.b
            )
            fillRect(
                base,
                width: width,
                height: height,
                x: 0,
                y: 0,
                w: panelWidth,
                h: titleBarHeight,
                r: headerBar.r,
                g: headerBar.g,
                b: headerBar.b
            )
            fillRect(base, width: width, height: height, x: 0, y: 0, w: 1, h: height, r: panelBorder.r, g: panelBorder.g, b: panelBorder.b)
            fillRect(base, width: width, height: height, x: panelWidth - 1, y: 0, w: 1, h: height, r: panelBorder.r, g: panelBorder.g, b: panelBorder.b)
            drawVerticalDivider(base, width: width, height: height, x: panelWidth - 1)

            drawTitle("Sources", in: base, width: width, height: height)

            let listTop = titleBarHeight + listTopPadding
            let visibleRows = max(1, (height - listTop - 8) / rowHeight)
            let scrollOffset = max(0, selectedIndex - visibleRows / 2)

            for rowIndex in 0 ..< min(rows.count, scrollOffset + visibleRows + 2) {
                let screenRow = rowIndex - scrollOffset
                guard screenRow >= 0, screenRow < visibleRows else { continue }
                let y = listTop + screenRow * rowHeight
                guard y + rowHeight <= height else { break }

                let isSelected = rowIndex == selectedIndex
                if isSelected {
                    fillRect(
                        base,
                        width: width,
                        height: height,
                        x: 0,
                        y: y,
                        w: panelWidth,
                        h: rowHeight,
                        r: rowSelected.r,
                        g: rowSelected.g,
                        b: rowSelected.b
                    )
                } else if rowIndex.isMultiple(of: 2) {
                    fillRect(
                        base,
                        width: width,
                        height: height,
                        x: 0,
                        y: y,
                        w: panelWidth,
                        h: rowHeight,
                        r: rowAlt.r,
                        g: rowAlt.g,
                        b: rowAlt.b
                    )
                }

                if showsFolderGlyph(rows[rowIndex]) {
                    drawFolderGlyph(base, width: width, height: height, x: 10, y: y + 8)
                }

                let label = rowLabel(rows[rowIndex])
                let textColor: (r: Int, g: Int, b: Int) = isSelected ? rowSelectedText : bodyText
                drawText(
                    label,
                    in: base,
                    width: width,
                    height: height,
                    x: 34,
                    y: y + 6,
                    maxWidth: panelWidth - 42,
                    color: textColor,
                    fontSize: 13,
                    weight: isSelected ? .semibold : .regular
                )

                if !isSelected {
                    fillRect(
                        base,
                        width: width,
                        height: height,
                        x: 8,
                        y: y + rowHeight - 1,
                        w: panelWidth - 16,
                        h: 1,
                        r: divider.r,
                        g: divider.g,
                        b: divider.b
                    )
                }
            }

            if rows.count > visibleRows {
                let hintY = height - 22
                drawText(
                    "Scroll ↕ \(rows.count) sources",
                    in: base,
                    width: width,
                    height: height,
                    x: 12,
                    y: hintY,
                    maxWidth: panelWidth - 16,
                    color: mutedText,
                    fontSize: 11,
                    weight: .regular
                )
            }
        }

        drawPreviewChrome(bgra: &bgra, width: width, height: height, previewX: previewX, previewW: previewW)
    }

    private static func drawPreviewChrome(
        bgra: inout Data,
        width: Int,
        height: Int,
        previewX: Int,
        previewW: Int
    ) {
        bgra.withUnsafeMutableBytes { raw in
            guard let base = raw.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            fillRect(
                base,
                width: width,
                height: height,
                x: previewX,
                y: 0,
                w: previewW,
                h: 3,
                r: panelBorder.r,
                g: panelBorder.g,
                b: panelBorder.b
            )
            drawText(
                "Mixer preview",
                in: base,
                width: width,
                height: height,
                x: previewX + 12,
                y: 10,
                maxWidth: previewW - 24,
                color: mutedText,
                fontSize: 11,
                weight: .medium
            )
        }
    }

    private static func blitScale(
        source: Data,
        sourceWidth: Int,
        sourceHeight: Int,
        into dest: inout Data,
        destWidth: Int,
        destHeight: Int,
        destX: Int,
        destY: Int,
        regionWidth: Int,
        regionHeight: Int
    ) {
        guard source.count == sourceWidth * sourceHeight * 4 else { return }
        source.withUnsafeBytes { srcRaw in
            dest.withUnsafeMutableBytes { dstRaw in
                guard let src = srcRaw.baseAddress?.assumingMemoryBound(to: UInt8.self),
                      let dst = dstRaw.baseAddress?.assumingMemoryBound(to: UInt8.self)
                else { return }
                for dy in 0 ..< regionHeight {
                    let sy = min(sourceHeight - 1, dy * sourceHeight / max(regionHeight, 1))
                    for dx in 0 ..< regionWidth {
                        let sx = min(sourceWidth - 1, dx * sourceWidth / max(regionWidth, 1))
                        let srcIndex = (sy * sourceWidth + sx) * 4
                        let dstIndex = ((destY + dy) * destWidth + (destX + dx)) * 4
                        dst[dstIndex] = src[srcIndex]
                        dst[dstIndex + 1] = src[srcIndex + 1]
                        dst[dstIndex + 2] = src[srcIndex + 2]
                        dst[dstIndex + 3] = src[srcIndex + 3]
                    }
                }
            }
        }
    }

    private static func fillRect(
        _ base: UnsafeMutablePointer<UInt8>,
        width: Int,
        height: Int,
        x: Int,
        y: Int,
        w: Int,
        h: Int,
        r: Int,
        g: Int,
        b: Int,
        a: UInt8 = 255
    ) {
        let x0 = max(0, x)
        let y0 = max(0, y)
        let x1 = min(width, x + w)
        let y1 = min(height, y + h)
        for py in y0 ..< y1 {
            for px in x0 ..< x1 {
                let index = (py * width + px) * 4
                base[index] = UInt8(b)
                base[index + 1] = UInt8(g)
                base[index + 2] = UInt8(r)
                base[index + 3] = a
            }
        }
    }

    private static func drawVerticalDivider(_ base: UnsafeMutablePointer<UInt8>, width: Int, height: Int, x: Int) {
        fillRect(base, width: width, height: height, x: x, y: 0, w: 1, h: height, r: divider.r, g: divider.g, b: divider.b)
    }

    private static func showsFolderGlyph(_ row: SourceBrowserListModel.Row) -> Bool {
        if case .source(let descriptor) = row.selection, case .localFile = descriptor.kind {
            return true
        }
        return false
    }

    private static func rowLabel(_ row: SourceBrowserListModel.Row) -> String {
        let title = row.title
        if title.hasPrefix("📁 ") {
            return String(title.dropFirst(2))
        }
        return title
    }

    private static func drawFolderGlyph(
        _ base: UnsafeMutablePointer<UInt8>,
        width: Int,
        height: Int,
        x: Int,
        y: Int
    ) {
        fillRect(base, width: width, height: height, x: x, y: y + 3, w: 16, h: 11, r: folderGlyphFace.r, g: folderGlyphFace.g, b: folderGlyphFace.b)
        fillRect(base, width: width, height: height, x: x, y: y, w: 8, h: 4, r: folderGlyphTab.r, g: folderGlyphTab.g, b: folderGlyphTab.b)
    }

    private static func drawTitle(_ title: String, in base: UnsafeMutablePointer<UInt8>, width: Int, height: Int) {
        drawText(
            title,
            in: base,
            width: width,
            height: height,
            x: 14,
            y: 14,
            maxWidth: panelWidth - 28,
            color: titleText,
            fontSize: 15,
            weight: .semibold
        )
        fillRect(
            base,
            width: width,
            height: height,
            x: 0,
            y: titleBarHeight - 1,
            w: panelWidth,
            h: 1,
            r: divider.r,
            g: divider.g,
            b: divider.b
        )
    }

    private enum FontWeight {
        case regular, medium, semibold
    }

    private static func drawText(
        _ string: String,
        in base: UnsafeMutablePointer<UInt8>,
        width: Int,
        height: Int,
        x: Int,
        y: Int,
        maxWidth: Int,
        color: (r: Int, g: Int, b: Int),
        fontSize: CGFloat,
        weight: FontWeight
    ) {
        let fontWeight: NSFont.Weight = switch weight {
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        }
        let font = NSFont.systemFont(ofSize: fontSize, weight: fontWeight)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor(
                red: CGFloat(color.r) / 255,
                green: CGFloat(color.g) / 255,
                blue: CGFloat(color.b) / 255,
                alpha: 1
            ),
        ]
        let attributed = NSAttributedString(string: string, attributes: attributes)
        let line = CTLineCreateWithAttributedString(attributed)
        let bounds = CTLineGetBoundsWithOptions(line, [])
        let drawWidth = min(maxWidth, Int(bounds.width.rounded(.up)))
        let drawHeight = max(Int(fontSize.rounded(.up)) + 4, Int(bounds.height.rounded(.up)))
        guard drawWidth > 0, drawHeight > 0, x + drawWidth <= width, y + drawHeight <= height else {
            return
        }

        var scratch = [UInt8](repeating: 0, count: drawWidth * drawHeight * 4)
        scratch.withUnsafeMutableBytes { scratchRaw in
            guard let scratchBase = scratchRaw.baseAddress else { return }
            let bitmapInfo = CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
            guard let ctx = CGContext(
                data: scratchBase,
                width: drawWidth,
                height: drawHeight,
                bitsPerComponent: 8,
                bytesPerRow: drawWidth * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: bitmapInfo
            ) else { return }
            ctx.clear(CGRect(x: 0, y: 0, width: drawWidth, height: drawHeight))
            ctx.textMatrix = .identity
            ctx.translateBy(x: 0, y: CGFloat(drawHeight))
            ctx.scaleBy(x: 1, y: -1)
            let ascent = CTFontGetAscent(font)
            ctx.textPosition = CGPoint(x: 0, y: CGFloat(drawHeight) - ascent)
            CTLineDraw(line, ctx)
        }

        for row in 0 ..< drawHeight {
            for col in 0 ..< drawWidth {
                let si = (row * drawWidth + col) * 4
                let alpha = scratch[si + 3]
                guard alpha > 0 else { continue }
                let dx = x + col
                let dy = y + (drawHeight - 1 - row)
                guard dx >= 0, dy >= 0, dx < width, dy < height else { continue }
                let di = (dy * width + dx) * 4
                let srcB = scratch[si]
                let srcG = scratch[si + 1]
                let srcR = scratch[si + 2]
                let a = Float(alpha) / 255
                let inv = 1 - a
                base[di] = UInt8(min(255, Float(base[di]) * inv + Float(srcB) * a))
                base[di + 1] = UInt8(min(255, Float(base[di + 1]) * inv + Float(srcG) * a))
                base[di + 2] = UInt8(min(255, Float(base[di + 2]) * inv + Float(srcR) * a))
                base[di + 3] = 255
            }
        }
    }
}
