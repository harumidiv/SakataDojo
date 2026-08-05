import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct ScreenshotSpec {
    let key: String
    let title: String
    let subtitle: String
    let accent: NSColor
}

struct CanvasSpec {
    let width: Int
    let height: Int
    let backgroundPath: String
    let rawPrefix: String
    let outputDirectory: String
    let deviceTop: CGFloat
    let deviceWidth: CGFloat
    let deviceFrame: CGFloat
    let deviceRadius: CGFloat
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

let screenshots = [
    ScreenshotSpec(
        key: "title",
        title: "ローソク足を、\n見抜く。",
        subtitle: "実例チャートで酒田の型を楽しく学ぶ",
        accent: NSColor(calibratedRed: 0.23, green: 0.83, blue: 1.00, alpha: 1)
    ),
    ScreenshotSpec(
        key: "direction",
        title: "上がる？\n下がる？",
        subtitle: "値動きを見て、その後の方向を予測",
        accent: NSColor(calibratedRed: 0.10, green: 0.54, blue: 1.00, alpha: 1)
    ),
    ScreenshotSpec(
        key: "pattern",
        title: "30の型を\n4択で習得",
        subtitle: "形からパターン名を見抜くトレーニング",
        accent: NSColor(calibratedRed: 0.96, green: 0.23, blue: 0.76, alpha: 1)
    ),
    ScreenshotSpec(
        key: "answer",
        title: "答えの先まで、\n見える。",
        subtitle: "正解と、その後の値動きを確認",
        accent: NSColor(calibratedRed: 1.00, green: 0.25, blue: 0.34, alpha: 1)
    ),
    ScreenshotSpec(
        key: "study",
        title: "30パターンを\n図鑑で復習",
        subtitle: "意味・見方・実例チャートをいつでも確認",
        accent: NSColor(calibratedRed: 1.00, green: 0.67, blue: 0.20, alpha: 1)
    )
]

let canvases = [
    CanvasSpec(
        width: 1284,
        height: 2778,
        backgroundPath: "AppStoreScreenshots/backgrounds/neon_phone.png",
        rawPrefix: "iphone",
        outputDirectory: "AppStoreScreenshots/6.5-inch",
        deviceTop: 720,
        deviceWidth: 920,
        deviceFrame: 25,
        deviceRadius: 82
    ),
    CanvasSpec(
        width: 2064,
        height: 2752,
        backgroundPath: "AppStoreScreenshots/backgrounds/neon_ipad.png",
        rawPrefix: "ipad",
        outputDirectory: "AppStoreScreenshots/13-inch",
        deviceTop: 680,
        deviceWidth: 1600,
        deviceFrame: 30,
        deviceRadius: 54
    )
]

func rectFromTop(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, canvasHeight: CGFloat) -> NSRect {
    NSRect(x: x, y: canvasHeight - y - height, width: width, height: height)
}

func drawImageCover(_ image: NSImage, in destination: NSRect) {
    let sourceSize = image.size
    let sourceAspect = sourceSize.width / sourceSize.height
    let destinationAspect = destination.width / destination.height
    var sourceRect = NSRect(origin: .zero, size: sourceSize)

    if sourceAspect > destinationAspect {
        let width = sourceSize.height * destinationAspect
        sourceRect.origin.x = (sourceSize.width - width) / 2
        sourceRect.size.width = width
    } else {
        let height = sourceSize.width / destinationAspect
        sourceRect.origin.y = (sourceSize.height - height) / 2
        sourceRect.size.height = height
    }

    image.draw(in: destination, from: sourceRect, operation: .copy, fraction: 1)
}

func drawText(
    _ text: String,
    rect: NSRect,
    font: NSFont,
    color: NSColor,
    lineSpacing: CGFloat = 0,
    kern: CGFloat = 0
) {
    let style = NSMutableParagraphStyle()
    style.lineSpacing = lineSpacing
    style.alignment = .left
    style.lineBreakMode = .byWordWrapping

    let attributed = NSAttributedString(
        string: text,
        attributes: [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: style,
            .kern: kern
        ]
    )
    attributed.draw(in: rect)
}

func drawRoundedImage(_ image: NSImage, in rect: NSRect, radius: CGFloat) {
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).addClip()
    image.draw(in: rect, from: NSRect(origin: .zero, size: image.size), operation: .copy, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
}

func drawDevice(rawScreenshot: NSImage, canvas: CanvasSpec) {
    let canvasWidth = CGFloat(canvas.width)
    let canvasHeight = CGFloat(canvas.height)
    let outerWidth = canvas.deviceWidth
    let screenWidth = outerWidth - canvas.deviceFrame * 2
    let screenHeight = screenWidth * rawScreenshot.size.height / rawScreenshot.size.width
    let outerHeight = screenHeight + canvas.deviceFrame * 2
    let outerX = (canvasWidth - outerWidth) / 2
    let outerRect = rectFromTop(
        x: outerX,
        y: canvas.deviceTop,
        width: outerWidth,
        height: outerHeight,
        canvasHeight: canvasHeight
    )

    let buttonColor = NSColor(calibratedWhite: 0.08, alpha: 1)
    buttonColor.setFill()
    if canvas.rawPrefix == "iphone" {
        NSBezierPath(roundedRect: NSRect(x: outerRect.minX - 8, y: outerRect.maxY - 520, width: 10, height: 160), xRadius: 5, yRadius: 5).fill()
        NSBezierPath(roundedRect: NSRect(x: outerRect.maxX - 2, y: outerRect.maxY - 600, width: 10, height: 260), xRadius: 5, yRadius: 5).fill()
    }

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.78)
    shadow.shadowBlurRadius = canvas.rawPrefix == "iphone" ? 58 : 72
    shadow.shadowOffset = NSSize(width: 0, height: -24)
    shadow.set()
    NSColor(calibratedWhite: 0.015, alpha: 1).setFill()
    NSBezierPath(roundedRect: outerRect, xRadius: canvas.deviceRadius, yRadius: canvas.deviceRadius).fill()
    NSGraphicsContext.restoreGraphicsState()

