import SwiftUI

enum BasicsMascotMood: Equatable {
    case idle
    case walking
    case explaining
    case thinking
    case celebrating

    var frames: [BasicsMascotFrame] {
        switch self {
        case .idle:
            [.smile, .smile, .smile, .smile, .smile, .blink, .smile, .smile, .smile, .smile]
        case .walking:
            [.walk01, .walk02, .walk03, .walk04, .walk05, .walk06, .walk07, .walk08]
        case .explaining:
            [.teachingSmile, .teach, .teachWide, .teach, .teachingSmile, .talk, .smile, .smile, .talk]
        case .thinking:
            [.ponder, .ponder, .ponderTalk, .ponder, .ponderTalk, .ponder, .ponder]
        case .celebrating:
            [.wave, .cheer, .cheer, .wave, .wave, .smile, .smile, .smile]
        }
    }
}

struct TopicPickerMascot: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var startedAt = Date.now
    /// Walking time at the moment the tanuki was tapped; non-nil while it stands still and talks.
    @State private var pausedElapsed: TimeInterval?

    private static let sceneHeight: CGFloat = 84
    private static let sceneInset: CGFloat = 16
    private static let spriteSize: CGFloat = 64
    /// Points per second; about one stride per walk cycle.
    private static let walkingSpeed = 42.0
    /// Without a banner below, the tanuki walks on the near edge of the ground, this far above the scene's bottom.
    private static let footFromBottom: CGFloat = 5
    /// Distance from the top of the 64pt sprite to the soles of its feet.
    private static let footInSprite: CGFloat = 61
    /// Distance from the top of the sprite to the top of the tanuki's ears.
    private static let headInSprite: CGFloat = 4
    private static let bubbleMaxWidth: CGFloat = 260
    /// How far the sky keeps going above the strip while fading out.
    private static let skyFade: CGFloat = 64

    private var isTalking: Bool { pausedElapsed != nil }

    /// How far below the strip the tanuki's feet land, e.g. on the top edge of the banner ad under it.
    private let footDrop: CGFloat

    /// - Parameters:
    ///   - footDrop: Distance below the strip's bottom edge to walk on. When 0, the tanuki walks inside the strip.
    ///   - talkingAfter: Starts the strip already stopped and talking at this point of the walk (for previews).
    init(footDrop: CGFloat = 0, talkingAfter: TimeInterval? = nil) {
        self.footDrop = footDrop
        _pausedElapsed = State(initialValue: talkingAfter)
    }

    var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation(minimumInterval: 0.05, paused: isTalking || reduceMotion || scenePhase != .active)) { timeline in
                let width = geometry.size.width
                let elapsed = pausedElapsed ?? max(0, timeline.date.timeIntervalSince(startedAt))
                let walk = walkState(elapsed: elapsed, width: width)
                let footY = footDrop > 0 ? Self.sceneHeight + footDrop : Self.sceneHeight - Self.footFromBottom
                let spriteTop = footY - Self.footInSprite
                let headX = walk.x + Self.spriteSize / 2

                Button(action: toggleTalking) {
                    BasicsMascotAnimation(mood: isTalking ? .explaining : .walking)
                        .id(isTalking)
                        .frame(width: Self.spriteSize, height: Self.spriteSize)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isTalking ? "たぬきの案内をとじる" : "たぬきの案内を聞く")
                .scaleEffect(x: isTalking || walk.isWalkingRight ? 1 : -1)
                .offset(x: walk.x, y: spriteTop)
                .frame(width: width, height: Self.sceneHeight, alignment: .topLeading)
                // An overlay doesn't take part in layout, so the bubble can rise above the strip.
                .overlay(alignment: .topLeading) {
                    // A clear box from the strip's top down to the tanuki's head; the bubble's bottom
                    // sits on its bottom edge and the bubble grows upward past the strip.
                    Color.clear
                        .frame(width: width, height: spriteTop + Self.headInSprite)
                        .overlay(alignment: .bottomLeading) {
                            if isTalking {
                                let bubbleWidth = min(Self.bubbleMaxWidth, width - 16)
                                let bubbleX = min(max(8, headX - bubbleWidth / 2), width - bubbleWidth - 8)
                                TopicPickerSpeechBubble(width: bubbleWidth, tailX: headX - bubbleX, onClose: toggleTalking)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .offset(x: bubbleX)
                                    .transition(.scale(scale: 0.6, anchor: .bottom).combined(with: .opacity))
                            }
                        }
                }
            }
        }
        .frame(height: Self.sceneHeight)
        .frame(maxWidth: .infinity)
        .background(alignment: .bottom) { SakataPortBackdrop(skyFade: Self.skyFade) }
    }

    private func walkState(elapsed: TimeInterval, width: CGFloat) -> (x: CGFloat, isWalkingRight: Bool) {
        let travelDistance = max(0, width - Self.spriteSize - Self.sceneInset * 2)
        guard !reduceMotion else { return (Self.sceneInset, true) }
        // Keep a steady walking pace however wide the screen is.
        let secondsPerDirection = max(6.0, Double(travelDistance) / Self.walkingSpeed)
        let phase = elapsed.truncatingRemainder(dividingBy: secondsPerDirection * 2)
        let isWalkingRight = phase < secondsPerDirection
        let progress = isWalkingRight ? phase / secondsPerDirection : (secondsPerDirection * 2 - phase) / secondsPerDirection
        return (Self.sceneInset + travelDistance * CGFloat(progress), isWalkingRight)
    }

    private func toggleTalking() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            if let pausedElapsed {
                // Resume walking from the spot where the tanuki stopped.
                startedAt = Date.now.addingTimeInterval(-pausedElapsed)
                self.pausedElapsed = nil
            } else {
                pausedElapsed = max(0, Date.now.timeIntervalSince(startedAt))
            }
        }
    }
}

