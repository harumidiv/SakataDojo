import AVFoundation
import UIKit

/// The tanuki's babbling "voice": while its commentary types out, each syllable plays a short,
/// high-pitched blip shaped like the character's vowel. The sounds are synthesized here, so no
/// audio files are needed.
@MainActor
final class MascotVoicePlayer {
    static let shared = MascotVoicePlayer()

    /// UserDefaults key for the on/off switch in Settings.
    static let enabledKey = "mascotVoiceEnabled"

    private let playback = Playback()

    private init() {}

    var isEnabled: Bool {
        UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true
    }

    /// Synthesizes the syllable sounds in the background. Call early (at launch) so they're
    /// ready long before the tanuki first talks.
    func preload() {
        Task { await playback.preload() }
    }

    /// Starts the audio engine and warms up the output, so the first syllable isn't late or garbled.
    /// Call when a screen where the tanuki talks appears.
    func prepare() {
        guard isEnabled else { return }
        Task { await playback.start() }
    }

    /// Stops the audio engine when no screen needs the voice, to save power.
    func suspend() {
        Task { await playback.stop() }
    }

    /// Plays one syllable for `character`. Punctuation and spaces stay silent.
    func speak(_ character: Character) {
        guard isEnabled, !UIAccessibility.isVoiceOverRunning, let vowel = Vowel(character) else { return }
        let requestedAt = ContinuousClock.now
        Task { await playback.play(vowel, requestedAt: requestedAt) }
    }

    nonisolated static func isVoiced(_ character: Character) -> Bool {
        Vowel(character) != nil
    }

    // AVAudioEngine may activate the audio session, so it lives off the main actor
    // and is driven serially, like SoundEffectPlayer.
    private actor Playback {
        private let engine = AVAudioEngine()
        private let player = AVAudioPlayerNode()
        private var buffers: [Vowel: [AVAudioPCMBuffer]] = [:]
        private var isLoaded = false
        private var isAttached = false
        /// A syllable that reaches the engine later than this is dropped, so a slow start
        /// doesn't make the queued syllables burst out all at once.
        private let staleAfter = Duration.milliseconds(60)

        func preload() {
            guard !isLoaded,
                  let format = AVAudioFormat(standardFormatWithSampleRate: Syllable.sampleRate, channels: 1) else { return }
            for vowel in Vowel.allCases {
                // A few pitches per vowel so the babble has some melody.
                buffers[vowel] = [0.92, 1.0, 1.06, 1.14].compactMap {
                    Syllable.makeBuffer(vowel: vowel, basePitch: 330 * $0, format: format)
                }
            }
            isLoaded = true
        }

        @discardableResult
        func start() -> Bool {
            preload()
            guard let format = AVAudioFormat(standardFormatWithSampleRate: Syllable.sampleRate, channels: 1) else { return false }
            if !isAttached {
                // Follow the silent switch and keep other apps' music playing.
                try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
                engine.attach(player)
                engine.connect(player, to: engine.mainMixerNode, format: format)
                isAttached = true
            }
            guard !engine.isRunning else { return true }
            // The engine also stops by itself when the app goes to the background or audio is interrupted.
            guard (try? engine.start()) != nil else { return false }
            // Push a moment of silence through so the output path is already running for the first syllable.
            if let silence = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(Syllable.sampleRate * 0.1)) {
                silence.frameLength = silence.frameCapacity
                player.scheduleBuffer(silence, at: nil, options: .interrupts)
            }
            player.play()
            return true
        }

        func stop() {
            guard engine.isRunning else { return }
            player.stop()
            engine.stop()
        }

        func play(_ vowel: Vowel, requestedAt: ContinuousClock.Instant) {
            guard start(), ContinuousClock.now - requestedAt < staleAfter,
                  let buffer = buffers[vowel]?.randomElement() else { return }
            player.scheduleBuffer(buffer, at: nil, options: .interrupts)
            if !player.isPlaying { player.play() }
        }
    }
}

