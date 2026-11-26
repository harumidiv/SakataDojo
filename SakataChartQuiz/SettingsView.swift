import SwiftUI

/// 記録・設定タブ。記録の確認やランキング、広告まわりの設定をまとめる。
struct SettingsView: View {
    @ObservedObject var adRemoval: AdRemovalSubscription
    let bestStreak: Int
    let dailyStreak: Int
    let dailyBestStreak: Int
    let hasMistakes: Bool
    let isPrivacyOptionsRequired: Bool
    let onResetMistakes: () -> Void
    /// ランキングを表示できたら true（Game Center 未サインインなら false）
    let onShowLeaderboards: () -> Bool
    let onPresentPrivacyOptions: () async -> Void

    @State private var showsAdRemoval = false
    @State private var showsResetConfirmation = false
    @State private var showsGameCenterSignInHelp = false

    private static let privacyURL = URL(string: "https://harumidiv.github.io/AppleStoreDevelopprSite/privacy.html")!
    private static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        return "\(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            List {
                Section("記録") {
                    LabeledContent {
                        Text("\(bestStreak)問").monospacedDigit()
                    } label: {
                        Label("最高連続正解", systemImage: "star.fill")
                    }
                    LabeledContent {
                        Text("\(dailyStreak)日").monospacedDigit()
                    } label: {
                        Label("デイリー連続日数", systemImage: "flame.fill")
                    }
                    LabeledContent {
                        Text("\(dailyBestStreak)日").monospacedDigit()
                    } label: {
                        Label("デイリー最長連続日数", systemImage: "calendar")
                    }
                    Button {
                        if !onShowLeaderboards() {
                            showsGameCenterSignInHelp = true
                        }
                    } label: {
                        Label("ランキング", systemImage: "trophy.fill")
                    }
                }

                Section {
                    Button {
                        showsResetConfirmation = true
                    } label: {
                        Label("苦手リセット", systemImage: "arrow.counterclockwise")
                            .foregroundStyle(hasMistakes ? Color.red : Color.secondary)
                    }
                    .disabled(!hasMistakes)
                } header: {
                    Text("学習")
                } footer: {
                    Text("間違えたパターンの記録を消し、弱点強化モードの出題の偏りをなくします。")
                }

                Section("広告") {
                    Button {
                        showsAdRemoval = true
                    } label: {
                        if adRemoval.access == .subscribed {
                            Label("広告非表示（購読中）", systemImage: "checkmark.circle.fill")
                        } else {
                            Label("広告を非表示", systemImage: "rectangle.slash")
                        }
                    }
                    if isPrivacyOptionsRequired {
                        Button {
                            Task { await onPresentPrivacyOptions() }
                        } label: {
                            Label("プライバシー設定", systemImage: "hand.raised.fill")
                        }
                    }
                }

                Section("このアプリについて") {
                    Link(destination: Self.termsURL) {
                        Label("利用規約", systemImage: "doc.text")
                    }
                    Link(destination: Self.privacyURL) {
                        Label("プライバシーポリシー", systemImage: "lock.shield")
                    }
                    LabeledContent("バージョン", value: appVersion)
                }
            }
            .navigationTitle("記録・設定")
            .sheet(isPresented: $showsAdRemoval) {
                AdRemovalSubscriptionView(subscription: adRemoval)
            }
            .confirmationDialog("苦手の記録をリセットしますか？", isPresented: $showsResetConfirmation, titleVisibility: .visible) {
                Button("リセット", role: .destructive) { onResetMistakes() }
                Button("キャンセル", role: .cancel) {}
            }
            .alert("Game Centerにサインインしていません", isPresented: $showsGameCenterSignInHelp) {
                Button("閉じる", role: .cancel) {}
            } message: {
                Text("設定アプリの「Game Center」からサインインすると、ランキングに参加できます。")
            }
        }
    }
}
