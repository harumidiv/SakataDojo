// App Store の検索結果・製品ページヘッダー用の動画を書き出す。
// 使い方: AppStoreScreenshots/PromoVideo/render.sh [--stills] [言語 ...]
// アプリの IdealPatterns.swift（手本チャート）と Models.swift（Candle）を一緒にコンパイルして使う。
import AppKit
import AVFoundation
import CoreGraphics
import Foundation

// MARK: - 仕様（Apple の Creative assets specifications）

struct VideoFormat {
    let name: String
    let width: Int
    let height: Int
    /// アートセーフエリア（Apple の表記どおり、左上原点）
    let safeTopLeft: CGRect

    /// CoreGraphics（左下原点）でのセーフエリア
    var safe: CGRect {
        CGRect(x: safeTopLeft.minX, y: CGFloat(height) - safeTopLeft.maxY,
               width: safeTopLeft.width, height: safeTopLeft.height)
    }
}

let formats = [
    VideoFormat(name: "search_3840x2560", width: 3840, height: 2560,
                safeTopLeft: CGRect(x: 836, y: 765, width: 2168, height: 1030)),
    // パターンの切り替えを先に見せ、そのあとスマホを出す構成
    VideoFormat(name: "search_carousel_3840x2560", width: 3840, height: 2560,
                safeTopLeft: CGRect(x: 836, y: 765, width: 2168, height: 1030)),
    VideoFormat(name: "header_3840x1646", width: 3840, height: 1646,
                safeTopLeft: CGRect(x: 1097, y: 493, width: 1646, height: 661)),
]

/// ヘッダーの静止画（PNG・透過なし）。セーフエリアは Apple の表記どおり
let imageFormats = [
    VideoFormat(name: "image_header_3840x1646", width: 3840, height: 1646,
                safeTopLeft: CGRect(x: 1097, y: 493, width: 1646, height: 661)),
    VideoFormat(name: "image_universal_5244x2950", width: 5244, height: 2950,
                safeTopLeft: CGRect(x: 1921, y: 660, width: 1402, height: 962)),
]
/// 端末によっては見切れるので、静止画の主役はセーフエリアのさらに内側（この割合）に収める
let imageContentScale: CGFloat = 0.85

let fps: Int32 = 30
let duration: Double = 15
let frameCount = Int(duration * Double(fps))

/// 前景はこの大きさの「設計用の座標」で組み、拡大縮小して画面に置く
let unit = CGSize(width: 2168, height: 1030)
/// 検索結果の動画で、前景が画面の横幅に占める割合（セーフエリアより大きく使う）
let searchContentRatio: CGFloat = 0.92

// MARK: - 言語ごとの文言

struct Copy {
    let hook1: String
    let hook2: String
    let patternsLabel: String
    let bullish: String
    let bearish: String
    let features: [(title: String, subtitle: String)]
    let brand: String
    let tagline: String
    let endFeatures: String
    let titleFont: String?
    let bodyFont: String?
}

let copies: [String: Copy] = [
    "ja": Copy(
        hook1: "酒田五法を",
        hook2: "クイズで学ぶ",
        patternsLabel: "PATTERNS",
        bullish: "上昇サイン",
        bearish: "下落サイン",
        features: [
            ("毎日5問のデイリーチャレンジ", "みんな同じ問題で、連続日数を伸ばそう"),
            ("形を見てパターン名を4択で", "実戦チャートでも基本形でも"),
            ("解説ですぐ分かる", "答えのあとに、その後の値動きも"),
            ("全42パターンを図鑑で復習", "方向別・分類別・名前順で"),
        ],
        brand: "酒田道場",
        tagline: "ローソク足クイズ",
        endFeatures: "42パターン ・ デイリーチャレンジ ・ ランキング",
        titleFont: "HiraginoSans-W8",
        bodyFont: "HiraginoSans-W6"
    ),
]

// MARK: - 素材

let neonRed = NSColor(calibratedRed: 1.00, green: 0.25, blue: 0.36, alpha: 1)
let neonBlue = NSColor(calibratedRed: 0.25, green: 0.55, blue: 1.00, alpha: 1)
let neonCyan = NSColor(calibratedRed: 0.23, green: 0.83, blue: 1.00, alpha: 1)
let neonOrange = NSColor(calibratedRed: 1.00, green: 0.67, blue: 0.20, alpha: 1)
let neonMagenta = NSColor(calibratedRed: 0.96, green: 0.23, blue: 0.76, alpha: 1)

/// カルーセルで見せるパターン（id, 上昇サインか）
let showcase: [(id: String, bullish: Bool)] = [
    ("三尊", false), ("明けの明星", true), ("三空叩き込み", true), ("赤三兵", true),
    ("宵の明星", false), ("陽の包み線", true), ("上げ三法", true), ("下放れタスキ", false),
    ("流れ星", false), ("逆三尊", true), ("三羽烏", false), ("差し込み線", false),
]

let scriptDirectory = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
let repoRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

func loadImage(_ path: String) -> CGImage? {
    guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(source, 0, nil)
}

// MARK: - 乱数（毎回同じ絵になるよう固定の種を使う）

struct SeededRandom {
    var state: UInt64
    mutating func next() -> Double {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return Double((z ^ (z >> 31)) >> 11) / Double(1 << 53)
    }
    mutating func range(_ a: Double, _ b: Double) -> Double { a + (b - a) * next() }
}

// MARK: - イージング

func clamp(_ x: Double, _ a: Double = 0, _ b: Double = 1) -> Double { min(max(x, a), b) }
func progress(_ t: Double, _ start: Double, _ end: Double) -> Double { clamp((t - start) / (end - start)) }
func easeOutCubic(_ x: Double) -> Double { 1 - pow(1 - x, 3) }
func easeInCubic(_ x: Double) -> Double { x * x * x }
func easeOutBack(_ x: Double) -> Double {
    let c1 = 1.70158, c3 = c1 + 1
    return 1 + c3 * pow(x - 1, 3) + c1 * pow(x - 1, 2)
}

// MARK: - 背景（画面全体。15秒でちょうど元の位置に戻るように動かす）

struct Streak {
    let y: Double, length: Double, thickness: Double, laps: Double, phase: Double
    let color: NSColor, alpha: Double
}

struct BackgroundCandle { let open: Double, close: Double, high: Double, low: Double }

final class Background {
    let width: Double, height: Double
    lazy var flow = FlowScene(width: Int(width), height: Int(height))
    let streaks: [Streak]
    let rows: [(y: Double, scale: Double, alpha: Double, laps: Double, candles: [BackgroundCandle])]

