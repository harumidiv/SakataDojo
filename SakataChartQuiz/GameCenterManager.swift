import Combine
import GameKit
import UIKit

/// Game Center のサインインとランキングへの記録送信をまとめて扱う。
/// Game Center を使わない人でもアプリの機能はすべて今まで通り使えるようにする。
@MainActor
final class GameCenterManager: ObservableObject {
    /// App Store Connect で作成するランキングのID（ここと完全に一致させること）
    enum Leaderboard {
        /// 最高連続正解（通常クイズ・デイリー共通の自己ベスト）
        static let bestStreak = "sakatadojo.leaderboard.bestStreak"
        /// デイリーチャレンジの最長連続日数
        static let dailyBestStreak = "sakatadojo.leaderboard.dailyBestStreak"
    }

    @Published private(set) var isAuthenticated = false

    /// 未サインイン時に GameKit から渡されるサインイン画面。起動直後には出さず、ランキングを開こうとしたときに出す
    private var signInViewController: UIViewController?
    private var hasStartedAuthentication = false
    /// サインイン前に送ろうとした記録。サインインできた時点でまとめて送る
    private var pendingScores: [String: Int] = [:]

    func authenticate() {
        guard !hasStartedAuthentication else { return }
        hasStartedAuthentication = true

        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    print("Game Center authentication failed: \(error.localizedDescription)")
                }
                self.signInViewController = viewController
                self.isAuthenticated = GKLocalPlayer.local.isAuthenticated
                if self.isAuthenticated {
                    self.submitPendingScores()
                }
            }
        }
    }

    /// 自己ベストを送る。Game Center 側で最高値だけが残るので、同じ値を何度送っても問題ない
    func submit(_ score: Int, to leaderboardID: String) {
        guard score > 0 else { return }
        pendingScores[leaderboardID] = max(pendingScores[leaderboardID] ?? 0, score)
        if isAuthenticated {
            submitPendingScores()
        }
    }

    /// ランキングを表示する。サインインできず表示できなかったときは false を返す
    func showLeaderboards() -> Bool {
        if isAuthenticated {
            GKAccessPoint.shared.trigger(state: .leaderboards) { }
            return true
        }
        if let signInViewController, let presenter = Self.topViewController() {
            presenter.present(signInViewController, animated: true)
            return true
        }
        // 一度サインインを閉じると、同じ起動中は GameKit がサインイン画面を出し直さない
        return false
    }

    private func submitPendingScores() {
        let scores = pendingScores
        pendingScores = [:]
        for (leaderboardID, score) in scores {
            Task {
                do {
                    try await GKLeaderboard.submitScore(
                        score,
                        context: 0,
                        player: GKLocalPlayer.local,
                        leaderboardIDs: [leaderboardID]
                    )
                } catch {
                    print("Failed to submit score to \(leaderboardID): \(error.localizedDescription)")
                    // 次の機会に送り直す
                    pendingScores[leaderboardID] = max(pendingScores[leaderboardID] ?? 0, score)
                }
            }
        }
    }

    private static func topViewController() -> UIViewController? {
        let root = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
        var top = root
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}
