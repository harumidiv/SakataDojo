import AppTrackingTransparency
import Combine
import GoogleMobileAds
import UserMessagingPlatform

@MainActor
final class AdConsentManager: ObservableObject {
    @Published private(set) var canRequestAds = false
    @Published private(set) var isPrivacyOptionsRequired = false

    private var hasGatheredConsent = false
    private var hasStartedMobileAds = false
    private let adRemoval: AdRemovalSubscription

    init(adRemoval: AdRemovalSubscription) {
        self.adRemoval = adRemoval
    }

    /// UMP の同意取得 → ATT ダイアログ → Mobile Ads SDK の起動を順に行う。
    /// ATT はアプリがアクティブな状態でないと表示されないため、scenePhase が active になってから呼ぶこと。
    func gatherConsentIfNeeded() async {
        guard adRemoval.access == .free, !hasGatheredConsent else { return }
        if ProcessInfo.processInfo.arguments.contains(where: { $0.hasPrefix("--screenshot-state=") }) { return }
        hasGatheredConsent = true

        // 前回起動時に同意済みなら、同意情報の更新を待たずに広告の準備を始める
        startMobileAdsIfPossible()

        do {
            try await ConsentInformation.shared.requestConsentInfoUpdate(with: nil)
            if adRemoval.access == .free {
                try await ConsentForm.loadAndPresentIfRequired(from: nil)
            }
        } catch {
            print("Failed to gather consent: \(error.localizedDescription)")
        }

        if adRemoval.access == .free {
            await requestTrackingAuthorizationIfNeeded()
        } else {
            hasGatheredConsent = false
        }

        isPrivacyOptionsRequired =
            ConsentInformation.shared.privacyOptionsRequirementStatus == .required
        startMobileAdsIfPossible()
    }

    func presentPrivacyOptionsForm() async {
        do {
            try await ConsentForm.presentPrivacyOptionsForm(from: nil)
        } catch {
            print("Failed to present privacy options form: \(error.localizedDescription)")
        }
        startMobileAdsIfPossible()
    }

    private func requestTrackingAuthorizationIfNeeded() async {
        // UMP の IDFA 説明メッセージ経由で既に表示済みの場合は notDetermined ではなくなる
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }
        _ = await ATTrackingManager.requestTrackingAuthorization()
    }

    private func startMobileAdsIfPossible() {
        guard adRemoval.access == .free, ConsentInformation.shared.canRequestAds else { return }
        canRequestAds = true

        guard !hasStartedMobileAds else { return }
        hasStartedMobileAds = true
        MobileAds.shared.start()
    }
}