    init(width: Int, height: Int) {
        self.width = Double(width); self.height = Double(height)
        var random = SeededRandom(state: 42)
        let palette = [neonCyan, neonMagenta, neonRed, neonOrange, neonCyan]
        streaks = (0..<70).map { _ in
            Streak(
                y: random.range(0, Double(height)),
                length: random.range(200, 1100),
                thickness: random.range(2, 9),
                laps: Double(Int(random.range(2, 7))),
                phase: random.next(),
                color: palette[Int(random.range(0, Double(palette.count)))],
                alpha: random.range(0.25, 0.8)
            )
        }
        rows = [(0.18, 0.75, 0.16, 1), (0.50, 1.0, 0.11, 2), (0.82, 0.6, 0.14, 3)].map { row in
            // 周期的な波の合成で、列の最後と最初がつながる値動きにする
            let count = 48
            var candles: [BackgroundCandle] = []
            var r = SeededRandom(state: UInt64(row.0 * 1000))
            let phases = (0..<3).map { _ in r.range(0, 2 * .pi) }
            func level(_ i: Double) -> Double {
                let x = 2 * .pi * i / Double(count)
                return sin(x + phases[0]) * 0.5 + sin(2 * x + phases[1]) * 0.3 + sin(5 * x + phases[2]) * 0.2
            }
            for i in 0..<count {
                let open = level(Double(i)), close = level(Double(i) + 1)
                let wick = r.range(0.05, 0.18)
                candles.append(BackgroundCandle(open: open, close: close,
                                                high: max(open, close) + wick, low: min(open, close) - wick))
            }
            return (y: row.0, scale: row.1, alpha: row.2, laps: row.3, candles: candles)
        }
    }

    func draw(_ ctx: CGContext, t: Double) {
        let space = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(colorsSpace: space, colors: [
            CGColor(red: 0.06, green: 0.08, blue: 0.19, alpha: 1),
            CGColor(red: 0.01, green: 0.01, blue: 0.04, alpha: 1),
        ] as CFArray, locations: [0, 1])!
        ctx.drawRadialGradient(gradient,
                               startCenter: CGPoint(x: width / 2, y: height / 2), startRadius: 0,
                               endCenter: CGPoint(x: width / 2, y: height / 2), endRadius: max(width, height) * 0.7,
                               options: [.drawsAfterEndLocation])

        // 左へ流れる方眼
        let cell = height / 10
        let gridShift = (t / duration * 30 * cell).truncatingRemainder(dividingBy: cell)
        ctx.setStrokeColor(neonCyan.withAlphaComponent(0.06).cgColor)
        ctx.setLineWidth(2)
        var x = -gridShift
        while x < width { ctx.move(to: CGPoint(x: x, y: 0)); ctx.addLine(to: CGPoint(x: x, y: height)); x += cell }
        var y = 0.0
        while y < height { ctx.move(to: CGPoint(x: 0, y: y)); ctx.addLine(to: CGPoint(x: width, y: y)); y += cell }
        ctx.strokePath()

        // 流れるローソク足（奥行きを出すため列ごとに速さと大きさを変える）
        for row in rows {
            let spacing = 150 * row.scale
            let period = spacing * Double(row.candles.count)
            let shift = (t / duration * row.laps * period).truncatingRemainder(dividingBy: period)
            let amplitude = height * 0.11 * row.scale
            let baseY = height * row.y
            let bodyWidth = spacing * 0.45
            var i = 0
            var cx = -shift
            while cx < width + spacing {
                let c = row.candles[i % row.candles.count]
                let color = (c.close >= c.open ? neonRed : neonBlue).withAlphaComponent(row.alpha)
                ctx.setStrokeColor(color.cgColor)
                ctx.setFillColor(color.cgColor)
                ctx.setLineWidth(4 * row.scale)
                ctx.move(to: CGPoint(x: cx, y: baseY + c.low * amplitude))
                ctx.addLine(to: CGPoint(x: cx, y: baseY + c.high * amplitude))
                ctx.strokePath()
                let top = baseY + max(c.open, c.close) * amplitude
                let bottom = baseY + min(c.open, c.close) * amplitude
                ctx.fill(CGRect(x: cx - bodyWidth / 2, y: bottom, width: bodyWidth, height: max(top - bottom, 4)))
                cx += spacing
                i += 1
            }
        }

        // 高速で走る光の筋
        ctx.setLineCap(.round)
        for s in streaks {
            let lap = width + s.length
            let x = width - ((t / duration * s.laps + s.phase) * lap).truncatingRemainder(dividingBy: lap)
            // 外側のにじみ → 芯の順に重ねて、ぼかしを使わずに光らせる
            for (widthScale, alphaScale) in [(5.0, 0.12), (2.2, 0.3), (1.0, 1.0)] {
                ctx.setStrokeColor(s.color.withAlphaComponent(s.alpha * alphaScale).cgColor)
                ctx.setLineWidth(s.thickness * widthScale)
                ctx.move(to: CGPoint(x: x, y: s.y))
                ctx.addLine(to: CGPoint(x: x + s.length, y: s.y))
                ctx.strokePath()
            }
        }
    }
}

// MARK: - ヘッダー用: 右から左へ流れるチャート（文字やアイコンは置かない）

final class FlowScene {
    struct Row {
        let centerY: Double, spacing: Double, amplitude: Double, laps: Double
        let alpha: Double, glow: Double, lineWidth: Double, showsCloseLine: Bool
        let candles: [BackgroundCandle]
    }
    let width: Double, height: Double
    let rows: [Row]
    let streaks: [Streak]

    init(width: Int, height: Int) {
        self.width = Double(width); self.height = Double(height)
        let H = Double(height)
        func makeCandles(seed: UInt64, count: Int) -> [BackgroundCandle] {
            // 周期的な波の合成で、列の最後と最初がつながる値動きにする（ループの継ぎ目を出さない）
            var r = SeededRandom(state: seed)
            let phases = (0..<4).map { _ in r.range(0, 2 * .pi) }
            // 48本で1つの大きな波になる速さを基準に、本数が増えても値動きの細かさを保つ
            let waves = Double(max(count / 48, 1))
            func level(_ i: Double) -> Double {
                let x = 2 * .pi * i / Double(count)
                // 周波数を整数のまま少しずつずらし、列の中で同じ波の形が繰り返されないようにする
                return sin(waves * x + phases[0]) * 0.45 + sin((2 * waves + 1) * x + phases[1]) * 0.3
                    + sin((5 * waves + 2) * x + phases[2]) * 0.17 + sin((11 * waves + 3) * x + phases[3]) * 0.08
            }
            return (0..<count).map { i in
                // 流れの向きに合わせた実体を、1本ごとに大きさを変えて付ける（たまに逆向きの足も混ぜる）
                let base = level(Double(i) + 0.5)
                let trend = level(Double(i) + 1) - level(Double(i))
                let direction: Double = (trend >= 0) == (r.next() < 0.78) ? 1 : -1
                let size = r.range(0.1, 0.32)
                let open = base - direction * size / 2, close = base + direction * size / 2
                let wick = r.range(0.04, 0.16)
                return BackgroundCandle(open: open, close: close, high: max(open, close) + wick, low: min(open, close) - wick)
            }
        }
        rows = [
            // どの列も15秒でちょうど1周させる（途中で同じ並びが繰り返されないように、本数で速さを決める）
            // 奥（上下に小さく暗く、ゆっくり）
            Row(centerY: H * 0.2, spacing: H * 0.045, amplitude: H * 0.07, laps: 1, alpha: 0.4, glow: 0, lineWidth: H * 0.003, showsCloseLine: false, candles: makeCandles(seed: 7, count: 180)),
            Row(centerY: H * 0.8, spacing: H * 0.045, amplitude: H * 0.07, laps: 1, alpha: 0.4, glow: 0, lineWidth: H * 0.003, showsCloseLine: false, candles: makeCandles(seed: 11, count: 240)),
            // 手前（中央に大きく明るく、速く）
            Row(centerY: H * 0.5, spacing: H * 0.1, amplitude: H * 0.24, laps: 1, alpha: 1, glow: H * 0.022, lineWidth: H * 0.006, showsCloseLine: true, candles: makeCandles(seed: 3, count: 120)),
        ]
        var random = SeededRandom(state: 99)
        let palette = [neonCyan, neonMagenta, neonRed, neonOrange, neonCyan, .white]
        streaks = (0..<110).map { _ in
            Streak(y: random.range(0, H), length: random.range(300, 1600), thickness: random.range(2, 8),
                   laps: Double(Int(random.range(8, 17))), phase: random.next(),
                   color: palette[Int(random.range(0, Double(palette.count)))], alpha: random.range(0.3, 0.9))
        }
    }

