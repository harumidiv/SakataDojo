import SwiftUI

struct CandlestickChartView: View {
    let candles: [Candle]
    let dividerIndex: Int?
    let showsVolume: Bool
    let showsMovingAverages: Bool
    let highlightedPrice: Double?

    init(
        candles: [Candle],
        dividerIndex: Int?,
        showsVolume: Bool = true,
        showsMovingAverages: Bool = true,
        highlightedPrice: Double? = nil
    ) {
        self.candles = candles
        self.dividerIndex = dividerIndex
        self.showsVolume = showsVolume
        self.showsMovingAverages = showsMovingAverages
        self.highlightedPrice = highlightedPrice
    }

    private var maxPrice: Double { candles.map { $0.high }.max() ?? 0 }
    private var minPrice: Double { candles.map { $0.low }.min() ?? 0 }
    private var maxVolume: Double { Double(candles.map { $0.volume }.max() ?? 1) }

    private func ma(_ period: Int) -> [Double?] {
        let closes = candles.map { $0.close }
        return closes.indices.map { i in
            guard i >= period - 1 else { return nil }
            return closes[(i - period + 1)...i].reduce(0, +) / Double(period)
        }
    }

    var body: some View {
        Canvas { context, size in
            guard !candles.isEmpty else { return }

            let volumeHeight = showsVolume ? size.height * 0.2 : 0
            let chartHeight = size.height - volumeHeight - (showsVolume ? 6 : 0)
            let priceScale = PriceScale(low: minPrice, high: maxPrice, height: chartHeight)
            let priceY = priceScale.y(for:)

            let slotWidth = size.width / CGFloat(candles.count)
            let bodyWidth = Self.bodyWidth(for: slotWidth)

            func drawMA(_ values: [Double?], color: Color) {
                var path = Path()
                var started = false
                for (i, val) in values.enumerated() {
                    guard let v = val else { continue }
                    let x = CGFloat(i) * slotWidth + slotWidth / 2
                    let y = priceY(v)
                    if !started {
                        path.move(to: CGPoint(x: x, y: y))
                        started = true
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                context.stroke(path, with: .color(color), lineWidth: 1.2)
            }

            if showsMovingAverages {
                drawMA(ma(5),  color: Color(red: 1.0, green: 0.6, blue: 0.0))  // 5日: オレンジ
                drawMA(ma(25), color: Color(red: 0.2, green: 0.7, blue: 0.3))  // 25日: グリーン
            }

            for (i, candle) in candles.enumerated() {
                let cx = CGFloat(i) * slotWidth + slotWidth / 2
                let isBullish = candle.close >= candle.open
                let isAnswer = dividerIndex.map { i >= $0 } ?? false

                let baseColor: Color = isBullish
                    ? Color(red: 0.85, green: 0.1, blue: 0.1)
                    : Color(red: 0.1, green: 0.3, blue: 0.85)
                let color = isAnswer ? baseColor.opacity(0.45) : baseColor

                // 答えパートとの境界線
                if let di = dividerIndex, i == di {
                    let divX = CGFloat(i) * slotWidth
                    context.stroke(
                        Path { p in
                            p.move(to: CGPoint(x: divX, y: 0))
                            p.addLine(to: CGPoint(x: divX, y: size.height))
                        },
                        with: .color(.orange),
                        lineWidth: 1.5
                    )
                }

                // ひげ
                context.stroke(
                    Path { p in
                        p.move(to: CGPoint(x: cx, y: priceY(candle.high)))
                        p.addLine(to: CGPoint(x: cx, y: priceY(candle.low)))
                    },
                    with: .color(color),
                    lineWidth: 1
                )

                // 実体（十字線は横線で描画）
                let isDoji = abs(candle.open - candle.close) < priceScale.range * 0.005
                if isDoji {
                    let dojiY = priceY((candle.open + candle.close) / 2)
                    context.stroke(
                        Path { p in
                            p.move(to: CGPoint(x: cx - bodyWidth / 2, y: dojiY))
                            p.addLine(to: CGPoint(x: cx + bodyWidth / 2, y: dojiY))
                        },
                        with: .color(color),
                        lineWidth: 1.5
                    )
                } else {
                    let bodyTop = min(priceY(candle.open), priceY(candle.close))
                    let bodyH = max(abs(priceY(candle.open) - priceY(candle.close)), 1.5)
                    context.fill(
                        Path(CGRect(x: cx - bodyWidth / 2, y: bodyTop,
                                    width: bodyWidth, height: bodyH)),
                        with: .color(color)
                    )
                }

                if let highlightedPrice, candles.count == 1 {
                    let y = priceY(highlightedPrice)
                    let x = Self.markerX(for: highlightedPrice, in: candle, center: cx, bodyWidth: bodyWidth)
                    let guideEnd = size.width - 5
                    context.stroke(
                        Path { path in
                            path.move(to: CGPoint(x: x, y: y))
                            path.addLine(to: CGPoint(x: guideEnd, y: y))
                        },
                        with: .color(.primary),
                        style: StrokeStyle(lineWidth: 1, dash: [3, 2])
                    )
                    let marker = Path(ellipseIn: CGRect(x: x - 4, y: y - 4, width: 8, height: 8))
                    context.fill(marker, with: .color(Color(uiColor: .systemBackground)))
                    context.stroke(marker, with: .color(.primary), lineWidth: 1.5)
                }

                if showsVolume {
                    let volRatio = CGFloat(candle.volume) / CGFloat(maxVolume)
                    let volBarH = volRatio * volumeHeight * 0.9
                    let volY = size.height - volBarH
                    context.fill(
                        Path(CGRect(x: cx - bodyWidth / 2, y: volY,
                                    width: bodyWidth, height: volBarH)),
                        with: .color(color.opacity(0.55))
                    )
                }
            }
        }
    }

    static func bodyWidth(for slotWidth: CGFloat) -> CGFloat {
        max(slotWidth * 0.6, 2)
    }

    static func markerX(for price: Double, in candle: Candle, center: CGFloat, bodyWidth: CGFloat) -> CGFloat {
        let isWithinBody = price >= min(candle.open, candle.close) && price <= max(candle.open, candle.close)
        let isWickTip = price == candle.high || price == candle.low
        return isWithinBody && !isWickTip ? center + bodyWidth / 2 : center
    }

    struct PriceScale {
        private let upper: Double
        private let height: CGFloat
        let range: Double

        init(low: Double, high: Double, height: CGFloat) {
            let padding = max(high - low, 1) * 0.06
            upper = high + padding
            range = upper - (low - padding)
            self.height = height
        }

        func y(for price: Double) -> CGFloat {
            CGFloat((upper - price) / range) * height
        }
    }
}
