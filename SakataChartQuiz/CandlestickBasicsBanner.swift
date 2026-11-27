import GoogleMobileAds
import SwiftUI

struct CandlestickBasicsBanner: View {
    let loadsAd: Bool

    var body: some View {
        let size = cgSize(for: AdSizeBanner)

        Color.clear
            .frame(height: size.height)
            .frame(maxWidth: .infinity)
            .overlay {
                if loadsAd {
                    ViewThatFits(in: .horizontal) {
                        BannerRepresentable()
                            .frame(width: size.width, height: size.height)
                        Color.clear
                    }
                }
            }
            .padding(.top, 16)
            .background(.bar)
    }
}

private struct BannerRepresentable: UIViewRepresentable {
#if DEBUG
    private static let adUnitID = "ca-app-pub-3940256099942544/2934735716"
#else
    private static let adUnitID = "ca-app-pub-8522231452310619/7555913507"
#endif

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: AdSizeBanner)
        banner.adUnitID = Self.adUnitID
        banner.load(Request())
        return banner
    }

    func updateUIView(_ banner: BannerView, context: Context) {}
}