    func draw(_ ctx: CGContext, t: Double) {
        // 速い光の筋（背景の筋より速く、本数も多い）
        ctx.setLineCap(.round)
        for s in streaks {
            let lap = width + s.length
            let x = width - ((t / duration * s.laps + s.phase) * lap).truncatingRemainder(dividingBy: lap)
            for (widthScale, alphaScale) in [(5.0, 0.1), (2.2, 0.28), (1.0, 1.0)] {
                ctx.setStrokeColor(s.color.withAlphaComponent(s.alpha * alphaScale).cgColor)
                ctx.setLineWidth(s.thickness * widthScale)
                ctx.move(to: CGPoint(x: x, y: s.y))
                ctx.addLine(to: CGPoint(x: x + s.length, y: s.y))
                ctx.strokePath()
            }
        }

        for row in rows {
            let period = row.spacing * Double(row.candles.count)
            let shift = (t / duration * row.laps * period).truncatingRemainder(dividingBy: period)
            // 1秒あたりの移動量。残像の長さに使う
            let speed = row.laps * period / duration
            let bodyWidth = row.spacing * 0.5
            var points: [CGPoint] = []
            var i = 0
            var cx = -shift
            while cx < width + row.spacing {
                if cx > -row.spacing {
                    let c = row.candles[i % row.candles.count]
                    let color = c.close >= c.open ? neonRed : neonBlue
                    let top = row.centerY + max(c.open, c.close) * row.amplitude
                    let bottom = row.centerY + min(c.open, c.close) * row.amplitude
                    let body = CGRect(x: cx - bodyWidth / 2, y: bottom, width: bodyWidth, height: max(top - bottom, row.lineWidth * 2))

                    // 進む向き（左）と逆側に残像を出して、速さを感じさせる
                    for k in 1...3 {
                        let trail = speed * 0.012 * Double(k)
                        ctx.setFillColor(color.withAlphaComponent(row.alpha * 0.12 / Double(k)).cgColor)
                        ctx.fill(body.offsetBy(dx: trail, dy: 0))
                    }
                    ctx.saveGState()
                    if row.glow > 0 { ctx.setShadow(offset: .zero, blur: row.glow, color: color.withAlphaComponent(0.9).cgColor) }
                    ctx.setStrokeColor(color.withAlphaComponent(row.alpha).cgColor)
                    ctx.setLineWidth(row.lineWidth)
                    ctx.move(to: CGPoint(x: cx, y: row.centerY + c.low * row.amplitude))
                    ctx.addLine(to: CGPoint(x: cx, y: row.centerY + c.high * row.amplitude))
                    ctx.strokePath()
                    ctx.setFillColor(color.withAlphaComponent(row.alpha * 0.3).cgColor)
                    ctx.fill(body)
                    ctx.setLineWidth(row.lineWidth * 1.2)
                    ctx.stroke(body.insetBy(dx: row.lineWidth * 0.6, dy: row.lineWidth * 0.6))
                    ctx.restoreGState()
                    points.append(CGPoint(x: cx, y: row.centerY + c.close * row.amplitude))
                }
                cx += row.spacing
                i += 1
            }
            // 終値をつなぐ光の線
            if row.showsCloseLine, points.count > 1 {
                ctx.saveGState()
                ctx.setShadow(offset: .zero, blur: row.glow * 1.2, color: neonCyan.withAlphaComponent(0.9).cgColor)
                ctx.setStrokeColor(neonCyan.withAlphaComponent(0.9).cgColor)
                ctx.setLineWidth(row.lineWidth * 0.9)
                ctx.setLineJoin(.round)
                ctx.addLines(between: points)
                ctx.strokePath()
                ctx.restoreGState()
            }
        }
    }
}

// MARK: - 描画の部品

func makeFont(_ name: String?, _ size: CGFloat, _ weight: NSFont.Weight) -> NSFont {
    if let name, let f = NSFont(name: name, size: size) { return f }
    return NSFont.systemFont(ofSize: size, weight: weight)
}

func attributed(_ text: String, _ font: NSFont, _ color: NSColor, kern: CGFloat = 0) -> NSAttributedString {
    NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color, .kern: kern])
}

/// 光彩つきで文字を描く。dx に速度を入れると、進行方向と逆に残像を出す
func drawText(_ ctx: CGContext, _ text: NSAttributedString, at point: CGPoint, glow: NSColor,
              alpha: Double = 1, blurTrail: Double = 0, anchor: CGPoint = CGPoint(x: 0.5, y: 0.5)) {
    guard alpha > 0.001 else { return }
    let size = text.size()
    let origin = CGPoint(x: point.x - size.width * anchor.x, y: point.y - size.height * anchor.y)
    ctx.saveGState()
    ctx.setAlpha(alpha)
    if abs(blurTrail) > 1 {
        for k in stride(from: 4, through: 1, by: -1) {
            ctx.saveGState()
            ctx.setAlpha(alpha * 0.12 * Double(5 - k) / 4)
            text.draw(at: CGPoint(x: origin.x - blurTrail * Double(k) / 4, y: origin.y))
            ctx.restoreGState()
        }
    }
    ctx.setShadow(offset: .zero, blur: 28, color: glow.withAlphaComponent(0.85).cgColor)
    text.draw(at: origin)
    ctx.restoreGState()
}

