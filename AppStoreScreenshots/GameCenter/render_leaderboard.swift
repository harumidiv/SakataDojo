// Game Center のリーダーボード画像を言語ごとに書き出す。
// 使い方: リポジトリのルートで `swift AppStoreScreenshots/GameCenter/render_leaderboard.swift`
// 出力: AppStoreScreenshots/GameCenter/<言語>/<リーダーボード>_1024.png（1024×1024・透過なしの RGB PNG）
//   best_streak_1024.png       … sakatadojo.leaderboard.bestStreak（最高連続正解）
//   daily_best_streak_1024.png … sakatadojo.leaderboard.dailyBestStreak（デイリー最長連続日数）
import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct LocaleSpec {
    let identifier: String
    let brand: String
    let fontName: String?
}

let locales = [
    LocaleSpec(identifier: "ja", brand: "酒田道場", fontName: "HiraginoSans-W8"),
    LocaleSpec(identifier: "en", brand: "SAKATA DOJO", fontName: nil),
    LocaleSpec(identifier: "ko", brand: "사카타 도장", fontName: "AppleSDGothicNeo-Heavy"),
    LocaleSpec(identifier: "zh-Hant", brand: "酒田道場", fontName: "PingFangTC-Semibold"),
    LocaleSpec(identifier: "vi", brand: "SAKATA DOJO", fontName: nil),
]

enum Motif {
    /// 右肩上がりの陽線と稲妻（連続正解）
    case risingCandles
    /// 7日分のカレンダーと炎（デイリーの連続日数）
    case dailyCalendar
}

struct LeaderboardSpec {
    let fileName: String
    let motif: Motif
    /// 言語ごとの表示名（App Store Connect のリーダーボードの表示名と同じにする）
    let titles: [String: String]
}

let leaderboards = [
    LeaderboardSpec(fileName: "best_streak_1024.png", motif: .risingCandles, titles: [
        "ja": "最高連続正解",
        "en": "Best Correct Streak",
        "ko": "최고 연속 정답",
        "zh-Hant": "最高連續答對",
        "vi": "Chuỗi đúng dài nhất",
    ]),
    LeaderboardSpec(fileName: "daily_best_streak_1024.png", motif: .dailyCalendar, titles: [
        "ja": "デイリー最長連続日数",
        "en": "Longest Daily Streak",
        "ko": "데일리 최장 연속 일수",
        "zh-Hant": "每日挑戰最長連續天數",
        "vi": "Chuỗi ngày dài nhất",
    ]),
]

let size: CGFloat = 1024
let neonRed = NSColor(calibratedRed: 1.00, green: 0.25, blue: 0.36, alpha: 1)
let neonCyan = NSColor(calibratedRed: 0.23, green: 0.83, blue: 1.00, alpha: 1)
let neonOrange = NSColor(calibratedRed: 1.00, green: 0.67, blue: 0.20, alpha: 1)
let neonMagenta = NSColor(calibratedRed: 0.96, green: 0.23, blue: 0.76, alpha: 1)

func font(_ name: String?, size: CGFloat, weight: NSFont.Weight) -> NSFont {
    if let name, let font = NSFont(name: name, size: size) { return font }
    return NSFont.systemFont(ofSize: size, weight: weight)
}

/// 光彩つきで線や面を描く（ネオン管のように外側をぼかしてから芯を描く）
func withGlow(_ ctx: CGContext, color: NSColor, blur: CGFloat, _ draw: () -> Void) {
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: blur, color: color.withAlphaComponent(0.9).cgColor)
    draw()
    draw()
    ctx.restoreGState()
}

func drawBackground(_ ctx: CGContext) {
    let space = CGColorSpaceCreateDeviceRGB()
    let colors = [
        CGColor(red: 0.07, green: 0.09, blue: 0.20, alpha: 1),
        CGColor(red: 0.01, green: 0.01, blue: 0.04, alpha: 1),
    ] as CFArray
    let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1])!
    ctx.drawRadialGradient(
        gradient,
        startCenter: CGPoint(x: size * 0.5, y: size * 0.58), startRadius: 0,
        endCenter: CGPoint(x: size * 0.5, y: size * 0.5), endRadius: size * 0.75,
        options: [.drawsAfterEndLocation]
    )

    // 薄い方眼（チャートの目盛り）
    ctx.saveGState()
    ctx.setStrokeColor(neonCyan.withAlphaComponent(0.07).cgColor)
    ctx.setLineWidth(2)
    for i in stride(from: 64, to: Int(size), by: 64) {
        let v = CGFloat(i)
        ctx.move(to: CGPoint(x: v, y: 0)); ctx.addLine(to: CGPoint(x: v, y: size))
        ctx.move(to: CGPoint(x: 0, y: v)); ctx.addLine(to: CGPoint(x: size, y: v))
    }
    ctx.strokePath()
    ctx.restoreGState()
}

