import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct ScreenshotSpec {
    let key: String
    let accent: NSColor
}

struct Copy {
    let title: String
    let subtitle: String
}

struct LocaleSpec {
    let identifier: String
    let brand: String
    let copies: [String: Copy]
    let titleFontName: String?
    let bodyFontName: String?
    // ベトナム語の声調記号などが詰まって欠けないよう、行間を言語ごとに調整する
    let titleLineSpacing: CGFloat
}

struct CanvasSpec {
    let width: Int
    let height: Int
    let backgroundPath: String
    let rawPrefix: String
    let outputDirectory: String
    let deviceMaxWidth: CGFloat
    let deviceFrame: CGFloat
    let deviceRadius: CGFloat
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

let screenshots = [
    ScreenshotSpec(key: "title", accent: NSColor(calibratedRed: 0.23, green: 0.83, blue: 1.00, alpha: 1)),
    ScreenshotSpec(key: "direction", accent: NSColor(calibratedRed: 0.10, green: 0.54, blue: 1.00, alpha: 1)),
    ScreenshotSpec(key: "pattern", accent: NSColor(calibratedRed: 0.96, green: 0.23, blue: 0.76, alpha: 1)),
    ScreenshotSpec(key: "answer", accent: NSColor(calibratedRed: 1.00, green: 0.25, blue: 0.34, alpha: 1)),
    ScreenshotSpec(key: "study", accent: NSColor(calibratedRed: 1.00, green: 0.67, blue: 0.20, alpha: 1))
]

let locales = [
    LocaleSpec(
        identifier: "ja",
        brand: "酒田道場  |  ローソク足クイズ",
        copies: [
            "title": Copy(title: "ローソク足を\nクイズで学ぶ", subtitle: "酒田五法の30パターンを、基本形から実戦チャートまで"),
            "direction": Copy(title: "上がる？\n下がる？", subtitle: "チャートを見て、この後の値動きを予想"),
            "pattern": Copy(title: "30の型を\n4択で覚える", subtitle: "形を見てパターン名を当てるトレーニング"),
            "answer": Copy(title: "解説つきで\nすぐ分かる", subtitle: "答えのあとにパターンの意味を確認"),
            "study": Copy(title: "全30パターンを\n図鑑で復習", subtitle: "チャートつきで、いつでも見返せる")
        ],
        titleFontName: "HiraginoSans-W8",
        bodyFontName: "HiraginoSans-W6",
        titleLineSpacing: -4
    ),
    LocaleSpec(
        identifier: "en",
        brand: "Sakata Dojo  |  Candlestick Quiz",
        copies: [
            "title": Copy(title: "Learn Candlestick\nPatterns by Quiz", subtitle: "30 classic Japanese patterns, from basics to real charts"),
            "direction": Copy(title: "Up or\nDown?", subtitle: "Read the chart and predict the next move"),
            "pattern": Copy(title: "Name the Pattern\nin 4 Choices", subtitle: "Train your eye to spot all 30 patterns"),
            "answer": Copy(title: "Learn Why,\nInstantly", subtitle: "See what each pattern means right after you answer"),
            "study": Copy(title: "All 30 Patterns\nin One Library", subtitle: "Review every pattern with charts, anytime")
        ],
        titleFontName: nil,
        bodyFontName: nil,
        titleLineSpacing: -4
    ),
    LocaleSpec(
        identifier: "ko",
        brand: "사카타 도장  |  캔들 퀴즈",
        copies: [
            "title": Copy(title: "캔들 패턴을\n퀴즈로 배우자", subtitle: "사카타 5법 30가지 패턴을 기본형부터 실전 차트까지"),
            "direction": Copy(title: "오를까?\n내릴까?", subtitle: "차트를 보고 이후 가격 흐름을 예측"),
            "pattern": Copy(title: "30가지 패턴을\n4지선다로", subtitle: "모양을 보고 패턴명을 맞히는 트레이닝"),
            "answer": Copy(title: "해설로\n바로 이해", subtitle: "정답 후 패턴의 의미를 바로 확인"),
            "study": Copy(title: "30가지 패턴을\n도감으로 복습", subtitle: "차트와 함께 언제든 다시 보기")
        ],
        titleFontName: "AppleSDGothicNeo-Heavy",
        bodyFontName: "AppleSDGothicNeo-SemiBold",
        titleLineSpacing: -2
    ),
    LocaleSpec(
        identifier: "zh-Hant",
        brand: "酒田道場  |  K線測驗",
        copies: [
            "title": Copy(title: "用測驗\n學會K線型態", subtitle: "酒田五法30種型態，從基本型到實戰圖表"),
            "direction": Copy(title: "會漲？\n還是會跌？", subtitle: "看圖表，預測接下來的走勢"),
            "pattern": Copy(title: "30種型態\n四選一練習", subtitle: "看形狀猜出型態名稱的訓練"),
            "answer": Copy(title: "附解說\n一看就懂", subtitle: "作答後立即確認型態的意義"),
            "study": Copy(title: "全部30種型態\n圖鑑複習", subtitle: "附圖表，隨時都能回顧")
        ],
        titleFontName: "PingFangTC-Semibold",
        bodyFontName: "PingFangTC-Medium",
        titleLineSpacing: -2
    ),
    LocaleSpec(
        identifier: "vi",
        brand: "Sakata Dojo  |  Câu đố nến Nhật",
        copies: [
            "title": Copy(title: "Học mô hình nến\nqua câu đố", subtitle: "30 mô hình nến Nhật, từ cơ bản đến biểu đồ thực chiến"),
            "direction": Copy(title: "Tăng hay\ngiảm?", subtitle: "Xem biểu đồ và dự đoán diễn biến giá tiếp theo"),
            "pattern": Copy(title: "Đoán tên mô hình\nvới 4 lựa chọn", subtitle: "Luyện mắt nhận diện cả 30 mô hình nến"),
            "answer": Copy(title: "Hiểu ngay\nnhờ giải thích", subtitle: "Xem ý nghĩa mô hình ngay sau khi trả lời"),
            "study": Copy(title: "Cả 30 mô hình\ntrong thư viện", subtitle: "Ôn lại mọi mô hình kèm biểu đồ, bất cứ lúc nào")
        ],
        titleFontName: nil,
        bodyFontName: nil,
        titleLineSpacing: 6
    )
]

let canvases = [
    CanvasSpec(
        // App Store Connect の iPhone 6.3インチ枠（1206 x 2622）
        width: 1206,
        height: 2622,
        backgroundPath: "AppStoreScreenshots/backgrounds/neon_phone.png",
        rawPrefix: "iphone",
        outputDirectory: "6.3-inch",
        deviceMaxWidth: 860,
        deviceFrame: 24,
        deviceRadius: 80
    ),
    CanvasSpec(
        width: 2064,
        height: 2752,
        backgroundPath: "AppStoreScreenshots/backgrounds/neon_ipad.png",
        rawPrefix: "ipad",
        outputDirectory: "13-inch",
        deviceMaxWidth: 1560,
        deviceFrame: 30,
        deviceRadius: 54
    ),
    CanvasSpec(
        width: 2007,
        height: 2853,
        backgroundPath: "AppStoreScreenshots/backgrounds/neon_ipad.png",
        rawPrefix: "duo",
        outputDirectory: "duo-inner",
        deviceMaxWidth: 1520,
        deviceFrame: 30,
        deviceRadius: 60
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

func font(named name: String?, size: CGFloat, fallbackWeight: NSFont.Weight) -> NSFont {
    if let name, let font = NSFont(name: name, size: size) { return font }
    return NSFont.systemFont(ofSize: size, weight: fallbackWeight)
}

func attributedText(
    _ text: String,
    font: NSFont,
    color: NSColor,
    lineSpacing: CGFloat = 0,
    kern: CGFloat = 0
) -> NSAttributedString {
    let style = NSMutableParagraphStyle()
    style.lineSpacing = lineSpacing
    style.alignment = .left
    style.lineBreakMode = .byWordWrapping

    return NSAttributedString(
        string: text,
        attributes: [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: style,
            .kern: kern
        ]
    )
}

func textHeight(_ text: NSAttributedString, width: CGFloat) -> CGFloat {
    ceil(text.boundingRect(
        with: NSSize(width: width, height: .greatestFiniteMagnitude),
        options: [.usesLineFragmentOrigin, .usesFontLeading]
    ).height)
}

// 明示的な改行ごとの行が1行に収まる最大のフォントサイズを探す（長い言語でも折り返さずに大きく見せる）
func fittingFontSize(
    _ text: String,
    maxSize: CGFloat,
    minSize: CGFloat,
    width: CGFloat,
    makeFont: (CGFloat) -> NSFont,
    kern: CGFloat
) -> CGFloat {
    var size = maxSize
    while size > minSize {
        let font = makeFont(size)
        let widest = text.components(separatedBy: "\n").map { line in
            attributedText(line, font: font, color: .white, kern: kern).size().width
        }.max() ?? 0
        if widest <= width { return size }
        size -= 2
    }
    return minSize
}

func drawRoundedImage(_ image: NSImage, in rect: NSRect, radius: CGFloat) {
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).addClip()
    image.draw(in: rect, from: NSRect(origin: .zero, size: image.size), operation: .copy, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
}

func drawDevice(rawScreenshot: NSImage, canvas: CanvasSpec, top: CGFloat) {
    let canvasWidth = CGFloat(canvas.width)
    let canvasHeight = CGFloat(canvas.height)
    let bottomMargin: CGFloat = canvas.rawPrefix == "iphone" ? 70 : 80
    let aspect = rawScreenshot.size.height / rawScreenshot.size.width

    // テキストを大きくした分、端末がキャンバス下端からはみ出さないよう幅を調整する
    let availableHeight = canvasHeight - top - bottomMargin
    let widthForHeight = (availableHeight - canvas.deviceFrame * 2) / aspect + canvas.deviceFrame * 2
    let outerWidth = min(canvas.deviceMaxWidth, widthForHeight)
    let screenWidth = outerWidth - canvas.deviceFrame * 2
    let screenHeight = screenWidth * aspect
    let outerHeight = screenHeight + canvas.deviceFrame * 2
    let outerX = (canvasWidth - outerWidth) / 2
    let outerRect = rectFromTop(
        x: outerX,
        y: top,
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

func render(spec: ScreenshotSpec, canvas: CanvasSpec, locale: LocaleSpec) throws {
    guard let copy = locale.copies[spec.key] else {
        throw NSError(domain: "ScreenshotRenderer", code: 5, userInfo: [NSLocalizedDescriptionKey: "Missing copy for \(locale.identifier)/\(spec.key)"])
    }
    let backgroundURL = root.appendingPathComponent(canvas.backgroundPath)
    let rawURL = root.appendingPathComponent("AppStoreScreenshots/raw/\(locale.identifier)/\(canvas.rawPrefix)_\(spec.key).png")
    let iconURL = root.appendingPathComponent("SakataChartQuiz/Assets.xcassets/AppIcon.appiconset/oneline_neon_icon_1024.png")

    guard let background = NSImage(contentsOf: backgroundURL),
          let rawScreenshot = NSImage(contentsOf: rawURL),
          let icon = NSImage(contentsOf: iconURL) else {
        throw NSError(domain: "ScreenshotRenderer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Required image could not be loaded for \(locale.identifier)/\(canvas.rawPrefix)_\(spec.key)"])
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

    let canvasWidth = CGFloat(canvas.width)
    let canvasHeight = CGFloat(canvas.height)
    let canvasRect = NSRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight)
    NSColor(calibratedRed: 0.005, green: 0.008, blue: 0.025, alpha: 1).setFill()
    canvasRect.fill()
    drawImageCover(background, in: canvasRect)

    // 文字を大きくしたので、背景の柄に負けないよう上部の暗いグラデーションを広めにとる
    let topShade = NSGradient(colorsAndLocations:
        (NSColor.black.withAlphaComponent(0.92), 0.0),
        (NSColor.black.withAlphaComponent(0.70), 0.62),
        (NSColor.clear, 1.0)
    )!
    topShade.draw(
        in: rectFromTop(x: 0, y: 0, width: canvasWidth, height: canvasHeight * 0.42, canvasHeight: canvasHeight),
        angle: 90
    )

    let glow = NSGradient(colors: [spec.accent.withAlphaComponent(0.32), spec.accent.withAlphaComponent(0)])!
    let glowCenter = NSPoint(x: canvasWidth * 0.83, y: canvasHeight * 0.80)
    glow.draw(
        fromCenter: glowCenter,
        radius: 0,
        toCenter: glowCenter,
        radius: canvasWidth * 0.62,
        options: [.drawsBeforeStartingLocation, .drawsAfterEndingLocation]
    )

    let isPhone = canvas.rawPrefix == "iphone"
    let left: CGFloat = isPhone ? 80 : 150
    let textWidth = canvasWidth - left * 2
    let iconSize: CGFloat = isPhone ? 96 : 112
    var cursor: CGFloat = isPhone ? 96 : 84

    // ブランド行（アイコン + アプリ名 | ジャンル）
    let brandFont = font(named: locale.bodyFontName, size: isPhone ? 40 : 46, fallbackWeight: .bold)
    let brand = attributedText(locale.brand, font: brandFont, color: spec.accent, kern: 0.4)
    let iconRect = rectFromTop(x: left, y: cursor, width: iconSize, height: iconSize, canvasHeight: canvasHeight)
    drawRoundedImage(icon, in: iconRect, radius: iconSize * 0.23)
    let brandHeight = textHeight(brand, width: textWidth - iconSize - 26)
    brand.draw(in: rectFromTop(
        x: left + iconSize + 26,
        y: cursor + (iconSize - brandHeight) / 2,
        width: textWidth - iconSize - 26,
        height: brandHeight,
        canvasHeight: canvasHeight
    ))
    cursor += iconSize + (isPhone ? 44 : 48)

    // 見出し（1行ずつ収まる範囲で最大サイズ）
    let titleKern: CGFloat = -1.0
    let makeTitleFont = { (size: CGFloat) in font(named: locale.titleFontName, size: size, fallbackWeight: .heavy) }
    let titleSize = fittingFontSize(
        copy.title,
        maxSize: isPhone ? 150 : 176,
        minSize: isPhone ? 96 : 110,
        width: textWidth,
        makeFont: makeTitleFont,
        kern: titleKern
    )
    let title = attributedText(
        copy.title,
        font: makeTitleFont(titleSize),
        color: NSColor(calibratedWhite: 0.98, alpha: 1),
        lineSpacing: locale.titleLineSpacing,
        kern: titleKern
    )
    let titleHeight = textHeight(title, width: textWidth)
    title.draw(in: rectFromTop(x: left, y: cursor, width: textWidth, height: titleHeight, canvasHeight: canvasHeight))
    cursor += titleHeight + (isPhone ? 28 : 32)

    // サブ見出し（最大2行まで折り返し）
    let subtitleFont = font(named: locale.bodyFontName, size: isPhone ? 52 : 60, fallbackWeight: .semibold)
    let subtitle = attributedText(
        copy.subtitle,
        font: subtitleFont,
        color: NSColor(calibratedWhite: 0.90, alpha: 1),
        lineSpacing: 6,
        kern: 0.1
    )
    let subtitleHeight = textHeight(subtitle, width: textWidth)
    subtitle.draw(in: rectFromTop(x: left, y: cursor, width: textWidth, height: subtitleHeight, canvasHeight: canvasHeight))
    cursor += subtitleHeight + (isPhone ? 64 : 72)

    drawDevice(rawScreenshot: rawScreenshot, canvas: canvas, top: cursor)

    let outputDirectory = root
        .appendingPathComponent("AppStoreScreenshots", isDirectory: true)
        .appendingPathComponent(locale.identifier, isDirectory: true)
        .appendingPathComponent(canvas.outputDirectory, isDirectory: true)
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

// リポジトリのルートで実行する: swift AppStoreScreenshots/render_screenshots.swift [rawPrefix や locale ...]
//   例: swift AppStoreScreenshots/render_screenshots.swift duo     （duo だけ全言語）
//       swift AppStoreScreenshots/render_screenshots.swift en ko   （英語と韓国語だけ全デバイス）
// 出力: AppStoreScreenshots/<locale>/<6.3-inch|13-inch|duo-inner>/NN_<key>.png
let arguments = Set(CommandLine.arguments.dropFirst())
let selectedPrefixes = arguments.intersection(canvases.map(\.rawPrefix))
let selectedLocales = arguments.intersection(locales.map(\.identifier))

do {
    for locale in locales where selectedLocales.isEmpty || selectedLocales.contains(locale.identifier) {
        for canvas in canvases where selectedPrefixes.isEmpty || selectedPrefixes.contains(canvas.rawPrefix) {
            for screenshot in screenshots {
                try render(spec: screenshot, canvas: canvas, locale: locale)
            }
        }
    }
} catch {
    fputs("Render failed: \(error.localizedDescription)\n", stderr)
    exit(1)
}