/// 手本チャートをネオンで描く（rect に収まるよう拡大縮小）
func drawIdealChart(_ ctx: CGContext, id: String, in rect: CGRect, reveal: Double) {
    guard let candles = idealPatternCandles[id], !candles.isEmpty else { return }
    let highs = candles.map(\.high), lows = candles.map(\.low)
    let maxP = highs.max()!, minP = lows.min()!
    let range = max(maxP - minP, 1)
    let slot = rect.width / CGFloat(candles.count)
    let bodyWidth = min(slot * 0.55, 90)
    func y(_ p: Double) -> CGFloat { rect.minY + CGFloat((p - minP) / range) * rect.height }

    // 左から順に描き足して、チャートが走り込んでくるように見せる
    let visible = Double(candles.count) * reveal
    for (i, c) in candles.enumerated() where Double(i) < visible {
        let local = clamp(visible - Double(i))
        let color = c.close >= c.open ? neonRed : neonBlue
        let cx = rect.minX + slot * (CGFloat(i) + 0.5)
        ctx.saveGState()
        ctx.setAlpha(local)
        ctx.setShadow(offset: .zero, blur: 30, color: color.withAlphaComponent(0.9).cgColor)
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(7)
        ctx.move(to: CGPoint(x: cx, y: y(c.low))); ctx.addLine(to: CGPoint(x: cx, y: y(c.high)))
        ctx.strokePath()
        let top = y(max(c.open, c.close)), bottom = y(min(c.open, c.close))
        let body = CGRect(x: cx - bodyWidth / 2, y: bottom, width: bodyWidth, height: max(top - bottom, 8))
        ctx.setFillColor(color.withAlphaComponent(0.3).cgColor)
        ctx.fill(body)
        ctx.setLineWidth(8)
        ctx.stroke(body.insetBy(dx: 4, dy: 4))
        ctx.restoreGState()
    }
}

func drawPhone(_ ctx: CGContext, screen: CGImage?, in rect: CGRect, alpha: Double) {
    guard alpha > 0.001 else { return }
    ctx.saveGState()
    ctx.setAlpha(alpha)
    let bezel = CGPath(roundedRect: rect, cornerWidth: rect.width * 0.16, cornerHeight: rect.width * 0.16, transform: nil)
    ctx.setShadow(offset: .zero, blur: 60, color: neonCyan.withAlphaComponent(0.7).cgColor)
    ctx.addPath(bezel)
    ctx.setFillColor(NSColor.black.cgColor)
    ctx.fillPath()
    ctx.setShadow(offset: .zero, blur: 0, color: nil)
    let screenRect = rect.insetBy(dx: rect.width * 0.035, dy: rect.width * 0.035)
    let screenPath = CGPath(roundedRect: screenRect, cornerWidth: screenRect.width * 0.14,
                            cornerHeight: screenRect.width * 0.14, transform: nil)
    if let screen {
        ctx.saveGState()
        ctx.addPath(screenPath)
        ctx.clip()
        ctx.interpolationQuality = .high
        ctx.draw(screen, in: screenRect)
        ctx.restoreGState()
    }
    ctx.addPath(bezel)
    ctx.setStrokeColor(neonCyan.withAlphaComponent(0.9).cgColor)
    ctx.setLineWidth(6)
    ctx.strokePath()
    ctx.restoreGState()
}

// MARK: - 前景（設計用の座標で描く）

struct Assets {
    let screens: [CGImage?]
    let icon: CGImage?
}

/// つかみ（「ローソク足を／クイズで学ぶ」が叩きつけるように出て、左へ抜ける）
func drawHook(_ ctx: CGContext, t: Double, copy: Copy, lineStarts: (Double, Double), outStart: Double, flash: inout Double) {
    let w = unit.width, h = unit.height
    guard t < outStart + 0.5 else { return }
    let lines = [(copy.hook1, lineStarts.0, h * 0.66), (copy.hook2, lineStarts.1, h * 0.34)]
    let out = easeInCubic(progress(t, outStart, outStart + 0.4))
    for (text, start, y) in lines {
        let p = progress(t, start, start + 0.28)
        guard p > 0 else { continue }
        let scale = 1.7 - 0.7 * easeOutBack(p)
        let font = makeFont(copy.titleFont, 250 * CGFloat(scale), .heavy)
        let x = w / 2 - CGFloat(out) * w * 1.2
        drawText(ctx, attributed(text, font, .white), at: CGPoint(x: x, y: y), glow: neonCyan,
                 alpha: clamp(p * 3), blurTrail: out * 900)
        if t >= start + 0.22 && t < start + 0.4 { flash = max(flash, 0.22 * (1 - progress(t, start + 0.22, start + 0.4))) }
    }
}

/// パターンのカルーセル（手本チャートと名前を高速で切り替える）
func drawCarousel(_ ctx: CGContext, t: Double, copy: Copy, start: Double, end: Double,
                  chartRect: CGRect, nameCenter: CGPoint, nameMaxWidth: CGFloat, baseNameSize: CGFloat,
                  labelCenter: CGPoint, labelSize: CGFloat, alpha: Double, clip: CGRect? = nil, flash: inout Double) {
    guard t >= start && t < end else { return }
    let per = (end - start) / Double(showcase.count)
    let index = min(max(Int((t - start) / per), 0), showcase.count - 1)
    let within = ((t - start) - Double(index) * per) / per
    let item = showcase[index]
    let enter = easeOutCubic(clamp(within / 0.35))
    let exit = easeInCubic(clamp((within - 0.8) / 0.2))
    let dx = CGFloat(1 - enter) * 500 - CGFloat(exit) * 700
    let titleFont = { (size: CGFloat) in makeFont(copy.titleFont, size, .heavy) }
    let color = item.bullish ? neonRed : neonBlue

    ctx.saveGState()
    // 指定があれば、その枠の中だけに描く（滑り込む途中でセーフエリアからはみ出さないように）
    if let clip { ctx.clip(to: clip) }
    ctx.translateBy(x: dx, y: 0)
    drawIdealChart(ctx, id: item.id, in: chartRect, reveal: easeOutCubic(clamp(within / 0.55)))
    let size = fitSize(item.id, titleFont, maxWidth: nameMaxWidth, base: item.id.count > 6 ? baseNameSize * 140 / 170 : baseNameSize)
    drawText(ctx, attributed(item.id, titleFont(size), .white), at: nameCenter, glow: color,
             alpha: alpha * (1 - exit), blurTrail: Double(dx) * 0.6)
    let label = attributed(item.bullish ? "▲ " + copy.bullish : "▼ " + copy.bearish,
                           makeFont(copy.bodyFont, labelSize, .bold), color)
    drawText(ctx, label, at: labelCenter, glow: color, alpha: alpha * (1 - exit))
    ctx.restoreGState()
    if within < 0.12 { flash = max(flash, 0.06) }
}

/// スマホの高さ（設計用の座標の高さに対する割合）。1 を超えた分はセーフエリアの上下にはみ出す
let phoneHeightRatio: CGFloat = 1.42

func phoneRect(slideIn: Double, slideOut: Double) -> CGRect {
    let h = unit.height
    let phoneHeight = h * phoneHeightRatio
    let phoneWidth = phoneHeight * 1206 / 2622
    let x = unit.width * 0.06 + CGFloat(1 - slideIn) * -900 + CGFloat(slideOut) * -1400
    return CGRect(x: x, y: (h - phoneHeight) / 2, width: phoneWidth, height: phoneHeight)
}

