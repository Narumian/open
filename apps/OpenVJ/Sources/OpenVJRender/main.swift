import AppKit
import Foundation
import OpenUI
import OpenVJ
import QuartzCore

struct OpenVJRenderCLI {
    static func main() {
        let args = CommandLine.arguments.dropFirst()
        var outputURL = URL(fileURLWithPath: "frame.png")
        var width: UInt32 = 1280
        var height: UInt32 = 720
        var frameCount = 1
        var sceneName: String? = ProcessInfo.processInfo.environment[OpenVJSceneEnvironment.sceneKey]

        var iterator = args.makeIterator()
        while let arg = iterator.next() {
            switch arg {
            case "--output", "-o":
                guard let path = iterator.next() else { fatalUsage("--output requires a path") }
                outputURL = URL(fileURLWithPath: path)
            case "--width":
                guard let value = iterator.next(), let parsed = UInt32(value) else { fatalUsage("--width requires a number") }
                width = parsed
            case "--height":
                guard let value = iterator.next(), let parsed = UInt32(value) else { fatalUsage("--height requires a number") }
                height = parsed
            case "--frames":
                guard let value = iterator.next(), let parsed = Int(value), parsed > 0 else { fatalUsage("--frames requires a positive integer") }
                frameCount = parsed
            case "--scene":
                guard let value = iterator.next() else { fatalUsage("--scene requires a name") }
                sceneName = value
            case "--help", "-h":
                printUsage()
                return
            default:
                fputs("Unknown argument: \(arg)\n", stderr)
                printUsage()
                exit(2)
            }
        }

        // CAMetalLayer + minimal AppKit bootstrap (no NSWindow).
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)

        let metalLayer = CAMetalLayer()
        metalLayer.pixelFormat = .bgra8Unorm
        metalLayer.drawableSize = CGSize(width: CGFloat(width), height: CGFloat(height))
        metalLayer.frame = CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height))
        metalLayer.isOpaque = true

        let layerPointer = Unmanaged.passUnretained(metalLayer).toOpaque()
        let attachment = VisualSurfaceAttachment(metalLayer: layerPointer)
        guard let renderer = VisualRender.makeRenderer(attachment: attachment) as? WGPUVisualRenderer else {
            fputs("[OpenVJRender] Failed to create WGPU renderer.\n", stderr)
            exit(1)
        }

        renderer.rootView = OpenVJSceneEnvironment.rootView(named: sceneName)
        guard renderer.configure(width: width, height: height) else {
            fputs("[OpenVJRender] configure(\(width), \(height)) failed.\n", stderr)
            exit(1)
        }

        var captured: Data?
        var lastStatus: VisualFrameStatus = .skipped
        for index in 0 ..< frameCount {
            let capture = index == frameCount - 1
            let frameTime = CFTimeInterval(index) / 60.0
            let result = renderer.render(frameTime: frameTime, captureSurfaceBGRA: capture)
            lastStatus = result.status
            if capture {
                captured = result.bgra
            }
        }

        guard lastStatus == .rendered || lastStatus == .renderedSuboptimal else {
            fputs("[OpenVJRender] Render failed with status \(lastStatus).\n", stderr)
            exit(1)
        }
        guard let bgra = captured else {
            fputs("[OpenVJRender] Frame readback failed.\n", stderr)
            exit(1)
        }

        do {
            try BGRA8PNG.write(bgra, width: Int(width), height: Int(height), to: outputURL)
        } catch {
            fputs("[OpenVJRender] PNG write failed: \(error.localizedDescription)\n", stderr)
            exit(1)
        }

        print(outputURL.path)
    }

    private static func fatalUsage(_ message: String) -> Never {
        fputs("\(message)\n", stderr)
        printUsage()
        exit(2)
    }

    private static func printUsage() {
        let text = """
        OpenVJRender — headless offscreen frame export (no window, no Source Browser UI)

        Usage:
          swift run OpenVJRender --output /tmp/frame.png [options]

        Options:
          -o, --output <path>   PNG output path (default: ./frame.png)
          --width <px>          Render width (default: 1280)
          --height <px>         Render height (default: 720)
          --frames <n>          Warm-up frames before capture (default: 1)
          --scene <name>        Scene name (overrides OPEN_VJ_SCENE)
          -h, --help            Show help

        Environment:
          OPEN_VJ_SCENE         default | source-browser-mixer | live | timed-demo

        Example:
          OPEN_VJ_SCENE=source-browser-mixer swift run OpenVJRender --output /tmp/frame.png
        """
        print(text)
    }
}

OpenVJRenderCLI.main()
