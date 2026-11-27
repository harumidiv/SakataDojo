import SwiftUI

enum BasicsMascotMood {
    case idle
    case explaining
    case thinking
    case celebrating

    var frames: [BasicsMascotFrame] {
        switch self {
        case .idle:
            [.smile, .smile, .smile, .smile, .smile, .blink, .smile, .smile, .smile, .smile]
        case .explaining:
            [.teachingSmile, .teach, .teachWide, .teach, .teachingSmile, .talk, .smile, .smile, .talk]
        case .thinking:
            [.ponder, .ponder, .ponderTalk, .ponder, .ponderTalk, .ponder, .ponder]
        case .celebrating:
            [.wave, .cheer, .cheer, .wave, .wave, .smile, .smile, .smile]
        }
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
}

struct BasicsMascotMessage<Message: View>: View {
    let mood: BasicsMascotMood
    var fill: Color = Color.secondary.opacity(0.08)
    var onTap: (() -> Void)? = nil
    var tapLabel: LocalizedStringResource = "タップでつづき"
    @ViewBuilder let message: () -> Message

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
                .background(fill, in: RoundedRectangle(cornerRadius: 12))
                .background(alignment: .bottomLeading) {
                    if !useVerticalLayout {
                        Path { path in
                            path.move(to: CGPoint(x: 8, y: 0))
                            path.addLine(to: CGPoint(x: 0, y: 6))
                            path.addLine(to: CGPoint(x: 8, y: 12))
                            path.closeSubpath()
                        }
                        .fill(fill)
                        .frame(width: 8, height: 12)
                        .offset(x: -8, y: -4)
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
                .offset(y: -10)
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
        .accessibilityAddTraits(onTap == nil ? [] : .isButton)
        .accessibilityHint(onTap == nil ? "" : String(localized: tapLabel))
    }
}

struct TypingText: View {
    let text: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startedAt = Date.now
    @State private var isTyping = true

    private let characterInterval = 0.035

    var body: some View {
        TimelineView(.animation(minimumInterval: characterInterval, paused: reduceMotion || !isTyping)) { timeline in
            let characters = Array(text)
            let elapsed = max(0, timeline.date.timeIntervalSince(startedAt))
            let visibleCount = reduceMotion
                ? characters.count
                : min(characters.count, Int(elapsed / characterInterval))

            Text(String(characters.prefix(visibleCount)))
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel(Text(verbatim: text))
        }
        .task(id: text) {
            startedAt = .now
            isTyping = !reduceMotion
            guard !reduceMotion else { return }
            do {
                try await Task.sleep(for: .seconds(Double(Array(text).count) * characterInterval))
            } catch {
                return
            }
            isTyping = false
        }
    }
}

private struct BasicsMascotAnimation: View {
    let mood: BasicsMascotMood

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var startedAt = Date.now

    var body: some View {
        let frames = mood.frames
        let frameDuration = 0.17
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