/// 特徴の見出し（番号・タイトル・説明）をスマホの右に出す
func drawFeatureCaption(_ ctx: CGContext, copy: Copy, index: Int, phone: CGRect, enter: Double, exit: Double,
                        titleY: CGFloat, compact: Bool = false) {
    let w = unit.width
    let titleFont = { (size: CGFloat) in makeFont(copy.titleFont, size, .heavy) }
    let alpha = enter * (1 - exit)
    let dx = CGFloat(1 - enter) * 600 - CGFloat(exit) * 600
    let textX = phone.maxX + 120 + dx
    let feature = copy.features[index]
    let titleSize = fitSize(feature.title, titleFont, maxWidth: w - phone.maxX - 160, base: compact ? 100 : 120)
    drawText(ctx, attributed("0\(index + 1)", titleFont(compact ? 70 : 90), neonOrange, kern: 6),
             at: CGPoint(x: textX, y: titleY + (compact ? 110 : unit.height * 0.2)), glow: neonOrange, alpha: alpha, anchor: CGPoint(x: 0, y: 0.5))
    drawText(ctx, attributed(feature.title, titleFont(titleSize), .white),
             at: CGPoint(x: textX, y: titleY), glow: neonCyan, alpha: alpha,
             blurTrail: Double(dx) * 0.8, anchor: CGPoint(x: 0, y: 0.5))
    if !compact {
        drawText(ctx, attributed(feature.subtitle, makeFont(copy.bodyFont, 64, .bold), neonCyan),
                 at: CGPoint(x: textX, y: titleY - unit.height * 0.18), glow: neonCyan, alpha: alpha, anchor: CGPoint(x: 0, y: 0.5))
    }
}

/// エンドカード（最後は消えて、冒頭のつかみにつながる）
func drawEndCard(_ ctx: CGContext, t: Double, copy: Copy, assets: Assets, start: Double, flash: inout Double) {
    guard t >= start - 0.1 else { return }
    let w = unit.width, h = unit.height
    let titleFont = { (size: CGFloat) in makeFont(copy.titleFont, size, .heavy) }
    let bodyFont = { (size: CGFloat) in makeFont(copy.bodyFont, size, .bold) }
    let appear = easeOutBack(progress(t, start, start + 0.45))
    let vanish = easeInCubic(progress(t, 14.55, 14.95))
    let alpha = clamp(progress(t, start, start + 0.25)) * (1 - vanish)
    let iconSize = h * 0.5 * CGFloat(0.6 + 0.4 * appear)
    let iconRect = CGRect(x: w * 0.2 - iconSize / 2, y: h * 0.5 - iconSize / 2, width: iconSize, height: iconSize)
    if let icon = assets.icon {
        ctx.saveGState()
        ctx.setAlpha(alpha)
        ctx.setShadow(offset: .zero, blur: 50, color: neonMagenta.withAlphaComponent(0.8).cgColor)
        let path = CGPath(roundedRect: iconRect, cornerWidth: iconSize * 0.22, cornerHeight: iconSize * 0.22, transform: nil)
        ctx.addPath(path); ctx.setFillColor(NSColor.black.cgColor); ctx.fillPath()
        ctx.setShadow(offset: .zero, blur: 0, color: nil)
        ctx.addPath(path); ctx.clip()
        ctx.draw(icon, in: iconRect)
        ctx.restoreGState()
    }
    let textX = w * 0.38
    drawText(ctx, attributed(copy.brand, titleFont(220), .white), at: CGPoint(x: textX, y: h * 0.62),
             glow: neonCyan, alpha: alpha, blurTrail: (1 - appear) * 300, anchor: CGPoint(x: 0, y: 0.5))
    drawText(ctx, attributed(copy.tagline, bodyFont(90), neonCyan, kern: 6), at: CGPoint(x: textX, y: h * 0.4),
             glow: neonCyan, alpha: alpha * clamp(progress(t, start + 0.25, start + 0.5)), anchor: CGPoint(x: 0, y: 0.5))
    drawText(ctx, attributed(copy.endFeatures, bodyFont(fitSize(copy.endFeatures, bodyFont, maxWidth: w - textX - 40, base: 56)), neonOrange),
             at: CGPoint(x: textX, y: h * 0.24), glow: neonOrange,
             alpha: alpha * clamp(progress(t, start + 0.4, start + 0.7)), anchor: CGPoint(x: 0, y: 0.5))
    if t >= start && t < start + 0.2 { flash = max(flash, 0.18 * (1 - progress(t, start, start + 0.2))) }
}

/// 検索結果用: アプリの画面をできるだけ長く見せる構成（Apple は検索結果では実際の体験を見せるよう勧めている）
/// 0〜2秒 つかみ → 2〜13秒 スマホを出したまま特徴を切り替え（図鑑の場面ではパターンを高速表示）→ 13〜15秒 エンドカード
func drawSearchForeground(_ ctx: CGContext, t: Double, copy: Copy, assets: Assets, flash: inout Double) {
    let w = unit.width, h = unit.height

    drawHook(ctx, t: t, copy: copy, lineStarts: (0.1, 0.4), outStart: 1.6, flash: &flash)

    let phoneStart = 2.0, phoneEnd = 13.0
    if t >= phoneStart - 0.1 && t < phoneEnd + 0.2 {
        let phoneIn = easeOutCubic(progress(t, phoneStart, phoneStart + 0.4))
        let phoneOut = easeInCubic(progress(t, phoneEnd - 0.3, phoneEnd))
        let phone = phoneRect(slideIn: phoneIn, slideOut: phoneOut)
        // 特徴ごとの区切り（最後の「図鑑」は、パターンを見せるため長めにとる）
        let marks = [phoneStart, 4.4, 6.8, 9.2, phoneEnd]
        let index = min(max((marks.lastIndex(where: { t >= $0 }) ?? 0), 0), copy.features.count - 1)
        let within = (t - marks[index]) / (marks[index + 1] - marks[index])
        drawPhone(ctx, screen: assets.screens[index], in: phone, alpha: clamp(phoneIn * 2) * (1 - phoneOut))

        let enter = easeOutCubic(clamp((t - marks[index]) / 0.3))
        let isLast = index == copy.features.count - 1
        let exit = isLast ? phoneOut : easeInCubic(clamp((t - (marks[index + 1] - 0.25)) / 0.25))
        if isLast {
            // 図鑑: 見出しを上に置き、その下でパターンを高速に切り替える
            drawFeatureCaption(ctx, copy: copy, index: index, phone: phone, enter: enter, exit: exit,
                               titleY: h * 0.83, compact: true)
            let panelX = phone.maxX + 120
            let panelWidth = w - panelX - 40
            drawCarousel(ctx, t: t, copy: copy, start: 9.6, end: phoneEnd - 0.3,
                         chartRect: CGRect(x: panelX, y: h * 0.06, width: panelWidth * 0.48, height: h * 0.6),
                         nameCenter: CGPoint(x: panelX + panelWidth * 0.75, y: h * 0.42),
                         nameMaxWidth: panelWidth * 0.5, baseNameSize: 130,
                         labelCenter: CGPoint(x: panelX + panelWidth * 0.75, y: h * 0.25), labelSize: 56,
                         alpha: clamp(progress(t, 9.6, 9.8)) * (1 - phoneOut),
                         clip: CGRect(x: panelX - 60, y: 0, width: w - panelX + 60, height: h * 0.7), flash: &flash)
        } else {
            drawFeatureCaption(ctx, copy: copy, index: index, phone: phone, enter: enter, exit: exit, titleY: h * 0.5)
        }
        if t - marks[index] < 0.1 && index > 0 { flash = max(flash, 0.08) }
    }

    drawEndCard(ctx, t: t, copy: copy, assets: assets, start: 13.1, flash: &flash)
}

