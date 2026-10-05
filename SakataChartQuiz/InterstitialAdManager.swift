import Combine
import GoogleMobileAds

@MainActor
final class InterstitialAdManager: NSObject, ObservableObject, FullScreenContentDelegate {
#if DEBUG
    private static let adUnitID = "ca-app-pub-3940256099942544/4411468910"
#else
    private static let adUnitID = "ca-app-pub-8522231452310619/5943546026"
#endif

    private var interstitialAd: InterstitialAd?
    private var isLoading = false
    private var dismissalAction: (() -> Void)?

    func loadAd() {
        guard interstitialAd == nil, !isLoading else { return }
        isLoading = true

        Task { [weak self] in
            guard let self else { return }

            do {
                let ad = try await InterstitialAd.load(
                    with: Self.adUnitID,
                    request: Request()
                )
                ad.fullScreenContentDelegate = self
                interstitialAd = ad
            } catch {
                print("Failed to load interstitial ad: \(error.localizedDescription)")
            }

            isLoading = false
        }
    }

    func present(onDismiss: @escaping () -> Void) {
        guard dismissalAction == nil else { return }
        guard let interstitialAd else {
            onDismiss()
            loadAd()
            return
        }

        dismissalAction = onDismiss
        self.interstitialAd = nil
        interstitialAd.present(from: nil)
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
