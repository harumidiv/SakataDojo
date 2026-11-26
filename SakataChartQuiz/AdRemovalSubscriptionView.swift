import StoreKit
import SwiftUI

struct AdRemovalSubscriptionView: View {
    @ObservedObject var subscription: AdRemovalSubscription
    @Environment(\.dismiss) private var dismiss
    @State private var showsSubscriptionManagement = false
    @State private var showsMessage = false
    @State private var message: LocalizedStringKey = ""

    private static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    private static let privacyURL = URL(string: "https://harumidiv.github.io/AppleStoreDevelopprSite/privacy.html")!

    var body: some View {
        NavigationStack {
            Group {
                switch subscription.access {
                case .checking:
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .free:
                    SubscriptionStoreView(productIDs: [AdRemovalSubscription.productID]) {
                        VStack(spacing: 12) {
                            Image(systemName: "rectangle.slash")
                                .font(.largeTitle)
                                .foregroundStyle(Color.accentColor)
                                .accessibilityHidden(true)
                            Text("購読中は広告が表示されません。")
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                    }
                    .modifier(BottomBarSubscribeButtonModifier())
                    // アプリ内の他のボタンと同じく、押下時にボタン全体が薄くなるスタイルに揃える
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    // 閉じるボタンはナビゲーションバーに出すので、ストア標準の × は隠す
                    .storeButton(.hidden, for: .cancellation)
                    .storeButton(.visible, for: .restorePurchases)
                    // 審査ガイドライン 3.1.2: 購入ボタンに価格と期間を明示する
                    .subscriptionStoreButtonLabel(.multiline)
                    .subscriptionStorePolicyDestination(url: Self.termsURL, for: .termsOfService)
                    .subscriptionStorePolicyDestination(url: Self.privacyURL, for: .privacyPolicy)
                    .onInAppPurchaseCompletion { _, result in
                        switch result {
                        case .success(.success(let verification)):
                            if case .verified = verification {
                                await subscription.finish(verification)
                            } else {
                                showMessage("購入を確認できませんでした。")
                            }
                        case .success(.pending):
                            showMessage("購入は承認待ちです。")
                        case .failure(StoreKitError.userCancelled):
                            break
                        case .failure:
                            showMessage("購入を完了できませんでした。もう一度お試しください。")
                        default:
                            break
                        }
                    }
                case .subscribed:
                    List {
                        Section {
                            Label("広告非表示が有効です", systemImage: "checkmark.circle.fill")
                            Button("サブスクリプションを管理") {
                                showsSubscriptionManagement = true
                            }
                        }
                        Section {
                            Link("利用規約", destination: Self.termsURL)
                            Link("プライバシーポリシー", destination: Self.privacyURL)
                        }
                    }
                }
            }
            .navigationTitle("広告を非表示")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("閉じる")
                }
            }
            .manageSubscriptionsSheet(isPresented: $showsSubscriptionManagement)
            .alert("広告を非表示", isPresented: $showsMessage) {
                Button("閉じる", role: .cancel) {}
            } message: {
                Text(message)
            }
        }
    }

    private func showMessage(_ message: LocalizedStringKey) {
        self.message = message
        showsMessage = true
    }
}

/// 購入ボタンをスクロールしない下部バーに固定し、シートを開いた直後から見えるようにする。
private struct BottomBarSubscribeButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.subscriptionStoreControlStyle(.buttons, placement: .bottomBar)
        } else {
            content.subscriptionStoreControlStyle(.buttons)
        }
    }
}