/// 検索結果用（パターン先出し）: 0〜2.3秒 つかみ → 2.3〜5.5秒 パターンを高速で切り替え
/// → 5.5〜13秒 スマホで特徴を切り替え → 13〜15秒 エンドカード
func drawSearchCarouselFirstForeground(_ ctx: CGContext, t: Double, copy: Copy, assets: Assets, flash: inout Double) {
    let w = unit.width, h = unit.height
    let titleFont = { (size: CGFloat) in makeFont(copy.titleFont, size, .heavy) }

    drawHook(ctx, t: t, copy: copy, lineStarts: (0.1, 0.4), outStart: 1.9, flash: &flash)

    let carouselStart = 2.3, carouselEnd = 5.5
    if t >= carouselStart - 0.1 && t < carouselEnd + 0.1 {
        let alpha = clamp(progress(t, carouselStart - 0.1, carouselStart)) * (1 - clamp(progress(t, carouselEnd - 0.1, carouselEnd)))
        // 42 PATTERNS のカウンター
        let count = Int(1 + 41 * easeOutCubic(progress(t, carouselStart, carouselEnd - 0.4)))
        let counter = NSMutableAttributedString(attributedString: attributed("\(count) ", titleFont(150), neonOrange))
        counter.append(attributed(copy.patternsLabel, titleFont(70), neonOrange, kern: 10))
        drawText(ctx, counter, at: CGPoint(x: w / 2, y: h * 0.9), glow: neonOrange, alpha: alpha)
        drawCarousel(ctx, t: t, copy: copy, start: carouselStart, end: carouselEnd,
                     chartRect: CGRect(x: w * 0.06, y: h * 0.1, width: w * 0.42, height: h * 0.62),
                     nameCenter: CGPoint(x: w * 0.74, y: h * 0.46), nameMaxWidth: w * 0.48, baseNameSize: 170,
                     labelCenter: CGPoint(x: w * 0.74, y: h * 0.25), labelSize: 70,
                     alpha: alpha, flash: &flash)
    }

    let phoneStart = carouselEnd, phoneEnd = 13.0
    if t >= phoneStart - 0.1 && t < phoneEnd + 0.2 {
        let phoneIn = easeOutCubic(progress(t, phoneStart, phoneStart + 0.4))
        let phoneOut = easeInCubic(progress(t, phoneEnd - 0.3, phoneEnd))
        let phone = phoneRect(slideIn: phoneIn, slideOut: phoneOut)
        let per = (phoneEnd - phoneStart) / Double(copy.features.count)
        let index = min(max(Int((t - phoneStart) / per), 0), copy.features.count - 1)
        let start = phoneStart + Double(index) * per
        drawPhone(ctx, screen: assets.screens[index], in: phone, alpha: clamp(phoneIn * 2) * (1 - phoneOut))
        let enter = easeOutCubic(clamp((t - start) / 0.3))
        let exit = index == copy.features.count - 1 ? phoneOut : easeInCubic(clamp((t - (start + per - 0.25)) / 0.25))
        drawFeatureCaption(ctx, copy: copy, index: index, phone: phone, enter: enter, exit: exit, titleY: h * 0.5)
        if t - start < 0.1 && index > 0 { flash = max(flash, 0.08) }
    }

    drawEndCard(ctx, t: t, copy: copy, assets: assets, start: 13.1, flash: &flash)
}

/// 横幅に収まる文字サイズを返す
func fitSize(_ text: String, _ font: (CGFloat) -> NSFont, maxWidth: CGFloat, base: CGFloat) -> CGFloat {
    var size = base
    while size > 20 && attributed(text, font(size), .white).size().width > maxWidth { size -= 4 }
    return size
}

// MARK: - ヘッダーの静止画

/// セーフエリアの外を飾る大きなネオンのローソク足（左は下がる陰線、右は上がる陽線）
func drawSideCandles(_ ctx: CGContext, format: VideoFormat) {
    let safe = format.safe
    let canvasWidth = CGFloat(format.width)
    for side in [-1.0, 1.0] {
        let rising = side > 0
        let count = 5
        let areaLeft = rising ? safe.maxX + safe.height * 0.25 : safe.height * 0.25
        let areaRight = rising ? canvasWidth - safe.height * 0.25 : safe.minX - safe.height * 0.25
        let areaWidth = areaRight - areaLeft
        guard areaWidth > 0 else { continue }
        let slot = areaWidth / CGFloat(count)
        let bodyWidth = min(slot * 0.45, safe.height * 0.12)
        let bottom = safe.midY - safe.height * 0.55, top = safe.midY + safe.height * 0.55
        let color = rising ? neonRed : neonBlue
        for i in 0..<count {
            let step = CGFloat(i) / CGFloat(count - 1)
            let progressY = rising ? step : 1 - step
            let cx = areaLeft + slot * (CGFloat(i) + 0.5)
            let lowBody = bottom + (top - bottom) * progressY * 0.7
            let highBody = lowBody + (top - bottom) * 0.22
            ctx.saveGState()
            ctx.setShadow(offset: .zero, blur: safe.height * 0.05, color: color.withAlphaComponent(0.9).cgColor)
            ctx.setStrokeColor(color.withAlphaComponent(0.75).cgColor)
            ctx.setLineWidth(safe.height * 0.012)
            ctx.move(to: CGPoint(x: cx, y: lowBody - safe.height * 0.06))
            ctx.addLine(to: CGPoint(x: cx, y: highBody + safe.height * 0.06))
            ctx.strokePath()
            let body = CGRect(x: cx - bodyWidth / 2, y: lowBody, width: bodyWidth, height: highBody - lowBody)
            ctx.setFillColor(color.withAlphaComponent(0.22).cgColor)
            ctx.fill(body)
            ctx.setLineWidth(safe.height * 0.014)
            ctx.stroke(body.insetBy(dx: safe.height * 0.007, dy: safe.height * 0.007))
            ctx.restoreGState()
        }
    }
}

