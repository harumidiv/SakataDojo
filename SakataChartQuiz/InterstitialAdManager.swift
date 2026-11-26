import Combine
import Foundation
import GoogleMobileAds
import UserMessagingPlatform

@MainActor
final class InterstitialAdManager: NSObject, ObservableObject, FullScreenContentDelegate {
#if DEBUG
    private static let adUnitID = "ca-app-pub-3940256099942544/4411468910"
#else
    private static let adUnitID = "ca-app-pub-8522231452310619/5943546026"
#endif

    /// インタースティシャル広告は読み込みから 1 時間で失効するため、少し余裕を持たせて破棄する
    private static let adExpirationInterval: TimeInterval = 55 * 60

    private var interstitialAd: InterstitialAd?
    private var loadedAt: Date?
    private var isLoading = false
    private var dismissalAction: (() -> Void)?
    private let adRemoval: AdRemovalSubscription

    init(adRemoval: AdRemovalSubscription) {
        self.adRemoval = adRemoval
        super.init()
    }

    func discardCachedAd() {
        interstitialAd = nil
        loadedAt = nil
    }

    func loadAd() {
        guard adRemoval.access == .free, ConsentInformation.shared.canRequestAds else { return }
        discardExpiredAd()
        guard interstitialAd == nil, !isLoading else { return }
        isLoading = true

        Task { [weak self] in
            guard let self else { return }
            defer { isLoading = false }
            guard adRemoval.access == .free else { return }

            do {
                let ad = try await InterstitialAd.load(
                    with: Self.adUnitID,
                    request: Request()
                )
                guard adRemoval.access == .free else { return }
                ad.fullScreenContentDelegate = self
                interstitialAd = ad
                loadedAt = Date()
            } catch {
                print("Failed to load interstitial ad: \(error.localizedDescription)")
            }
        }
    }

    func present(onDismiss: @escaping () -> Void) {
        guard dismissalAction == nil else { return }
        guard adRemoval.access == .free, ConsentInformation.shared.canRequestAds else {
            onDismiss()
            return
        }
        discardExpiredAd()
        guard let interstitialAd else {
            onDismiss()
            loadAd()
            return
        }

        dismissalAction = onDismiss
        discardCachedAd()
        interstitialAd.present(from: nil)
    }

    private func discardExpiredAd() {
        guard let loadedAt,
              Date().timeIntervalSince(loadedAt) > Self.adExpirationInterval else { return }
        discardCachedAd()
    }

    func ad(
        _ ad: FullScreenPresentingAd,
        didFailToPresentFullScreenContentWithError error: Error
    ) {
        print("Failed to present interstitial ad: \(error.localizedDescription)")
        finishPresentation()
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        finishPresentation()
    }

    private func finishPresentation() {
        let action = dismissalAction
        dismissalAction = nil
        action?()
        loadAd()
    }
}