    NSColor(calibratedWhite: 0.32, alpha: 0.85).setStroke()
    let edge = NSBezierPath(roundedRect: outerRect.insetBy(dx: 1.5, dy: 1.5), xRadius: canvas.deviceRadius, yRadius: canvas.deviceRadius)
    edge.lineWidth = 3
    edge.stroke()

    let screenRect = outerRect.insetBy(dx: canvas.deviceFrame, dy: canvas.deviceFrame)
    let screenRadius = max(canvas.deviceRadius - canvas.deviceFrame, 20)
    drawRoundedImage(rawScreenshot, in: screenRect, radius: screenRadius)

    let highlight = NSBezierPath(roundedRect: screenRect.insetBy(dx: -1, dy: -1), xRadius: screenRadius, yRadius: screenRadius)
    NSColor.white.withAlphaComponent(0.16).setStroke()
    highlight.lineWidth = 2
    highlight.stroke()
}

func render(spec: ScreenshotSpec, canvas: CanvasSpec) throws {
    let backgroundURL = root.appendingPathComponent(canvas.backgroundPath)
    let rawURL = root.appendingPathComponent("AppStoreScreenshots/raw/\(canvas.rawPrefix)_\(spec.key).png")
    let iconURL = root.appendingPathComponent("SakataChartQuiz/Assets.xcassets/AppIcon.appiconset/oneline_neon_icon_1024.png")

    guard let background = NSImage(contentsOf: backgroundURL),
          let rawScreenshot = NSImage(contentsOf: rawURL),
          let icon = NSImage(contentsOf: iconURL) else {
        throw NSError(domain: "ScreenshotRenderer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Required image could not be loaded for \(spec.key)"])
    }

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let cgContext = CGContext(
        data: nil,
        width: canvas.width,
        height: canvas.height,
        bitsPerComponent: 8,
        bytesPerRow: canvas.width * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ) else {
        throw NSError(domain: "ScreenshotRenderer", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not create bitmap context"])
    }
    let graphics = NSGraphicsContext(cgContext: cgContext, flipped: false)

    let previous = NSGraphicsContext.current
    NSGraphicsContext.current = graphics
    defer { NSGraphicsContext.current = previous }

    let canvasRect = NSRect(x: 0, y: 0, width: canvas.width, height: canvas.height)
    NSColor(calibratedRed: 0.005, green: 0.008, blue: 0.025, alpha: 1).setFill()
    canvasRect.fill()
    drawImageCover(background, in: canvasRect)

    let topShade = NSGradient(colorsAndLocations:
        (NSColor.black.withAlphaComponent(0.90), 0.0),
        (NSColor.black.withAlphaComponent(0.58), 0.56),
        (NSColor.clear, 1.0)
    )!
    let shadeHeight = CGFloat(canvas.height) * 0.32
    topShade.draw(
        in: rectFromTop(x: 0, y: 0, width: CGFloat(canvas.width), height: shadeHeight, canvasHeight: CGFloat(canvas.height)),
        angle: 90
    )

    let glow = NSGradient(colors: [spec.accent.withAlphaComponent(0.32), spec.accent.withAlphaComponent(0)])!
    let glowCenter = NSPoint(x: CGFloat(canvas.width) * 0.83, y: CGFloat(canvas.height) * 0.80)
    glow.draw(
        fromCenter: glowCenter,
        radius: 0,
        toCenter: glowCenter,
        radius: CGFloat(canvas.width) * 0.62,
        options: [.drawsBeforeStartingLocation, .drawsAfterEndingLocation]
    )

    let isPhone = canvas.rawPrefix == "iphone"
    let left: CGFloat = isPhone ? 94 : 150
    let iconTop: CGFloat = isPhone ? 92 : 78
    let iconSize: CGFloat = isPhone ? 76 : 88
    let brandFont = NSFont.systemFont(ofSize: isPhone ? 29 : 34, weight: .semibold)
    let titleFont = NSFont.systemFont(ofSize: isPhone ? 92 : 108, weight: .heavy)
    let subtitleFont = NSFont.systemFont(ofSize: isPhone ? 34 : 39, weight: .medium)

    let iconRect = rectFromTop(x: left, y: iconTop, width: iconSize, height: iconSize, canvasHeight: CGFloat(canvas.height))
    drawRoundedImage(icon, in: iconRect, radius: iconSize * 0.23)
    drawText(
        "酒田道場  |  ローソク足クイズ",
        rect: rectFromTop(
            x: left + iconSize + 22,
            y: iconTop + 12,
            width: CGFloat(canvas.width) - left * 2 - iconSize - 22,
            height: 52,
            canvasHeight: CGFloat(canvas.height)
        ),
        font: brandFont,
        color: spec.accent,
        kern: 0.4
    )

    let titleTop: CGFloat = isPhone ? 202 : 178
    let titleHeight: CGFloat = isPhone ? 236 : 274
    drawText(
        spec.title,
        rect: rectFromTop(
            x: left,
            y: titleTop,
            width: CGFloat(canvas.width) - left * 2,
            height: titleHeight,
            canvasHeight: CGFloat(canvas.height)
        ),
        font: titleFont,
        color: NSColor(calibratedWhite: 0.98, alpha: 1),
        lineSpacing: isPhone ? -6 : -4,
        kern: -1.2
    )

    let subtitleTop: CGFloat = isPhone ? 486 : 480
    drawText(
        spec.subtitle,
        rect: rectFromTop(
            x: left,
            y: subtitleTop,
            width: CGFloat(canvas.width) - left * 2,
            height: 72,
            canvasHeight: CGFloat(canvas.height)
        ),
        font: subtitleFont,
        color: NSColor(calibratedWhite: 0.86, alpha: 1),
        kern: 0.1
    )

    drawDevice(rawScreenshot: rawScreenshot, canvas: canvas)

    let outputDirectory = root.appendingPathComponent(canvas.outputDirectory, isDirectory: true)
    try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
    let index = screenshots.firstIndex(where: { $0.key == spec.key })! + 1
    let outputURL = outputDirectory.appendingPathComponent(String(format: "%02d_%@.png", index, spec.key))

    guard let cgImage = cgContext.makeImage(),
          let destination = CGImageDestinationCreateWithURL(
              outputURL as CFURL,
              UTType.png.identifier as CFString,
              1,
              nil
          ) else {
        throw NSError(domain: "ScreenshotRenderer", code: 3, userInfo: [NSLocalizedDescriptionKey: "Could not prepare PNG encoding"])
    }
    CGImageDestinationAddImage(destination, cgImage, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw NSError(domain: "ScreenshotRenderer", code: 4, userInfo: [NSLocalizedDescriptionKey: "Could not encode PNG"])
    }
    print(outputURL.path)
}

do {
    for canvas in canvases {
        for screenshot in screenshots {
            try render(spec: screenshot, canvas: canvas)
        }
    }
} catch {
    fputs("Render failed: \(error.localizedDescription)\n", stderr)
    exit(1)
}