private struct TopicPickerSpeechBubble: View {
    let width: CGFloat
    /// Horizontal position of the tail tip, measured from the bubble's leading edge.
    let tailX: CGFloat
    let onClose: () -> Void

    private let tailHeight: CGFloat = 8
    private let cornerRadius: CGFloat = 12

    var body: some View {
        Button(action: onClose) {
            VStack(alignment: .leading, spacing: 6) {
                TypingText(text: String(localized: "今日の米相場は……ん？\nちょうどいい、相場の読み方を教えてあげよう"))
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Label("とじる", systemImage: "hand.tap")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .multilineTextAlignment(.leading)
            .padding(12)
            .frame(width: width, alignment: .leading)
            .background {
                let clampedTail = min(max(tailX, cornerRadius + 8), width - cornerRadius - 8)
                BubbleShape(cornerRadius: cornerRadius, tailX: clampedTail, tailHeight: tailHeight)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                    .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
                    .padding(.bottom, -tailHeight)
            }
            .padding(.bottom, tailHeight)
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("タップでとじる"))
    }
}

private struct BubbleShape: Shape {
    let cornerRadius: CGFloat
    let tailX: CGFloat
    let tailHeight: CGFloat

    func path(in rect: CGRect) -> Path {
        let body = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height - tailHeight)
        var path = Path(roundedRect: body, cornerRadius: cornerRadius)
        var tail = Path()
        tail.move(to: CGPoint(x: rect.minX + tailX - 8, y: body.maxY - 0.5))
        tail.addLine(to: CGPoint(x: rect.minX + tailX, y: rect.maxY))
        tail.addLine(to: CGPoint(x: rect.minX + tailX + 8, y: body.maxY - 0.5))
        tail.closeSubpath()
        path.addPath(tail)
        return path
    }
}

enum BasicsMascotFrame: String {
    case smile = "BasicsMascot01"
    case talk = "BasicsMascot02"
    case teach = "BasicsMascot03"
    case teachWide = "BasicsMascot04"
    case teachingSmile = "BasicsMascot05"
    case blink = "BasicsMascot06"
    case ponder = "BasicsMascot07"
    case ponderTalk = "BasicsMascot08"
    case wave = "BasicsMascot09"
    case cheer = "BasicsMascot10"
    case walk01 = "BasicsMascotWalk01"
    case walk02 = "BasicsMascotWalk02"
    case walk03 = "BasicsMascotWalk03"
    case walk04 = "BasicsMascotWalk04"
    case walk05 = "BasicsMascotWalk05"
    case walk06 = "BasicsMascotWalk06"
    case walk07 = "BasicsMascotWalk07"
    case walk08 = "BasicsMascotWalk08"
}

struct BasicsMascotMessage<Message: View>: View {
    let mood: BasicsMascotMood
    var fill: Color = Color.secondary.opacity(0.08)
    var onTap: (() -> Void)? = nil
    var tapLabel: LocalizedStringResource = "タップでつづき"
    @ViewBuilder let message: () -> Message

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private static var cornerRadius: CGFloat { 12 }
    /// How far the bubble is raised above the bottom of the mascot sprite.
    private static var bubbleLift: CGFloat { 10 }
    /// The tanuki's mouth in the 64pt sprite (about 43% down from the top).
    private static var mouthAboveSpriteBottom: CGFloat { 36 }

