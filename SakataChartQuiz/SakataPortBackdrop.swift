import SwiftUI

/// The strip the tanuki walks across on the topic picker: the Sakata rice port, where the
/// rice trade that gave rise to the Sakata five methods took place.
/// Sankyo storehouses with their zelkova row, rice bales, a kitamaebune on the Sea of Japan
/// and Mt. Chokai in the distance. Drawn with Canvas so it fits any width and both appearances.
struct SakataPortBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    /// Extra sky drawn above the scene that fades out to transparent, so the strip
    /// blends into the content above instead of ending in a hard edge.
    var skyFade: CGFloat = 0

    var body: some View {
        let palette = Palette(dark: colorScheme == .dark)

        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion || scenePhase != .active)) { timeline in
            let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            scene(palette: palette, time: time)
        }
        // Mask the full, taller drawing first; the negative padding then lets it rise above the strip.
        .mask {
            GeometryReader { geometry in
                let fadeEnd = geometry.size.height > 0 ? skyFade / geometry.size.height : 0
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black.opacity(0.55), location: fadeEnd * 0.6),
                        .init(color: .black, location: fadeEnd),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .padding(.top, -skyFade)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func scene(palette: Palette, time: TimeInterval) -> some View {
        Canvas { context, size in
            let w = size.width
            let fade = min(skyFade, size.height)
            let h = size.height - fade
            let horizon = h * 0.40
            let shore = h * 0.60

            // Sky, including the fading extension above the scene
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .linearGradient(
                    Gradient(colors: [palette.skyTop, palette.skyBottom]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: 0, y: fade + horizon)
                )
            )
            // Everything else is laid out in the scene's own coordinates below the fade.
            context.translateBy(x: 0, y: fade)

            // Mt. Chokai, snow-capped, beyond the sea
            let peak = CGPoint(x: w * 0.74, y: h * 0.10)
            var mountain = Path()
            mountain.move(to: CGPoint(x: w * 0.50, y: horizon))
            mountain.addQuadCurve(to: peak, control: CGPoint(x: w * 0.66, y: h * 0.16))
            mountain.addQuadCurve(to: CGPoint(x: w * 1.02, y: horizon), control: CGPoint(x: w * 0.84, y: h * 0.14))
            mountain.closeSubpath()
            context.fill(mountain, with: .color(palette.mountain))
            // Snow cap: a jagged band clipped to the mountain's outline
            var snow = Path()
            snow.move(to: CGPoint(x: peak.x - 40, y: 0))
            snow.addLine(to: CGPoint(x: peak.x + 40, y: 0))
            snow.addLine(to: CGPoint(x: peak.x + 40, y: peak.y + 5))
            for (dx, dy) in [(24.0, 7.0), (14.0, 4.0), (6.0, 8.0), (-3.0, 4.5), (-11.0, 7.5), (-20.0, 4.0), (-40.0, 5.0)] {
                snow.addLine(to: CGPoint(x: peak.x + dx, y: peak.y + dy))
            }
            snow.closeSubpath()
            var snowLayer = context
            snowLayer.clip(to: mountain)
            snowLayer.fill(snow, with: .color(palette.snow))

            // Sea of Japan
            context.fill(Path(CGRect(x: 0, y: horizon, width: w, height: shore - horizon)), with: .color(palette.sea))
            for row in 0..<2 {
                let y = horizon + (shore - horizon) * (0.35 + 0.35 * CGFloat(row))
                var waves = Path()
                var x = CGFloat(row) * 9 + 4
                while x < w {
                    waves.move(to: CGPoint(x: x, y: y))
                    waves.addQuadCurve(to: CGPoint(x: x + 8, y: y), control: CGPoint(x: x + 4, y: y - 2.5))
                    x += 22
                }
                context.stroke(waves, with: .color(palette.wave), lineWidth: 1)
            }

            // Kitamaebune carrying rice out of the port
            // rolling gently on the swell
            let swell = time * 2 * .pi / 3.6
            let shipBase = CGPoint(x: w * 0.86, y: horizon + (shore - horizon) * 0.62 + 1.2 * sin(swell))
            var shipLayer = context
            shipLayer.translateBy(x: shipBase.x, y: shipBase.y)
            shipLayer.rotate(by: .degrees(2.5 * sin(swell - 0.9)))
            drawShip(in: &shipLayer, at: .zero, palette: palette)

            // Ground
            context.fill(Path(CGRect(x: 0, y: shore, width: w, height: h - shore)), with: .color(palette.ground))
            context.fill(Path(CGRect(x: 0, y: shore, width: w, height: 1.5)), with: .color(palette.groundEdge))

            // Sankyo storehouses with the zelkova row behind them
            let houseWidth: CGFloat = min(44, w * 0.12)
            let firstHouseX = w * 0.04
            let houseCount = 3
            for index in 0...houseCount {
                let tree = CGRect(
                    x: firstHouseX + (CGFloat(index) - 0.35) * houseWidth,
                    y: shore - 40,
                    width: houseWidth * 0.95,
                    height: 32
                )
                context.fill(Path(ellipseIn: tree), with: .color(palette.tree))
            }
            for index in 0..<houseCount {
                drawStorehouse(
                    in: &context,
                    frame: CGRect(x: firstHouseX + CGFloat(index) * houseWidth, y: shore - 20, width: houseWidth, height: 20),
                    palette: palette
                )
            }

            // Rice bales stacked on the quay
            let baleWidth: CGFloat = 20
            let baleHeight: CGFloat = 12
            let stackX = w * 0.52
            let baleBase = shore + 12
            for (column, row) in [(0.0, 0), (1.0, 0), (2.0, 0), (0.5, 1), (1.5, 1), (1.0, 2)] {
                let rect = CGRect(
                    x: stackX + CGFloat(column) * (baleWidth + 1),
                    y: baleBase - baleHeight * CGFloat(row + 1) + CGFloat(row) * 1.5,
                    width: baleWidth,
                    height: baleHeight
                )
                drawBale(in: &context, rect: rect, palette: palette)
            }
            drawBale(in: &context, rect: CGRect(x: w * 0.36, y: shore + 4, width: baleWidth, height: baleHeight), palette: palette)
            drawBale(in: &context, rect: CGRect(x: w * 0.92, y: shore + 6, width: baleWidth, height: baleHeight), palette: palette)
        }
    }

    private func drawStorehouse(in context: inout GraphicsContext, frame: CGRect, palette: Palette) {
        let wallTop = frame.minY + frame.height * 0.38
        let wall = CGRect(x: frame.minX, y: wallTop, width: frame.width, height: frame.maxY - wallTop)
        context.fill(Path(wall), with: .color(palette.wall))
        // Lower wainscot of dark wood
        context.fill(Path(CGRect(x: wall.minX, y: wall.maxY - 4, width: wall.width, height: 4)), with: .color(palette.roof.opacity(0.75)))
        // Door
        context.fill(Path(CGRect(x: wall.midX - 3.5, y: wall.maxY - 9, width: 7, height: 9)), with: .color(palette.roof))

        // Gabled roof with the characteristic overhang (seen from the long side)
        var roof = Path()
        roof.move(to: CGPoint(x: frame.minX - 1, y: wallTop + 1))
        roof.addLine(to: CGPoint(x: frame.minX + frame.width * 0.12, y: frame.minY))
        roof.addLine(to: CGPoint(x: frame.maxX - frame.width * 0.12, y: frame.minY))
        roof.addLine(to: CGPoint(x: frame.maxX + 1, y: wallTop + 1))
        roof.closeSubpath()
        context.fill(roof, with: .color(palette.roof))
        context.stroke(
            Path { $0.move(to: CGPoint(x: frame.minX + frame.width * 0.12, y: frame.minY)); $0.addLine(to: CGPoint(x: frame.maxX - frame.width * 0.12, y: frame.minY)) },
            with: .color(palette.roofRidge),
            lineWidth: 1.5
        )
    }

    private func drawBale(in context: inout GraphicsContext, rect: CGRect, palette: Palette) {
        let body = Path(roundedRect: rect, cornerRadius: rect.height / 2)
        context.fill(body, with: .color(palette.straw))
        // Straw lid (sandawara) on the visible end
        let lid = CGRect(x: rect.maxX - rect.height * 0.55, y: rect.minY + 0.5, width: rect.height * 0.55, height: rect.height - 1)
        context.fill(Path(ellipseIn: lid), with: .color(palette.strawShade))
        // Rope bands
        for fraction in [0.3, 0.55] {
            let x = rect.minX + rect.width * fraction
            context.stroke(
                Path { $0.move(to: CGPoint(x: x, y: rect.minY + 1)); $0.addLine(to: CGPoint(x: x, y: rect.maxY - 1)) },
                with: .color(palette.rope),
                lineWidth: 1.2
            )
        }
        context.stroke(body, with: .color(palette.rope), lineWidth: 1)
    }

    private func drawShip(in context: inout GraphicsContext, at base: CGPoint, palette: Palette) {
        var hull = Path()
        hull.move(to: CGPoint(x: base.x - 16, y: base.y - 4))
        hull.addLine(to: CGPoint(x: base.x + 18, y: base.y - 5))
        hull.addQuadCurve(to: CGPoint(x: base.x + 10, y: base.y + 1), control: CGPoint(x: base.x + 16, y: base.y + 1))
        hull.addLine(to: CGPoint(x: base.x - 12, y: base.y + 1))
        hull.closeSubpath()
        context.fill(hull, with: .color(palette.hull))
        // Mast and the single large square sail
        context.stroke(
            Path { $0.move(to: CGPoint(x: base.x, y: base.y - 4)); $0.addLine(to: CGPoint(x: base.x, y: base.y - 26)) },
            with: .color(palette.hull),
            lineWidth: 1.2
        )
        let sail = CGRect(x: base.x - 9, y: base.y - 24, width: 18, height: 16)
        context.fill(Path(roundedRect: sail, cornerRadius: 1.5), with: .color(palette.sail))
        for index in 1..<4 {
            let x = sail.minX + sail.width * CGFloat(index) / 4
            context.stroke(
                Path { $0.move(to: CGPoint(x: x, y: sail.minY)); $0.addLine(to: CGPoint(x: x, y: sail.maxY)) },
                with: .color(palette.sailSeam),
                lineWidth: 0.6
            )
        }
    }

    fileprivate struct Palette {
        let skyTop, skyBottom, mountain, snow, sea, wave, ground, groundEdge: Color
        let tree, wall, roof, roofRidge, straw, strawShade, rope, hull, sail, sailSeam: Color

        init(dark: Bool) {
            if dark {
                skyTop = Color(red: 0.11, green: 0.14, blue: 0.21)
                skyBottom = Color(red: 0.19, green: 0.21, blue: 0.28)
                mountain = Color(red: 0.24, green: 0.27, blue: 0.35)
                snow = Color(red: 0.62, green: 0.66, blue: 0.74)
                sea = Color(red: 0.14, green: 0.24, blue: 0.34)
                wave = Color(red: 0.32, green: 0.45, blue: 0.56)
                ground = Color(red: 0.25, green: 0.22, blue: 0.18)
                groundEdge = Color(red: 0.33, green: 0.29, blue: 0.23)
                tree = Color(red: 0.16, green: 0.27, blue: 0.19)
                wall = Color(red: 0.70, green: 0.67, blue: 0.60)
                roof = Color(red: 0.13, green: 0.12, blue: 0.13)
                roofRidge = Color(red: 0.30, green: 0.28, blue: 0.29)
                straw = Color(red: 0.66, green: 0.55, blue: 0.32)
                strawShade = Color(red: 0.55, green: 0.45, blue: 0.25)
                rope = Color(red: 0.36, green: 0.27, blue: 0.14)
                hull = Color(red: 0.35, green: 0.24, blue: 0.16)
                sail = Color(red: 0.72, green: 0.70, blue: 0.64)
                sailSeam = Color(red: 0.50, green: 0.48, blue: 0.44)
            } else {
                skyTop = Color(red: 0.83, green: 0.91, blue: 0.96)
                skyBottom = Color(red: 0.96, green: 0.94, blue: 0.87)
                mountain = Color(red: 0.62, green: 0.70, blue: 0.80)
                snow = Color.white
                sea = Color(red: 0.55, green: 0.73, blue: 0.84)
                wave = Color.white.opacity(0.75)
                ground = Color(red: 0.91, green: 0.84, blue: 0.68)
                groundEdge = Color(red: 0.80, green: 0.71, blue: 0.52)
                tree = Color(red: 0.42, green: 0.60, blue: 0.40)
                wall = Color(red: 0.98, green: 0.97, blue: 0.93)
                roof = Color(red: 0.25, green: 0.23, blue: 0.24)
                roofRidge = Color(red: 0.42, green: 0.40, blue: 0.40)
                straw = Color(red: 0.89, green: 0.77, blue: 0.47)
                strawShade = Color(red: 0.80, green: 0.66, blue: 0.36)
                rope = Color(red: 0.55, green: 0.42, blue: 0.22)
                hull = Color(red: 0.45, green: 0.31, blue: 0.20)
                sail = Color.white
                sailSeam = Color(red: 0.78, green: 0.76, blue: 0.72)
            }
        }
    }
}

/// The quay's ground on its own, to carry the port scene on below the strip
/// (behind the banner and into the bottom safe area).
struct SakataPortGround: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let palette = SakataPortBackdrop.Palette(dark: colorScheme == .dark)
        palette.ground
            .accessibilityHidden(true)
    }
}

#Preview("Sakata port") {
    SakataPortBackdrop()
        .frame(height: 84)
}

#Preview("Walking tanuki on the port") {
    VStack {
        Spacer()
        TopicPickerMascot()
    }
}

#Preview("Tanuki talking") {
    List(0..<20) { Text("テーマ \($0)") }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            // Mirrors the topic picker's bottom: strip, banner slot, ground into the safe area.
            VStack(spacing: 0) {
                TopicPickerMascot(footDrop: CandlestickBasicsBanner.topPadding, talkingAfter: 3)
                    .zIndex(1)
                CandlestickBasicsBanner(loadsAd: false, showsBarBackground: false)
                    .overlay { Rectangle().fill(.gray.opacity(0.4)).frame(width: 320, height: 50).padding(.top, CandlestickBasicsBanner.topPadding) }
            }
            .background { SakataPortGround().ignoresSafeArea() }
        }
}
