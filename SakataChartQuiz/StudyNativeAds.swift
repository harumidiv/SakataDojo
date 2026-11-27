import Combine
import GoogleMobileAds
import SwiftUI
import UIKit
import UserMessagingPlatform

/// 図鑑の一覧に差し込むネイティブ広告をまとめて読み込む。
@MainActor
final class StudyNativeAdManager: NSObject, ObservableObject, NativeAdLoaderDelegate {
#if DEBUG
    private static let adUnitID = "ca-app-pub-3940256099942544/3986624511"
#else
    private static let adUnitID = "ca-app-pub-8522231452310619/4559988573"
#endif

    /// 一覧に差し込む最大枚数（パターン8件ごとに1枚）
    static let maxAds = 4
    /// ネイティブ広告は読み込みから 1 時間で失効するため、少し余裕を持たせて読み直す
    private static let adExpirationInterval: TimeInterval = 55 * 60

    @Published private(set) var ads: [NativeAd] = []

    private var adLoader: AdLoader?
    private var pendingAds: [NativeAd] = []
    private var loadedAt: Date?
    private let adRemoval: AdRemovalSubscription

    init(adRemoval: AdRemovalSubscription) {
        self.adRemoval = adRemoval
        super.init()
    }

    func loadAdsIfNeeded() {
        guard adRemoval.access == .free, ConsentInformation.shared.canRequestAds else { return }
        if let loadedAt, Date().timeIntervalSince(loadedAt) < Self.adExpirationInterval, !ads.isEmpty { return }
        guard adLoader?.isLoading != true else { return }

        let options = MultipleAdsAdLoaderOptions()
        options.numberOfAds = Self.maxAds
        let loader = AdLoader(
            adUnitID: Self.adUnitID,
            rootViewController: nil,
            adTypes: [.native],
            options: [options]
        )
        loader.delegate = self
        pendingAds = []
        adLoader = loader
        loader.load(Request())
    }

    func discardAds() {
        ads = []
        pendingAds = []
        loadedAt = nil
        adLoader = nil
    }

    nonisolated func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
        MainActor.assumeIsolated {
            pendingAds.append(nativeAd)
        }
    }

    nonisolated func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
        print("Failed to load native ad: \(error.localizedDescription)")
    }

    nonisolated func adLoaderDidFinishLoading(_ adLoader: AdLoader) {
        MainActor.assumeIsolated {
            // 読み込み中に購読された場合は表示しない
            guard adRemoval.access == .free, !pendingAds.isEmpty else { return }
            ads = pendingAds
            pendingAds = []
            loadedAt = Date()
        }
    }
}

/// 図鑑の一覧に馴染むカード型のネイティブ広告。
struct StudyNativeAdCard: View {
    let nativeAd: NativeAd

    var body: some View {
        NativeAdCardRepresentable(nativeAd: nativeAd)
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct NativeAdCardRepresentable: UIViewRepresentable {
    let nativeAd: NativeAd

    func makeUIView(context: Context) -> NativeAdCardView {
        NativeAdCardView()
    }

    func updateUIView(_ view: NativeAdCardView, context: Context) {
        view.configure(with: nativeAd)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: NativeAdCardView, context: Context) -> CGSize? {
        let proposedWidth = proposal.width ?? .infinity
        guard let width = proposedWidth.isFinite ? proposedWidth : uiView.window?.bounds.width else {
            return nil
        }
        let size = uiView.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        return CGSize(width: width, height: size.height)
    }
}

/// AdMob のネイティブ広告ポリシーに沿って、広告ラベル・見出し・メディア・CTA を表示する。
private final class NativeAdCardView: NativeAdView {
    private let badgeLabel = UILabel()
    private let headlineLabel = UILabel()
    private let advertiserLabel = UILabel()
    private let adMediaView = MediaView()
    private let bodyLabel = UILabel()
    private let ctaButton = UIButton(configuration: .filled())

    /// ポリシー上 MediaView は 120x120pt 以上が必要
    private static let mediaSize: CGFloat = 120

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUpViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// 横長レイアウト: 左にメディア、右に「広告」ラベル・見出し・説明・CTA
    private func setUpViews() {
        badgeLabel.text = String(localized: "広告", comment: "ネイティブ広告であることを示すラベル")
        badgeLabel.font = .preferredFont(forTextStyle: .caption2).bold()
        badgeLabel.textColor = .white
        badgeLabel.backgroundColor = .systemOrange
        badgeLabel.textAlignment = .center
        badgeLabel.layer.cornerRadius = 4
        badgeLabel.clipsToBounds = true
        badgeLabel.setContentHuggingPriority(.required, for: .horizontal)

        advertiserLabel.font = .preferredFont(forTextStyle: .caption2)
        advertiserLabel.textColor = .secondaryLabel

        headlineLabel.font = .preferredFont(forTextStyle: .subheadline).bold()
        headlineLabel.numberOfLines = 2

        bodyLabel.font = .preferredFont(forTextStyle: .caption1)
        bodyLabel.textColor = .secondaryLabel
        bodyLabel.numberOfLines = 1

        adMediaView.contentMode = .scaleAspectFill
        adMediaView.layer.cornerRadius = 8
        adMediaView.clipsToBounds = true

        // CTA のタップは NativeAdView が処理するため、ボタン自身はタッチを受け取らない
        ctaButton.isUserInteractionEnabled = false
        ctaButton.configuration?.cornerStyle = .capsule
        ctaButton.configuration?.buttonSize = .small
        ctaButton.setContentHuggingPriority(.required, for: .horizontal)

        let badgeRow = UIStackView(arrangedSubviews: [badgeLabel, advertiserLabel])
        badgeRow.axis = .horizontal
        badgeRow.spacing = 6
        badgeRow.alignment = .center

        let ctaRow = UIStackView(arrangedSubviews: [UIView(), ctaButton])
        ctaRow.axis = .horizontal

        let textStack = UIStackView(arrangedSubviews: [badgeRow, headlineLabel, bodyLabel, UIView(), ctaRow])
        textStack.axis = .vertical
        textStack.spacing = 4

        let stack = UIStackView(arrangedSubviews: [adMediaView, textStack])
        stack.axis = .horizontal
        stack.spacing = 12
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            badgeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 32),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            adMediaView.widthAnchor.constraint(equalToConstant: Self.mediaSize),
            adMediaView.heightAnchor.constraint(equalToConstant: Self.mediaSize),
        ])

        headlineView = headlineLabel
        advertiserView = advertiserLabel
        mediaView = adMediaView
        bodyView = bodyLabel
        callToActionView = ctaButton
    }

    func configure(with nativeAd: NativeAd) {
        guard self.nativeAd !== nativeAd else { return }

        headlineLabel.text = nativeAd.headline
        advertiserLabel.text = nativeAd.advertiser
        advertiserLabel.isHidden = nativeAd.advertiser == nil
        adMediaView.mediaContent = nativeAd.mediaContent
        bodyLabel.text = nativeAd.body
        bodyLabel.isHidden = nativeAd.body == nil
        ctaButton.configuration?.title = nativeAd.callToAction
        ctaButton.isHidden = nativeAd.callToAction == nil

        // アセットを設定してから nativeAd を渡す（インプレッション計測とクリック処理のため）
        self.nativeAd = nativeAd
    }
}

private extension UIFont {
    func bold() -> UIFont {
        guard let descriptor = fontDescriptor.withSymbolicTraits(.traitBold) else { return self }
        return UIFont(descriptor: descriptor, size: 0)
    }
}
