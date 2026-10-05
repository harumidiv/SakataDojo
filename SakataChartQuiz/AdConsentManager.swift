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

    /// UMP の同意取得 → ATT ダイアログ → Mobile Ads SDK の起動を順に行う。
    /// ATT はアプリがアクティブな状態でないと表示されないため、scenePhase が active になってから呼ぶこと。
    func gatherConsentIfNeeded() async {
        guard !hasGatheredConsent else { return }
        hasGatheredConsent = true

        // 前回起動時に同意済みなら、同意情報の更新を待たずに広告の準備を始める
        startMobileAdsIfPossible()

        do {
            try await ConsentInformation.shared.requestConsentInfoUpdate(with: nil)
            try await ConsentForm.loadAndPresentIfRequired(from: nil)
        } catch {
            print("Failed to gather consent: \(error.localizedDescription)")
        }

        await requestTrackingAuthorizationIfNeeded()

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
        guard ConsentInformation.shared.canRequestAds else { return }
        canRequestAds = true

        guard !hasStartedMobileAds else { return }
        hasStartedMobileAds = true
        MobileAds.shared.start()
    }
}
