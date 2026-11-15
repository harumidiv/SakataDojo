import AVFoundation

@MainActor
final class SoundEffectPlayer {
    enum Effect: String, Sendable {
        case correct = "quiz_correct"
        case wrong = "quiz_wrong"
    }

    static let shared = SoundEffectPlayer()

    private let playback = Playback()

    private init() {}

    /// 初回再生時の読み込み遅延を避けるため、事前に呼んでおく
    func prepare() {
        Task {
            await playback.prepare()
        }
    }

    func play(_ effect: Effect) {
        Task {
            await playback.play(effect)
        }
    }

    // prepareToPlay() と play() は音声セッションを有効化することがあるため、
    // プレイヤーの生成・操作を MainActor から分離し、直列に実行する。
    private actor Playback {
        private var players: [Effect: AVAudioPlayer] = [:]
        private var isPrepared = false

        func prepare() {
            guard !isPrepared else { return }
            // 消音スイッチに従い、他アプリの再生中の音楽も止めない
            try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])

            for effect in [Effect.correct, .wrong] {
                guard let url = Bundle.main.url(forResource: effect.rawValue, withExtension: "mp3"),
                      let player = try? AVAudioPlayer(contentsOf: url) else { continue }
                player.prepareToPlay()
                players[effect] = player
            }
            isPrepared = true
        }

        func play(_ effect: Effect) {
            prepare()
            guard let player = players[effect] else { return }
            player.currentTime = 0
            player.play()
        }
    }
}