/// 右肩上がりに続く陽線（＝連続正解）を描く。座標は左下原点
func drawRisingCandles(_ ctx: CGContext) {
    let count = 7
    let left: CGFloat = 170, right: CGFloat = 620
    let bottom: CGFloat = 390, top: CGFloat = 760
    let slot = (right - left) / CGFloat(count - 1)
    let bodyWidth: CGFloat = 44

    for i in 0..<count {
        let t = CGFloat(i) / CGFloat(count - 1)
        let cx = left + slot * CGFloat(i)
        let open = bottom + (top - bottom) * t * 0.82
        let close = open + 70 + 30 * t
        let high = close + 26
        let low = open - 24
        // 手前から奥へ、マゼンタ → 赤 と少しずつ色を変える
        let color = neonMagenta.blended(withFraction: t, of: neonRed) ?? neonRed

        withGlow(ctx, color: color, blur: 26) {
            ctx.setStrokeColor(color.cgColor)
            ctx.setLineWidth(6)
            ctx.move(to: CGPoint(x: cx, y: low)); ctx.addLine(to: CGPoint(x: cx, y: high))
            ctx.strokePath()
            let body = CGRect(x: cx - bodyWidth / 2, y: open, width: bodyWidth, height: close - open)
            ctx.setFillColor(color.withAlphaComponent(0.28).cgColor)
            ctx.fill(body)
            ctx.setLineWidth(7)
            ctx.stroke(body.insetBy(dx: 3.5, dy: 3.5))
        }
    }

    // 上昇の流れを示すネオンの線
    withGlow(ctx, color: neonCyan, blur: 22) {
        ctx.setStrokeColor(neonCyan.cgColor)
        ctx.setLineWidth(6)
        ctx.setLineCap(.round)
        ctx.move(to: CGPoint(x: left - 40, y: bottom - 60))
        ctx.addCurve(
            to: CGPoint(x: right + 40, y: top + 40),
            control1: CGPoint(x: left + 140, y: bottom - 40),
            control2: CGPoint(x: right - 120, y: top - 10)
        )
        ctx.strokePath()
    }
}

/// 7日分のカレンダーに、毎日挑戦したしるしのチェックが並ぶ絵
func drawDailyCalendar(_ ctx: CGContext) {
    let columns = 7
    let cell: CGFloat = 92, gap: CGFloat = 16
    let totalWidth = CGFloat(columns) * cell + CGFloat(columns - 1) * gap
    let left = (size - totalWidth) / 2
    let y: CGFloat = 430

    // 上の帯（カレンダーの綴じ部分）
    withGlow(ctx, color: neonCyan, blur: 22) {
        ctx.setStrokeColor(neonCyan.cgColor)
        ctx.setLineWidth(6)
        ctx.setLineCap(.round)
        ctx.move(to: CGPoint(x: left, y: y + cell + 40))
        ctx.addLine(to: CGPoint(x: left + totalWidth, y: y + cell + 40))
        ctx.strokePath()
    }

    for i in 0..<columns {
        let t = CGFloat(i) / CGFloat(columns - 1)
        let color = neonMagenta.blended(withFraction: t, of: neonRed) ?? neonRed
        let rect = CGRect(x: left + CGFloat(i) * (cell + gap), y: y, width: cell, height: cell)
        withGlow(ctx, color: color, blur: 24) {
            let path = CGPath(roundedRect: rect.insetBy(dx: 3.5, dy: 3.5), cornerWidth: 18, cornerHeight: 18, transform: nil)
            ctx.addPath(path)
            ctx.setFillColor(color.withAlphaComponent(0.22).cgColor)
            ctx.fillPath()
            ctx.addPath(path)
            ctx.setStrokeColor(color.cgColor)
            ctx.setLineWidth(7)
            ctx.strokePath()

            // チェックマーク
            ctx.setStrokeColor(NSColor.white.cgColor)
            ctx.setLineWidth(9)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            ctx.move(to: CGPoint(x: rect.minX + cell * 0.25, y: rect.minY + cell * 0.52))
            ctx.addLine(to: CGPoint(x: rect.minX + cell * 0.44, y: rect.minY + cell * 0.32))
            ctx.addLine(to: CGPoint(x: rect.minX + cell * 0.76, y: rect.minY + cell * 0.70))
            ctx.strokePath()
        }
    }
}