    var body: some View {
        let useVerticalLayout = dynamicTypeSize.isAccessibilitySize
        let layout = useVerticalLayout
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .bottom, spacing: 12))

        layout {
            BasicsMascotAnimation(mood: mood)
                .id(mood)

            VStack(alignment: .leading, spacing: 6, content: message)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .padding(.bottom, onTap == nil ? 0 : 14)
                .background(fill, in: RoundedRectangle(cornerRadius: Self.cornerRadius))
                .background {
                    if !useVerticalLayout {
                        GeometryReader { geometry in
                            // Point the tail at the tanuki's mouth. The bubble's bottom sits
                            // `bubbleLift` above the sprite's bottom, so the mouth is this far up from it.
                            let mouthAboveBubbleBottom = Self.mouthAboveSpriteBottom - Self.bubbleLift
                            // Keep the tail on the straight part of the edge, clear of the rounded corner.
                            let tailY = max(Self.cornerRadius + 6, geometry.size.height - mouthAboveBubbleBottom)
                            Path { path in
                                path.move(to: CGPoint(x: 8, y: 0))
                                path.addLine(to: CGPoint(x: 0, y: 6))
                                path.addLine(to: CGPoint(x: 8, y: 12))
                                path.closeSubpath()
                            }
                            .fill(fill)
                            .frame(width: 8, height: 12)
                            .position(x: -4, y: tailY)
                        }
                        .accessibilityHidden(true)
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    if onTap != nil {
                        Label(tapLabel, systemImage: "hand.tap")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(8)
                    }
                }
                .offset(y: -Self.bubbleLift)
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
        .accessibilityAddTraits(onTap == nil ? [] : .isButton)
        .accessibilityHint(onTap == nil ? "" : String(localized: tapLabel))
    }
}

struct TypingText: View {
    let text: String
    /// Plays the tanuki's babbling voice while the text types out.
    var speaksAloud = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startedAt = Date.now
    @State private var isTyping = true

    private let characterInterval = 0.035
    /// One syllable for every this many voiced characters, so the babble isn't a buzz.
    private let charactersPerSyllable = 2

    var body: some View {
        TimelineView(.animation(minimumInterval: characterInterval, paused: reduceMotion || !isTyping)) { timeline in
            let characters = Array(text)
            let elapsed = max(0, timeline.date.timeIntervalSince(startedAt))
            let visibleCount = reduceMotion
                ? characters.count
                : min(characters.count, Int(elapsed / characterInterval))

            // The full text, hidden, keeps the height fixed so the layout doesn't grow line by line.
            Text(text)
                .hidden()
                .overlay(alignment: .topLeading) {
                    Text(String(characters.prefix(visibleCount)))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: text))
        }
        .task(id: text) {
            startedAt = .now
            isTyping = !reduceMotion
            guard !reduceMotion else { return }

            let start = ContinuousClock.now
            var voicedCount = 0
            for (index, character) in text.enumerated() {
                if speaksAloud, MascotVoicePlayer.isVoiced(character) {
                    if voicedCount % charactersPerSyllable == 0 {
                        MascotVoicePlayer.shared.speak(character)
                    }
                    voicedCount += 1
                }
                do {
                    try await Task.sleep(until: start + .seconds(Double(index + 1) * characterInterval), clock: .continuous)
                } catch {
                    return
                }
            }
            isTyping = false
        }
    }
}

struct BasicsMascotAnimation: View {
    let mood: BasicsMascotMood

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var startedAt = Date.now

    var body: some View {
        let frames = mood.frames
        let frameDuration = mood == .walking ? 0.1 : 0.17
        let isPaused = reduceMotion || scenePhase != .active

        TimelineView(.animation(minimumInterval: frameDuration, paused: isPaused)) { timeline in
            let elapsed = max(0, timeline.date.timeIntervalSince(startedAt))
            let index = isPaused ? 0 : Int(elapsed / frameDuration) % frames.count

            Image(frames[index].rawValue)
                .resizable()
                .scaledToFit()
        }
        .frame(width: 64, height: 64)
        .accessibilityHidden(true)
    }
}

#Preview("Mascot message tail") {
    VStack(spacing: 24) {
        BasicsMascotMessage(mood: .idle) {
            Text("ヒント")
        }
        BasicsMascotMessage(mood: .explaining, onTap: {}) {
            Text("陽線は、始値より終値が高いローソク足だよ。実体の上と下に出ている細い線が「ひげ」なんだ。")
        }
    }
    .padding(20)
}