/// ヘッダーの静止画の主役（アイコン・アプリ名・ひとことで伝える価値）を box の中に収める。
/// box が横長ならアイコンと文字を横に並べ、縦長気味なら縦に積む
func drawHeaderImageForeground(_ ctx: CGContext, copy: Copy, assets: Assets, box: CGRect) {
    let titleFont = { (size: CGFloat) in makeFont(copy.titleFont, size, .heavy) }
    let bodyFont = { (size: CGFloat) in makeFont(copy.bodyFont, size, .bold) }
    let headline = copy.hook1 + copy.hook2
    let horizontal = box.width / box.height >= 1.8

    func drawIcon(_ rect: CGRect) {
        guard let icon = assets.icon else { return }
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: rect.width * 0.12, color: neonMagenta.withAlphaComponent(0.8).cgColor)
        let path = CGPath(roundedRect: rect, cornerWidth: rect.width * 0.22, cornerHeight: rect.width * 0.22, transform: nil)
        ctx.addPath(path); ctx.setFillColor(NSColor.black.cgColor); ctx.fillPath()
        ctx.setShadow(offset: .zero, blur: 0, color: nil)
        ctx.addPath(path); ctx.clip()
        ctx.draw(icon, in: rect)
        ctx.restoreGState()
    }

    if horizontal {
        let iconSize = box.height * 0.8
        let gap = box.height * 0.12
        let textMax = box.width - iconSize - gap
        let brand = attributed(copy.brand, titleFont(fitSize(copy.brand, titleFont, maxWidth: textMax, base: box.height * 0.3)), .white)
        let head = attributed(headline, titleFont(fitSize(headline, titleFont, maxWidth: textMax, base: box.height * 0.15)), neonCyan)
        let features = attributed(copy.endFeatures, bodyFont(fitSize(copy.endFeatures, bodyFont, maxWidth: textMax, base: box.height * 0.08)), neonOrange)
        let textWidth = max(brand.size().width, head.size().width, features.size().width)
        let groupX = box.midX - (iconSize + gap + textWidth) / 2
        drawIcon(CGRect(x: groupX, y: box.midY - iconSize / 2, width: iconSize, height: iconSize))
        let textX = groupX + iconSize + gap
        drawText(ctx, brand, at: CGPoint(x: textX, y: box.midY + box.height * 0.2), glow: neonCyan, anchor: CGPoint(x: 0, y: 0.5))
        drawText(ctx, head, at: CGPoint(x: textX, y: box.midY - box.height * 0.08), glow: neonCyan, anchor: CGPoint(x: 0, y: 0.5))
        drawText(ctx, features, at: CGPoint(x: textX, y: box.midY - box.height * 0.29), glow: neonOrange, anchor: CGPoint(x: 0, y: 0.5))
    } else {
        let iconSize = box.height * 0.42
        let brand = attributed(copy.brand, titleFont(fitSize(copy.brand, titleFont, maxWidth: box.width, base: box.height * 0.17)), .white)
        let head = attributed(headline, titleFont(fitSize(headline, titleFont, maxWidth: box.width, base: box.height * 0.09)), neonCyan)
        let features = attributed(copy.endFeatures, bodyFont(fitSize(copy.endFeatures, bodyFont, maxWidth: box.width, base: box.height * 0.055)), neonOrange)
        let gap = box.height * 0.04
        let heights = [iconSize, brand.size().height, head.size().height, features.size().height]
        let total = heights.reduce(0, +) + gap * 3
        var y = box.midY + total / 2
        drawIcon(CGRect(x: box.midX - iconSize / 2, y: y - iconSize, width: iconSize, height: iconSize))
        y -= iconSize + gap
        for (text, glow) in [(brand, neonCyan), (head, neonCyan), (features, neonOrange)] {
            let h = text.size().height
            drawText(ctx, text, at: CGPoint(x: box.midX, y: y - h / 2), glow: glow)
            y -= h + gap
        }
    }
}

// MARK: - 1コマの描画

func renderFrame(_ ctx: CGContext, format: VideoFormat, background: Background, t: Double, copy: Copy, assets: Assets) {
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
    background.draw(ctx, t: t)
    if format.name.hasPrefix("header") {
        background.flow.draw(ctx, t: t)
        NSGraphicsContext.restoreGraphicsState()
        return
    }
    let isImage = format.name.hasPrefix("image")
    if isImage { drawSideCandles(ctx, format: format) }

    // 文字が読みやすいよう、セーフエリアの裏だけ背景を暗く沈める（外側の動きはそのまま見せる）
    let safe = format.safe
    let dim = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [
        CGColor(red: 0.01, green: 0.01, blue: 0.04, alpha: 0.78),
        CGColor(red: 0.01, green: 0.01, blue: 0.04, alpha: 0),
    ] as CFArray, locations: [0.35, 1])!
    ctx.saveGState()
    ctx.translateBy(x: safe.midX, y: safe.midY)
    ctx.scaleBy(x: 1, y: safe.height / safe.width)
    // 検索結果の動画は前景を画面いっぱいに広げるので、暗くする範囲も広げる
    let dimScale: CGFloat = isImage ? 1 : searchContentRatio * CGFloat(format.width) / safe.width
    ctx.drawRadialGradient(dim, startCenter: .zero, startRadius: 0, endCenter: .zero,
                           endRadius: safe.width * 0.72 * dimScale, options: [])
    ctx.restoreGState()

    if isImage {
        // 静止画は、セーフエリアのさらに内側の範囲に主役を収める（端末による見切れ対策）
        let box = safe.insetBy(dx: safe.width * (1 - imageContentScale) / 2, dy: safe.height * (1 - imageContentScale) / 2)
        drawHeaderImageForeground(ctx, copy: copy, assets: assets, box: box)
        NSGraphicsContext.restoreGraphicsState()
        return
    }
    // 検索結果の動画は、セーフエリアではなく画面の横幅いっぱい（searchContentRatio）に前景を広げる
    let content = CGRect(x: 0, y: 0, width: format.width, height: format.height)
    let scale = content.width * searchContentRatio / unit.width
    ctx.saveGState()
    ctx.translateBy(x: content.midX - unit.width * scale / 2, y: content.midY - unit.height * scale / 2)
    ctx.scaleBy(x: scale, y: scale)
    var flash = 0.0
    if format.name.contains("carousel") {
        drawSearchCarouselFirstForeground(ctx, t: t, copy: copy, assets: assets, flash: &flash)
    } else {
        drawSearchForeground(ctx, t: t, copy: copy, assets: assets, flash: &flash)
    }
    ctx.restoreGState()

    if flash > 0 {
        ctx.setFillColor(NSColor.white.withAlphaComponent(flash).cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: format.width, height: format.height))
    }
    NSGraphicsContext.restoreGraphicsState()
}

// MARK: - 書き出し

