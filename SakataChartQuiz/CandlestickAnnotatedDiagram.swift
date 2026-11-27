import SwiftUI

struct CandlestickAnnotatedDiagram: View {
    enum Style {
        case prices
        case parts
    }

    let sample: BasicsSample
    let style: Style

    @ScaledMetric(relativeTo: .subheadline) private var rowHeight: CGFloat = 34
    private let chartWidth: CGFloat = 76
    private let plotInset: CGFloat = 12

    var body: some View {
        let candle = sample.candle
        let annotations = annotations(for: candle)

        HStack(spacing: 0) {
            Color.clear.frame(minWidth: 0, maxWidth: .infinity)
                .accessibilityHidden(true)
            Color.clear.frame(width: chartWidth + 28)
                .accessibilityHidden(true)

            VStack(spacing: 4) {
                ForEach(annotations) { annotation in
                    annotationLabel(annotation, candle: candle)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, minHeight: rowHeight, alignment: .leading)
                        .anchorPreference(key: LabelAnchors.self, value: .bounds) {
                            [annotation.choice: $0]
                        }
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        }
        .background {
            CandlestickChartView(
                candles: [candle], dividerIndex: nil,
                showsVolume: false, showsMovingAverages: false
            )
            .frame(width: chartWidth)
            .padding(.vertical, plotInset)
            .accessibilityHidden(true)
        }
        .overlayPreferenceValue(LabelAnchors.self) { anchors in
            GeometryReader { geometry in
                Canvas { context, size in
                    let scale = CandlestickChartView.PriceScale(
                        low: candle.low, high: candle.high, height: size.height - 2 * plotInset
                    )
                    let center = size.width / 2
                    let bodyWidth = CandlestickChartView.bodyWidth(for: chartWidth)
                    let elbow = center + chartWidth / 2

                    for annotation in annotations {
                        guard let anchor = anchors[annotation.choice] else { continue }
                        let label = geometry[anchor]
                        let price = annotation.point.price(in: candle)
                        let x = CandlestickChartView.markerX(
                            for: price, in: candle, center: center, bodyWidth: bodyWidth
                        )
                        let y = plotInset + scale.y(for: price)
                        let arrow = Path { path in
                            path.move(to: CGPoint(x: label.minX - 7, y: label.midY))
                            path.addLine(to: CGPoint(x: elbow, y: label.midY))
                            path.addLine(to: CGPoint(x: x + 9, y: y))
                            path.addLine(to: CGPoint(x: x, y: y))
                            path.move(to: CGPoint(x: x + 6, y: y - 4))
                            path.addLine(to: CGPoint(x: x, y: y))
                            path.addLine(to: CGPoint(x: x + 6, y: y + 4))
                        }
                        context.stroke(
                            arrow, with: .color(.secondary),
                            style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
                        )
                    }
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .padding(16)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
    }

    private func annotations(for candle: Candle) -> [Annotation] {
        switch style {
        case .prices:
            let rises = candle.close > candle.open
            return [
                Annotation(choice: .high, point: .high),
                Annotation(choice: rises ? .close : .open, point: .bodyTop),
                Annotation(choice: rises ? .open : .close, point: .bodyBottom),
                Annotation(choice: .low, point: .low)
            ]
        case .parts:
            return [
                Annotation(choice: .upperWick, point: .upperWick),
                Annotation(choice: .body, point: .bodyMiddle),
                Annotation(choice: .lowerWick, point: .lowerWick)
            ]
        }
    }

    private func annotationLabel(_ annotation: Annotation, candle: Candle) -> Text {
        let name = Text(annotation.choice.title).fontWeight(.semibold)
        guard style == .prices else { return name }

        let value = Text(annotation.point.price(in: candle), format: .number)
            .foregroundStyle(.secondary)
            .monospacedDigit()

        return Text("\(name)  \(value)")
    }

    private struct Annotation: Identifiable {
        let choice: BasicsChoice
        let point: BasicsPoint

        var id: BasicsChoice { choice }
    }

    private struct LabelAnchors: PreferenceKey {
        static let defaultValue: [BasicsChoice: Anchor<CGRect>] = [:]

        static func reduce(
            value: inout [BasicsChoice: Anchor<CGRect>],
            nextValue: () -> [BasicsChoice: Anchor<CGRect>]
        ) {
            value.merge(nextValue(), uniquingKeysWith: { _, latest in latest })
        }
    }
}
