import AVFoundation

@MainActor
final class SoundEffectPlayer {
    enum Effect: String {
        case correct = "quiz_correct"
        case wrong = "quiz_wrong"
    }

    static let shared = SoundEffectPlayer()

    private var players: [Effect: AVAudioPlayer] = [:]

    private init() {
        // 消音スイッチに従い、他アプリの再生中の音楽も止めない
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])

        for effect in [Effect.correct, .wrong] {
            guard let url = Bundle.main.url(forResource: effect.rawValue, withExtension: "mp3"),
                  let player = try? AVAudioPlayer(contentsOf: url) else { continue }
            player.prepareToPlay()
            players[effect] = player
        }
    }

    /// 初回再生時の読み込み遅延を避けるため、事前に呼んでおく
    func prepare() {}

    func play(_ effect: Effect) {
        guard let player = players[effect] else { return }
        player.currentTime = 0
        player.play()
    }
}
