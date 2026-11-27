import GoogleMobileAds
import SwiftUI

struct CandlestickBasicsBanner: View {
    /// Space between the top of this view and the ad itself.
    static let topPadding: CGFloat = 16

    let loadsAd: Bool
    /// Off when the banner sits on a scene that should show through around the ad.
    var showsBarBackground = true

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
            .padding(.top, Self.topPadding)
            .background(showsBarBackground ? AnyShapeStyle(.bar) : AnyShapeStyle(.clear))
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
