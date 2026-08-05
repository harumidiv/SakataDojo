import SwiftUI

struct CandlestickChartView: View {
    let candles: [Candle]
    let dividerIndex: Int?

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

            let priceRange = max(maxPrice - minPrice, 1)
            let pad = priceRange * 0.06
            let priceLow = minPrice - pad
            let priceHigh = maxPrice + pad
            let adjustedRange = priceHigh - priceLow

            let volumeHeight = size.height * 0.2
            let chartHeight = size.height - volumeHeight - 6

            let slotWidth = size.width / CGFloat(candles.count)
            let bodyWidth = max(slotWidth * 0.6, 2)

            func priceY(_ price: Double) -> CGFloat {
                CGFloat((priceHigh - price) / adjustedRange) * chartHeight
            }

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

            // 移動平均線
            drawMA(ma(5),  color: Color(red: 1.0, green: 0.6, blue: 0.0))  // 5日: オレンジ
            drawMA(ma(25), color: Color(red: 0.2, green: 0.7, blue: 0.3))  // 25日: グリーン

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

                // 実体
                let bodyTop = min(priceY(candle.open), priceY(candle.close))
                let bodyH = max(abs(priceY(candle.open) - priceY(candle.close)), 1.5)
                context.fill(
                    Path(CGRect(x: cx - bodyWidth / 2, y: bodyTop,
                                width: bodyWidth, height: bodyH)),
                    with: .color(color)
                )

                // 出来高バー
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