nonisolated enum Vowel: CaseIterable, Sendable {
    case a, i, u, e, o

    /// First and second formant frequencies, raised a little for a small animal's voice.
    var formants: (Double, Double) {
        switch self {
        case .a: (900, 1450)
        case .i: (380, 2600)
        case .u: (420, 1500)
        case .e: (600, 2250)
        case .o: (560, 1000)
        }
    }

    private static let hiraganaRows: [(Vowel, String)] = [
        (.a, "あかさたなはまやらわがざだばぱぁゃゎ"),
        (.i, "いきしちにひみりぎじぢびぴぃゐ"),
        (.u, "うくすつぬふむゆるぐずづぶぷぅゅゔん"),
        (.e, "えけせてねへめれげぜでべぺぇゑ"),
        (.o, "おこそとのほもよろをごぞどぼぽぉょ"),
    ]

    private static let kanaTable: [Character: Vowel] = {
        var table: [Character: Vowel] = [:]
        for (vowel, row) in hiraganaRows {
            for character in row { table[character] = vowel }
        }
        return table
    }()

    /// The vowel to voice for `character`, or nil for characters that should stay silent
    /// (punctuation, spaces, the long-vowel mark and the small っ).
    init?(_ character: Character) {
        guard let scalar = character.unicodeScalars.first else { return nil }
        var hiragana = character
        // Katakana → hiragana (ァ U+30A1 … ヶ U+30F6 sit 0x60 above ぁ … ゖ).
        if (0x30A1...0x30F6).contains(scalar.value), let shifted = Unicode.Scalar(scalar.value - 0x60) {
            hiragana = Character(shifted)
        }
        if let vowel = Self.kanaTable[hiragana] {
            self = vowel
            return
        }
        // Kanji, Latin letters and digits: a fixed but varied vowel per character.
        let isKanji = (0x4E00...0x9FFF).contains(scalar.value) || (0x3400...0x4DBF).contains(scalar.value)
        guard isKanji || character.isLetter || character.isNumber else { return nil }
        self = Self.allCases[Int(scalar.value % UInt32(Self.allCases.count))]
    }
}

/// Formant synthesis of one short syllable: a buzzy pulse train with a falling pitch,
/// shaped by two resonators at the vowel's formants and a quick attack/decay envelope.
nonisolated enum Syllable {
    static let sampleRate = 44_100.0
    private static let duration = 0.075

    static func makeBuffer(vowel: Vowel, basePitch: Double, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let channel = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount

        let (f1, f2) = vowel.formants
        var first = Resonator(frequency: f1, bandwidth: 120, sampleRate: sampleRate)
        var second = Resonator(frequency: f2, bandwidth: 180, sampleRate: sampleRate)
        var phase = 0.0
        var samples = [Double](repeating: 0, count: Int(frameCount))
        var peak = 0.0

        for index in 0..<Int(frameCount) {
            let t = Double(index) / sampleRate
            let progress = t / duration
            // Starts a little high and falls, like a chirpy syllable.
            let pitch = basePitch * (1.12 - 0.22 * progress)
            phase += pitch / sampleRate
            phase -= phase.rounded(.down)
            let source = 2 * phase - 1
            let voiced = first.process(source) + 0.55 * second.process(source)
            let envelope = min(1, t / 0.006) * pow(max(0, 1 - progress), 1.6)
            let value = voiced * envelope
            samples[index] = value
            peak = max(peak, abs(value))
        }

        let gain = peak > 0 ? 0.32 / peak : 0
        for index in 0..<Int(frameCount) {
            channel[index] = Float(samples[index] * gain)
        }
        return buffer
    }

    /// Two-pole band-pass resonator.
    private struct Resonator {
        private let a1: Double
        private let a2: Double
        private let gain: Double
        private var y1 = 0.0
        private var y2 = 0.0

        init(frequency: Double, bandwidth: Double, sampleRate: Double) {
            let r = exp(-Double.pi * bandwidth / sampleRate)
            a1 = -2 * r * cos(2 * Double.pi * frequency / sampleRate)
            a2 = r * r
            gain = 1 - r
        }

        mutating func process(_ x: Double) -> Double {
            let y = gain * x - a1 * y1 - a2 * y2
            y2 = y1
            y1 = y
            return y
        }
    }
}