func writeStills(format: VideoFormat, language: String, copy: Copy, assets: Assets, to directory: URL) throws {
    let background = Background(width: format.width, height: format.height)
    let times = format.name.contains("carousel") ? [1.0, 3.5, 6.5, 8.5, 10.5, 12.3, 13.8]
        : format.name.hasPrefix("search") ? [1.0, 3.2, 7.5, 10.5, 12.2, 13.8] : [0.0, 5.0, 14.96]
    for t in times {
        guard let ctx = CGContext(data: nil, width: format.width, height: format.height, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        else { continue }
        renderFrame(ctx, format: format, background: background, t: t, copy: copy, assets: assets)
        // セーフエリアの枠を重ねて、はみ出していないか確かめられるようにする
        ctx.setStrokeColor(NSColor.yellow.cgColor)
        ctx.setLineWidth(6)
        ctx.stroke(format.safe)
        let url = directory.appendingPathComponent("\(format.name)_\(language)_t\(String(format: "%04.1f", t)).png")
        let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
        CGImageDestinationFinalize(dest)
        print("still \(url.lastPathComponent)")
    }
}

func writeVideo(format: VideoFormat, language: String, copy: Copy, assets: Assets, to url: URL) throws {
    try? FileManager.default.removeItem(at: url)
    let background = Background(width: format.width, height: format.height)

    for codec in [AVVideoCodecType.h264, .hevc] {
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        var compression: [String: Any] = [
            AVVideoAverageBitRateKey: format.height > 2000 ? 60_000_000 : 45_000_000,
            AVVideoMaxKeyFrameIntervalKey: Int(fps),
            AVVideoExpectedSourceFrameRateKey: Int(fps),
        ]
        if codec == .h264 { compression[AVVideoProfileLevelKey] = AVVideoProfileLevelH264HighAutoLevel }
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: codec,
            AVVideoWidthKey: format.width,
            AVVideoHeightKey: format.height,
            AVVideoCompressionPropertiesKey: compression,
        ])
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: format.width,
            kCVPixelBufferHeightKey as String: format.height,
        ])
        guard writer.canAdd(input) else { continue }
        writer.add(input)
        guard writer.startWriting() else {
            print("\(codec.rawValue) は使えないため次の形式を試します: \(writer.error?.localizedDescription ?? "")")
            try? FileManager.default.removeItem(at: url)
            continue
        }
        writer.startSession(atSourceTime: .zero)

        var failed = false
        for frame in 0..<frameCount {
            while !input.isReadyForMoreMediaData { usleep(2000) }
            guard let pool = adaptor.pixelBufferPool else { failed = true; break }
            var buffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
            guard let buffer else { failed = true; break }
            CVPixelBufferLockBaseAddress(buffer, [])
            let ctx = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: format.width, height: format.height,
                                bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
            renderFrame(ctx, format: format, background: background, t: Double(frame) / Double(fps), copy: copy, assets: assets)
            CVPixelBufferUnlockBaseAddress(buffer, [])
            if !adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: fps)) {
                print("フレーム \(frame) の書き込みに失敗: \(writer.error?.localizedDescription ?? "")")
                failed = true
                break
            }
            if frame % 90 == 0 { print("  \(format.name) \(language) \(frame)/\(frameCount)") }
        }
        input.markAsFinished()
        let done = DispatchSemaphore(value: 0)
        writer.finishWriting { done.signal() }
        done.wait()
        if !failed && writer.status == .completed {
            print("wrote \(url.path) (\(codec.rawValue))")
            return
        }
        print("\(codec.rawValue) での書き出しに失敗: \(writer.error?.localizedDescription ?? "")")
        try? FileManager.default.removeItem(at: url)
    }
    throw NSError(domain: "promo", code: 1, userInfo: [NSLocalizedDescriptionKey: "動画を書き出せませんでした"])
}

/// ヘッダーの静止画を書き出す。確認用に、セーフエリアと主役の範囲の枠を重ねた画像も別に出す
func writeHeaderImages(language: String, copy: Copy, assets: Assets, to directory: URL, previewDirectory: URL) throws {
    for format in imageFormats {
        let background = Background(width: format.width, height: format.height)
        for preview in [false, true] {
            guard let ctx = CGContext(data: nil, width: format.width, height: format.height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
            else { continue }
            renderFrame(ctx, format: format, background: background, t: 3.3, copy: copy, assets: assets)
            if preview {
                ctx.setLineWidth(6)
                ctx.setStrokeColor(NSColor.yellow.cgColor)
                ctx.stroke(format.safe)
                ctx.setStrokeColor(NSColor.green.cgColor)
                ctx.stroke(format.safe.insetBy(dx: format.safe.width * (1 - imageContentScale) / 2,
                                               dy: format.safe.height * (1 - imageContentScale) / 2))
            }
            let base = String(format.name.dropFirst("image_".count))
            let url = preview ? previewDirectory.appendingPathComponent("\(base)_preview.png")
                              : directory.appendingPathComponent("\(base).png")
            let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
            CGImageDestinationAddImage(dest, ctx.makeImage()!, [kCGImagePropertyDPIWidth: 72, kCGImagePropertyDPIHeight: 72] as CFDictionary)
            CGImageDestinationFinalize(dest)
            print("wrote \(url.path)")
        }
    }
}

// MARK: - 実行

var arguments = Array(CommandLine.arguments.dropFirst())
let stillsOnly = arguments.contains("--stills")
let imagesOnly = arguments.contains("--images")
arguments.removeAll { $0.hasPrefix("--") }
let shotsDirectory = ProcessInfo.processInfo.environment["SHOTS_DIR"] ?? repoRoot.appendingPathComponent("AppStoreScreenshots/PromoVideo/shots").path
let outputDirectory = URL(fileURLWithPath: ProcessInfo.processInfo.environment["OUTPUT_DIR"]
    ?? repoRoot.appendingPathComponent("AppStoreScreenshots/PromoVideo/output").path)
let languages = arguments.isEmpty ? ["ja"] : arguments

for language in languages {
    guard let copy = copies[language] else { print("文言がありません: \(language)"); continue }
    let shots = ProcessInfo.processInfo.environment["SHOTS_DIR"].map { _ in shotsDirectory } ?? "\(shotsDirectory)/\(language)"
    let assets = Assets(
        screens: ["title", "pattern", "answer", "study"].map { loadImage("\(shots)/\($0).png") },
        icon: loadImage(repoRoot.appendingPathComponent("SakataChartQuiz/Assets.xcassets/AppIcon.appiconset/oneline_neon_icon_1024.png").path)
    )
    if assets.screens.contains(where: { $0 == nil }) { print("アプリ画面の画像が足りません: \(shots)") }
    let directory = outputDirectory.appendingPathComponent(language)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    if imagesOnly {
        // 静止画は小さいのでリポジトリに残す（AppStoreScreenshots/HeaderImage/<言語>/）
        let imageDirectory = repoRoot.appendingPathComponent("AppStoreScreenshots/HeaderImage/\(language)")
        try FileManager.default.createDirectory(at: imageDirectory, withIntermediateDirectories: true)
        try writeHeaderImages(language: language, copy: copy, assets: assets, to: imageDirectory, previewDirectory: directory)
        continue
    }
    // FORMATS=search のように指定すると、その名前で始まるフォーマットだけ書き出す
    let onlyFormats = ProcessInfo.processInfo.environment["FORMATS"]?.split(separator: ",").map(String.init)
    for format in formats where onlyFormats == nil || onlyFormats!.contains(where: { format.name.hasPrefix($0) }) {
        if stillsOnly {
            try writeStills(format: format, language: language, copy: copy, assets: assets, to: directory)
        } else {
            try writeVideo(format: format, language: language, copy: copy, assets: assets,
                           to: directory.appendingPathComponent("\(format.name).mp4"))
        }
    }
}