/// アプリで連続正解を表す稲妻マーク / デイリーの連続日数を表す炎マーク
func drawSymbol(_ ctx: CGContext, name: String, center: CGPoint, height: CGFloat) {
    guard let symbol = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
        .withSymbolConfiguration(.init(pointSize: 230, weight: .black)) else { return }
    let tinted = NSImage(size: symbol.size, flipped: false) { rect in
        symbol.draw(in: rect)
        neonOrange.set()
        rect.fill(using: .sourceAtop)
        return true
    }
    let width = height * tinted.size.width / tinted.size.height
    let rect = CGRect(x: center.x - width / 2, y: center.y - height / 2, width: width, height: height)
    withGlow(ctx, color: neonOrange, blur: 40) {
        tinted.draw(in: rect)
    }
}

/// 横幅に収まるまで文字を小さくしてから、中央揃えで描く
func drawCentered(_ text: String, font baseFont: NSFont, color: NSColor, glow: NSColor,
                  centerY: CGFloat, maxWidth: CGFloat, kern: CGFloat = 0, ctx: CGContext) {
    var pointSize = baseFont.pointSize
    var attributed: NSAttributedString
    repeat {
        let f = NSFont(descriptor: baseFont.fontDescriptor, size: pointSize) ?? baseFont
        attributed = NSAttributedString(string: text, attributes: [
            .font: f, .foregroundColor: color, .kern: kern,
        ])
        pointSize -= 2
    } while attributed.size().width > maxWidth && pointSize > 20

    let textSize = attributed.size()
    let origin = CGPoint(x: (size - textSize.width) / 2, y: centerY - textSize.height / 2)
    withGlow(ctx, color: glow, blur: 18) {
        attributed.draw(at: origin)
    }
}

func render(_ leaderboard: LeaderboardSpec, _ locale: LocaleSpec, to url: URL) throws {
    // noneSkipLast でアルファチャンネルを持たない画像にする（App Store Connect は透過を受け付けない）
    guard let ctx = CGContext(
        data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ) else { throw NSError(domain: "render", code: 1) }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)

    drawBackground(ctx)
    switch leaderboard.motif {
    case .risingCandles:
        drawRisingCandles(ctx)
        drawSymbol(ctx, name: "bolt.fill", center: CGPoint(x: 800, y: 765), height: 250)
    case .dailyCalendar:
        drawDailyCalendar(ctx)
        drawSymbol(ctx, name: "flame.fill", center: CGPoint(x: size / 2, y: 735), height: 230)
    }

    // 表示時に角が丸く切られても欠けないよう、文字は中央 約80% の幅に収める
    drawCentered(leaderboard.titles[locale.identifier] ?? "",
                 font: font(locale.fontName, size: 104, weight: .heavy),
                 color: .white, glow: neonCyan, centerY: 250, maxWidth: 820, ctx: ctx)
    drawCentered(locale.brand,
                 font: font(locale.fontName, size: 44, weight: .bold),
                 color: neonCyan, glow: neonCyan, centerY: 140, maxWidth: 700,
                 kern: locale.identifier == "en" || locale.identifier == "vi" ? 8 : 4, ctx: ctx)

    NSGraphicsContext.restoreGraphicsState()

    guard let image = ctx.makeImage(),
          let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
    else { throw NSError(domain: "render", code: 2) }
    CGImageDestinationAddImage(destination, image, [kCGImagePropertyDPIWidth: 72, kCGImagePropertyDPIHeight: 72] as CFDictionary)
    guard CGImageDestinationFinalize(destination) else { throw NSError(domain: "render", code: 3) }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("AppStoreScreenshots/GameCenter")
for leaderboard in leaderboards {
    for locale in locales {
        let directory = root.appendingPathComponent(locale.identifier)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(leaderboard.fileName)
        try render(leaderboard, locale, to: url)
        print("wrote \(url.path)")
    }
}
