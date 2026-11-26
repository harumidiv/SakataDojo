import SwiftUI
import UIKit
import StoreKit
import GoogleMobileAds

private func signalLabel(for direction: String) -> String {
    direction == "bullish"
        ? String(localized: "上昇サイン", comment: "上昇を示すローソク足パターン")
        : String(localized: "下落サイン", comment: "下落を示すローソク足パターン")
}

private enum AppScreen {
    /// タブ（ホーム・図鑑・記録・設定）を表示している状態
    case title
    case quiz
    case results
}

private enum AppTab: Hashable {
    case home
    case study
    case settings
}

private enum QuizMode: String, CaseIterable, Identifiable {
    case direction = "上昇／下落"
    case patternName = "パターン名4択"

    var id: Self { self }

    var title: String {
        switch self {
        case .direction:
            return String(localized: "上昇／下落", comment: "出題形式: 上がるか下がるかを当てる")
        case .patternName:
            return String(localized: "パターン名4択", comment: "出題形式: パターン名を4択で当てる")
        }
    }

    var prompt: String {
        switch self {
        case .direction:
            return String(localized: "このサインの方向は？")
        case .patternName:
            return String(localized: "このローソク足パターンは？")
        }
    }

    var description: String {
        switch self {
        case .direction:
            return String(localized: "チャートを見て、その後に上がるか下がるかを当てます")
        case .patternName:
            return String(localized: "ローソク足の形から、パターン名を4つの候補から選びます")
        }
    }

    var systemImage: String {
        switch self {
        case .direction:
            return "arrow.up.arrow.down"
        case .patternName:
            return "square.grid.2x2"
        }
    }
}

private enum QuizChartSource: String, CaseIterable, Identifiable {
    case ideals = "基本形"
    case examples = "実戦"

    var id: Self { self }

    var label: String {
        switch self {
        case .ideals:
            return String(localized: "基本形", comment: "チャート種別の切り替え: 模式図")
        case .examples:
            return String(localized: "実戦", comment: "チャート種別の切り替え: 実際の株価チャート")
        }
    }

    var title: String {
        switch self {
        case .examples:
            return String(localized: "実戦チャートで挑戦")
        case .ideals:
            return String(localized: "基本形チャートで練習")
        }
    }

    var description: String {
        switch self {
        case .examples:
            return String(localized: "実際の日本株市場で発生したローソク足パターンです")
        case .ideals:
            return String(localized: "特徴を強調した模式図で基本形を覚えます")
        }
    }

    var systemImage: String {
        switch self {
        case .examples:
            return "chart.xyaxis.line"
        case .ideals:
            return "star.fill"
        }
    }
}

private enum StudySortOrder: String, CaseIterable, Identifiable {
    case direction
    case category
    case name

    var id: Self { self }

    var title: String {
        switch self {
        case .direction:
            return String(localized: "方向別", comment: "図鑑の並べ替え: 上昇・下落サインごと")
        case .category:
            return String(localized: "分類別", comment: "図鑑の並べ替え: 三山・三川などの分類ごと")
        case .name:
            return String(localized: "名前順", comment: "図鑑の並べ替え: パターン名の順")
        }
    }
}

private struct StudySection: Identifiable {
    let id: String
    let title: String
    let systemImage: String
    let color: Color
    let patterns: [QuizPattern]
}

private struct QuestionResult: Identifiable {
    let id = UUID()
    let questionNumber: Int
    let patternID: String
    let patternName: String
    let patternDescription: String
    let signalDirection: String
    let chartSubtitle: String
    let candles: [Candle]
    let dividerIndex: Int?
    let showsMarketDetails: Bool
    let selectedAnswer: String
    let correctAnswer: String
    let isCorrect: Bool
}

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.requestReview) private var requestReview
    @ObservedObject private var adRemoval: AdRemovalSubscription
    @StateObject private var adConsentManager: AdConsentManager
    @StateObject private var interstitialAdManager: InterstitialAdManager
    @StateObject private var studyNativeAds: StudyNativeAdManager
    @StateObject private var gameCenter = GameCenterManager()
    @State private var allPatterns: [QuizPattern] = []
    @State private var currentPattern: QuizPattern?
    @State private var currentExample: QuizExample?
    @State private var quizChartSource: QuizChartSource = .ideals
    @State private var quizMode: QuizMode = .direction
    @State private var appScreen: AppScreen = .title
    @State private var selectedTab: AppTab = .home
    @State private var selectedAnswer: String?
    @State private var patternChoices: [String] = []
    @State private var showAnswer = false
    @State private var studySearchText = ""
    @State private var errorMessage: String?
    @State private var questionLimit: Int? = 10  // nil = 無限
    @State private var questionNumber: Int = 0
    @State private var correctCount: Int = 0
    @State private var patternQueue: [QuizPattern] = []
    @State private var weaknessMode: Bool = false
    @State private var currentStreak: Int = 0
    @State private var bestStreakThisSession: Int = 0
    @State private var isCompletingQuiz = false
    @State private var questionResults: [QuestionResult] = []
    @State private var isCorrectResultsExpanded = false
    @State private var isIncorrectResultsExpanded = false
    @State private var resultDate = Date()
    @State private var shareImage: ResultShareImage?
    @State private var showsShareError = false
    @AppStorage("patternMistakesData") private var patternMistakesData: Data = Data()
    @AppStorage("allTimeBestStreak") private var allTimeBestStreak: Int = 0
    @AppStorage("lastReviewRequestVersion") private var lastReviewRequestVersion = ""
    @AppStorage("patternIDMigrationVersion") private var patternIDMigrationVersion = 0
    @AppStorage("studySortOrder") private var studySortOrder: StudySortOrder = .direction

    // デイリーチャレンジ
    @State private var isDailyChallenge = false
    @State private var dailyQueue: [DailyQuestion] = []
    @State private var dailyStartDate = Date()
    @State private var todayKey = DailyChallenge.dayKey()
    @State private var settingsBeforeDaily: (source: QuizChartSource, mode: QuizMode, limit: Int?, weakness: Bool)?
    @AppStorage("dailyLastCompletedDay") private var dailyLastCompletedDay = ""
    @AppStorage("dailyStreak") private var dailyStreak = 0
    @AppStorage("dailyBestStreak") private var dailyBestStreak = 0
    @AppStorage("dailyLastResults") private var dailyLastResults = ""  // 例: "10111"（1=正解）

    init(adRemoval: AdRemovalSubscription) {
        self.adRemoval = adRemoval
        _adConsentManager = StateObject(wrappedValue: AdConsentManager(adRemoval: adRemoval))
        _interstitialAdManager = StateObject(wrappedValue: InterstitialAdManager(adRemoval: adRemoval))
        _studyNativeAds = StateObject(wrappedValue: StudyNativeAdManager(adRemoval: adRemoval))
    }

    private var isDailyCompletedToday: Bool {
        dailyLastCompletedDay == todayKey
    }

    /// 昨日までに途切れていれば0として表示する
    private var displayedDailyStreak: Int {
        let isAlive = dailyLastCompletedDay == todayKey
            || dailyLastCompletedDay == DailyChallenge.previousDayKey()
        return isAlive ? dailyStreak : 0
    }

    private var dailyResultFlags: [Bool] {
        dailyLastResults.map { $0 == "1" }
    }

    private var dailyShareText: String {
        let flags = dailyResultFlags
        let correct = flags.filter { $0 }.count
        var lines = [
            String(localized: "酒田道場 デイリーチャレンジ \(dailyLastCompletedDay)", comment: "SNS共有テキスト: デイリーチャレンジの日付（yyyy-MM-dd）"),
            "\(DailyChallenge.emojiSummary(flags)) \(correct)/\(flags.count)"
        ]
        if dailyStreak >= 2 {
            lines.append(String(localized: "🔥\(dailyStreak)日連続", comment: "SNS共有テキスト: デイリーチャレンジの連続日数"))
        }
        lines.append(String(localized: "#酒田道場", comment: "SNS共有用ハッシュタグ（#を残し、スペースを含めないこと）"))
        lines.append(Self.appStoreURL)
        return lines.joined(separator: "\n")
    }

    private static let appStoreURL = "https://apps.apple.com/app/id6798115410"

    private var patternMistakes: [String: Int] {
        (try? JSONDecoder().decode([String: Int].self, from: patternMistakesData)) ?? [:]
    }

    private func recordResult(patternName: String, correct: Bool) {
        var m = patternMistakes
        m[patternName] = correct
            ? max(0, (m[patternName] ?? 0) - 1)
            : (m[patternName] ?? 0) + 1
        patternMistakesData = (try? JSONEncoder().encode(m)) ?? Data()
    }

    private func weightedRandom(from patterns: [QuizPattern]) -> QuizPattern? {
        guard !patterns.isEmpty else { return nil }
        let m = patternMistakes
        let weights = patterns.map { max(1, (m[$0.pattern] ?? 0) * 2 + 1) }
        let total = weights.reduce(0, +)
        var rand = Int.random(in: 0..<total)
        for (p, w) in zip(patterns, weights) {
            rand -= w
            if rand < 0 { return p }
        }
        return patterns.last
    }

    private let patternNames = PatternCatalog.ids

    /// Game Center にサインインし、これまでの自己ベストも送っておく（アップデート前の記録もランキングに反映される）
    private func startGameCenterIfNeeded() {
        if ProcessInfo.processInfo.arguments.contains(where: { $0.hasPrefix("--screenshot-state=") }) { return }
        gameCenter.authenticate()
        gameCenter.submit(allTimeBestStreak, to: GameCenterManager.Leaderboard.bestStreak)
        gameCenter.submit(dailyBestStreak, to: GameCenterManager.Leaderboard.dailyBestStreak)
    }

    /// パターンIDを改名したので、保存済みの苦手記録を新しいIDへ一度だけ付け替える
    private func migratePatternIDsIfNeeded() {
        guard patternIDMigrationVersion < PatternCatalog.currentMigrationVersion else { return }
        let migrated = PatternCatalog.migrateMistakes(patternMistakes)
        patternMistakesData = (try? JSONEncoder().encode(migrated)) ?? Data()
        patternIDMigrationVersion = PatternCatalog.currentMigrationVersion
    }

    private var displayCandles: [Candle] {
        switch quizChartSource {
        case .examples:
            guard let ex = currentExample else { return [] }
            return showAnswer ? ex.quizCandles + ex.answerCandles : ex.quizCandles
        case .ideals:
            guard let pattern = currentPattern else { return [] }
            let base = idealPatternCandles[pattern.pattern] ?? []
            if showAnswer, let answer = idealPatternAnswerCandles[pattern.pattern] {
                return base + answer
            }
            return base
        }
    }

    private var dividerIndex: Int? {
        guard showAnswer else { return nil }
        switch quizChartSource {
        case .examples:
            guard let ex = currentExample else { return nil }
            return ex.quizCandles.count
        case .ideals:
            guard let pattern = currentPattern,
                  idealPatternAnswerCandles[pattern.pattern] != nil else { return nil }
            return idealPatternCandles[pattern.pattern]?.count
        }
    }

    private var answerOptions: [String] {
        switch quizMode {
        case .direction:
            return ["bullish", "bearish"]
        case .patternName:
            return patternChoices
        }
    }

    private var correctAnswer: String? {
        guard let pattern = currentPattern else { return nil }
        switch quizMode {
        case .direction:
            return pattern.direction
        case .patternName:
            return pattern.pattern
        }
    }

    private var isCorrect: Bool? {
        guard let selectedAnswer, let correctAnswer else { return nil }
        return selectedAnswer == correctAnswer
    }

    private var isLastQuestion: Bool {
        guard let questionLimit else { return false }
        return questionNumber >= questionLimit
    }

    private var filteredStudyPatterns: [QuizPattern] {
        guard !studySearchText.isEmpty else { return allPatterns }
        return allPatterns.filter {
            $0.localizedName.localizedCaseInsensitiveContains(studySearchText)
                || $0.localizedDescription.localizedCaseInsensitiveContains(studySearchText)
                || $0.pattern.localizedCaseInsensitiveContains(studySearchText)
        }
    }

    private var resultShareText: String {
        if isDailyChallenge { return dailyShareText }
        let accuracy = (questionNumber > 0
            ? Double(correctCount) / Double(questionNumber)
            : 0).formatted(.percent.precision(.fractionLength(0)))
        var lines = [
            String(localized: "酒田道場でローソク足クイズに挑戦！", comment: "SNS共有テキストの1行目"),
            String(localized: "\(questionNumber)問中 \(correctCount)問正解（正解率\(accuracy)）", comment: "SNS共有テキスト: 問題数・正解数・正解率")
        ]
        if bestStreakThisSession >= 2 {
            lines.append(String(localized: "最大\(bestStreakThisSession)連続正解🔥", comment: "SNS共有テキスト: 最大連続正解数"))
        }
        lines.append(String(localized: "#酒田道場", comment: "SNS共有用ハッシュタグ（#を残し、スペースを含めないこと）"))
        lines.append(Self.appStoreURL)
        return lines.joined(separator: "\n")
    }

    private var correctQuestionResults: [QuestionResult] {
        questionResults.filter(\.isCorrect)
    }

    private var incorrectQuestionResults: [QuestionResult] {
        questionResults.filter { !$0.isCorrect }
    }

    var body: some View {
        Group {
            switch appScreen {
            case .title:
                mainTabs
            case .quiz:
                quizScreen
            case .results:
                resultsScreen
            }
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            guard phase == .active else { return }
            todayKey = DailyChallenge.dayKey()
            Task {
                await adRemoval.refresh()
                await adConsentManager.gatherConsentIfNeeded()
            }
        }
        .onChange(of: adRemoval.access) { _, access in
            if access == .free, scenePhase == .active {
                Task { await adConsentManager.gatherConsentIfNeeded() }
                if adConsentManager.canRequestAds {
                    interstitialAdManager.loadAd()
                    studyNativeAds.loadAdsIfNeeded()
                }
            } else {
                interstitialAdManager.discardCachedAd()
                studyNativeAds.discardAds()
            }
        }
        .onChange(of: adConsentManager.canRequestAds) { _, canRequestAds in
            if canRequestAds {
                interstitialAdManager.loadAd()
                studyNativeAds.loadAdsIfNeeded()
            }
        }
        .onAppear {
            if allPatterns.isEmpty, errorMessage == nil {
                migratePatternIDsIfNeeded()
                loadAllPatterns()
#if DEBUG
                configureScreenshotStateIfNeeded()
#endif
            }
            startGameCenterIfNeeded()
        }
        // 自己ベストが更新されたらランキングへ送る
        .onChange(of: allTimeBestStreak) { _, newValue in
            gameCenter.submit(newValue, to: GameCenterManager.Leaderboard.bestStreak)
        }
        .onChange(of: dailyBestStreak) { _, newValue in
            gameCenter.submit(newValue, to: GameCenterManager.Leaderboard.dailyBestStreak)
        }
    }

    private var titleScreen: some View {
        NavigationStack {
        ScrollView {
            VStack(spacing: 24) {
                dailyChallengeCard
                    .padding(.top, 8)

                VStack(alignment: .leading, spacing: 12) {
                    Text("チャートを選択")
                        .font(.headline)

                    Picker("チャート", selection: $quizChartSource) {
                        ForEach(QuizChartSource.allCases) { source in
                            Label(source.label, systemImage: source.systemImage)
                                .tag(source)
                        }
                    }
                    .pickerStyle(.segmented)

                    Label(quizChartSource.title, systemImage: quizChartSource.systemImage)
                        .font(.subheadline.bold())
                        .foregroundStyle(Color.accentColor)

                    Text(quizChartSource.description)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("出題形式を選択")
                        .font(.headline)

                    ForEach(QuizMode.allCases) { mode in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                quizMode = mode
                            }
                        } label: {
                            HStack(spacing: 16) {
                                Image(systemName: mode.systemImage)
                                    .font(.title2.bold())
                                    .foregroundStyle(Color.accentColor)
                                    .frame(width: 44, height: 44)
                                    .background(
                                        Circle()
                                            .fill(Color.accentColor.opacity(0.12))
                                    )

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(mode.title)
                                        .font(.headline)
                                        .foregroundStyle(.primary)

                                    Text(mode.description)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.leading)
                                }

                                Spacer(minLength: 8)

                                Image(systemName: quizMode == mode ? "checkmark.circle.fill" : "circle")
                                    .font(.title2)
                                    .foregroundStyle(quizMode == mode ? Color.accentColor : Color.secondary)
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        quizMode == mode
                                            ? Color.accentColor.opacity(0.08)
                                            : Color.secondary.opacity(0.06)
                                    )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        quizMode == mode
                                            ? Color.accentColor
                                            : Color.secondary.opacity(0.2),
                                        lineWidth: quizMode == mode ? 2 : 1
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("問題数を選択")
                        .font(.headline)

                    Picker("問題数", selection: $questionLimit) {
                        Text("10問").tag(Optional(10))
                        Text("30問").tag(Optional(30))
                        Text("∞").tag(Optional<Int>(nil))
                    }
                    .pickerStyle(.segmented)
                }

                let totalMistakes = patternMistakes.values.reduce(0, +)
                if totalMistakes >= 50 {
                    HStack {
                        Label("弱点強化モード", systemImage: "flame.fill")
                            .font(.headline)
                            .foregroundStyle(weaknessMode ? .orange : .primary)
                        Spacer()
                        Toggle("", isOn: $weaknessMode)
                            .labelsHidden()
                            .tint(.orange)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(weaknessMode ? Color.orange.opacity(0.08) : Color.secondary.opacity(0.06))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(weaknessMode ? Color.orange : Color.secondary.opacity(0.2),
                                    lineWidth: weaknessMode ? 2 : 1)
                    )
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "flame")
                            .foregroundStyle(.secondary)
                        Text("あと\(50 - totalMistakes)問ミスで弱点強化モード解放")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Group {
                    if let error = errorMessage {
                        Text(error)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    } else if allPatterns.isEmpty {
                        ProgressView("問題を読み込み中...")
                    }
                }

                Spacer(minLength: 16)
            }
            .frame(maxWidth: 600)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
        }
        // 設定がスクロールしても「クイズを始める」は常にタブバーの上に見えるようにする
        .safeAreaInset(edge: .bottom) {
            Button {
                startQuiz()
            } label: {
                Label("クイズを始める", systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(allPatterns.isEmpty)
            .frame(maxWidth: 600)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(.bar)
        }
        .background(Color.secondary.opacity(0.04).ignoresSafeArea())
        .navigationTitle("酒田道場")
        .navigationBarTitleDisplayMode(.inline)
        } // NavigationStack
    }

    private var mainTabs: some View {
        TabView(selection: $selectedTab) {
            titleScreen
                .tabItem { Label("ホーム", systemImage: "house.fill") }
                .tag(AppTab.home)

            studyScreen
                .tabItem { Label("図鑑", systemImage: "books.vertical.fill") }
                .tag(AppTab.study)

            SettingsView(
                adRemoval: adRemoval,
                bestStreak: allTimeBestStreak,
                dailyStreak: displayedDailyStreak,
                dailyBestStreak: dailyBestStreak,
                hasMistakes: patternMistakes.values.contains(where: { $0 > 0 }),
                isPrivacyOptionsRequired: adConsentManager.isPrivacyOptionsRequired,
                onResetMistakes: { patternMistakesData = Data() },
                onShowLeaderboards: { gameCenter.showLeaderboards() },
                onPresentPrivacyOptions: { await adConsentManager.presentPrivacyOptionsForm() }
            )
            .tabItem { Label("記録・設定", systemImage: "gearshape.fill") }
            .tag(AppTab.settings)
        }
    }

    private var dailyChallengeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("デイリーチャレンジ", systemImage: "calendar")
                    .font(.headline)
                Spacer()
                if displayedDailyStreak > 0 {
                    Label("\(displayedDailyStreak)日連続", systemImage: "flame.fill")
                        .font(.subheadline.bold().monospacedDigit())
                        .foregroundStyle(.orange)
                }
            }

            if isDailyCompletedToday {
                let flags = dailyResultFlags
                Text(DailyChallenge.emojiSummary(flags))
                    .font(.title2)
                Text("今日の結果 \(flags.filter { $0 }.count)/\(flags.count)　また明日挑戦しよう")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                ShareLink(item: dailyShareText) {
                    Label("結果を共有", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .tint(.orange)
            } else {
                Text("実戦チャートのパターン名4択・全\(DailyChallenge.questionCount)問。1日1回、みんな同じ問題に挑戦します")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if displayedDailyStreak > 0 {
                    Text("今日も挑戦して連続記録を伸ばそう")
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                }
                Button {
                    startDailyChallenge()
                } label: {
                    Label("今日の\(DailyChallenge.questionCount)問に挑戦", systemImage: "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(allPatterns.isEmpty)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.orange.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.orange.opacity(0.4), lineWidth: 1)
        )
    }

    private var studyScreen: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Picker("並べ替え", selection: $studySortOrder) {
                        ForEach(StudySortOrder.allCases) { order in
                            Text(order.title).tag(order)
                        }
                    }
                    .pickerStyle(.segmented)

                    let sections = studySections
                    ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                        studyGrid(
                            section,
                            patternOffset: sections.prefix(index).reduce(0) { $0 + $1.patterns.count },
                            totalPatterns: sections.reduce(0) { $0 + $1.patterns.count }
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("パターン図鑑")
            .searchable(text: $studySearchText, prompt: "パターン名や説明を検索")
            .overlay {
                if filteredStudyPatterns.isEmpty {
                    ContentUnavailableView.search(text: studySearchText)
                }
            }
        }
    }

    private var studySections: [StudySection] {
        let patterns = filteredStudyPatterns
        switch studySortOrder {
        case .direction:
            return [
                StudySection(
                    id: "bullish",
                    title: signalLabel(for: "bullish"),
                    systemImage: "arrow.up.right",
                    color: .red,
                    patterns: patterns.filter { $0.direction == "bullish" }
                ),
                StudySection(
                    id: "bearish",
                    title: signalLabel(for: "bearish"),
                    systemImage: "arrow.down.right",
                    color: .blue,
                    patterns: patterns.filter { $0.direction == "bearish" }
                )
            ].filter { !$0.patterns.isEmpty }
        case .category:
            return PatternCategory.allCases.compactMap { category in
                // 分類の中では上昇サインを先に並べる
                let items = patterns
                    .filter { PatternCatalog.category(for: $0.pattern) == category }
                    .sorted { ($0.direction == "bullish" ? 0 : 1) < ($1.direction == "bullish" ? 0 : 1) }
                guard !items.isEmpty else { return nil }
                return StudySection(
                    id: category.rawValue,
                    title: category.title,
                    systemImage: category.systemImage,
                    color: .primary,
                    patterns: items
                )
            }
        case .name:
            let sorted = patterns.sorted {
                PatternCatalog.sortKey(for: $0)
                    .localizedStandardCompare(PatternCatalog.sortKey(for: $1)) == .orderedAscending
            }
            guard !sorted.isEmpty else { return [] }
            return [StudySection(
                id: "all",
                title: String(localized: "すべてのパターン"),
                systemImage: "textformat",
                color: .primary,
                patterns: sorted
            )]
        }
    }

    /// 図鑑ではセクションをまたいで通しでパターン8件ごとにネイティブ広告を1枚はさむ
    private static let studyPatternsPerAd = 8

    /// 検索中は広告を出さず、読み込めた枚数の範囲で差し込む
    private func studyAd(slot: Int) -> NativeAd? {
        guard studySearchText.isEmpty, adRemoval.access == .free,
              studyNativeAds.ads.indices.contains(slot) else { return nil }
        return studyNativeAds.ads[slot]
    }

    /// patternOffset: このセクションより前にあるパターン数。通しの件数で広告の位置を決める
    private func studyGrid(_ section: StudySection, patternOffset: Int, totalPatterns: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label(section.title, systemImage: section.systemImage)
                        .font(.headline)
                        .foregroundStyle(section.color)
                    Spacer()
                    Text("\(section.patterns.count)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                // 通し番号が8の倍数になる位置でグリッドを区切る
                let per = Self.studyPatternsPerAd
                let firstCut = (per - patternOffset % per) % per
                let cuts = stride(from: firstCut == 0 ? per : firstCut, to: section.patterns.count, by: per).map { $0 }
                let bounds = [0] + cuts + [section.patterns.count]
                let chunks = zip(bounds, bounds.dropFirst()).map { Array(section.patterns[$0..<$1]) }
                let chunkEnds = Array(bounds.dropFirst())
                ForEach(Array(chunks.enumerated()), id: \.offset) { chunkIndex, chunk in
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(chunk, id: \.pattern) { pattern in
                        let color: Color = pattern.direction == "bullish" ? .red : .blue
                        NavigationLink {
                            PatternStudyDetailView(pattern: pattern)
                        } label: {
                            VStack(spacing: 6) {
                                if let candles = idealPatternCandles[pattern.pattern] {
                                    CandlestickChartView(
                                        candles: candles,
                                        dividerIndex: nil,
                                        showsVolume: false,
                                        showsMovingAverages: false
                                    )
                                    .frame(height: 80)
                                }
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(color)
                                        .frame(width: 7, height: 7)
                                    Text(pattern.localizedName)
                                        .font(.caption)
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                    let mistakes = patternMistakes[pattern.pattern] ?? 0
                                    if mistakes > 0 {
                                        Spacer(minLength: 0)
                                        Image(systemName: "flame.fill")
                                            .font(.caption2)
                                            .foregroundStyle(.orange)
                                    }
                                }
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
                let end = patternOffset + chunkEnds[chunkIndex]
                if end % per == 0, end < totalPatterns, let ad = studyAd(slot: end / per - 1) {
                    StudyNativeAdCard(nativeAd: ad)
                }
                }
        }
    }

    private var quizScreen: some View {
        VStack(spacing: 0) {
            // ヘッダー
            if let pattern = currentPattern {
                HStack(spacing: 12) {
                    Button {
                        returnToTitle()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.subheadline.bold())
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 8) {
                            if showAnswer {
                                Circle()
                                    .fill(pattern.direction == "bullish" ? Color.red : Color.blue)
                                    .frame(width: 14, height: 14)
                            }
                            Text(showAnswer ? pattern.localizedName : "???")
                                .font(.title2).bold()
                            if showAnswer {
                                Text(signalLabel(for: pattern.direction))
                                    .font(.caption).bold()
                                    .foregroundStyle(pattern.direction == "bullish" ? .red : .blue)
                            }
                        }
                        Text(quizSubtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        if let limit = questionLimit {
                            Text("\(questionNumber)/\(limit)")
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        if currentStreak >= 2 {
                            HStack(spacing: 2) {
                                Image(systemName: "bolt.fill")
                                    .font(.caption2)
                                Text("\(currentStreak)連続")
                                    .font(.caption.monospacedDigit())
                            }
                            .foregroundStyle(.orange)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }

            if let limit = questionLimit {
                GeometryReader { geo in
                    let progress = CGFloat(questionNumber) / CGFloat(limit)
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color(.systemFill))
                        Rectangle()
                            .fill(Color.accentColor)
                            .frame(width: geo.size.width * progress)
                            .animation(.easeInOut(duration: 0.3), value: progress)
                    }
                }
                .frame(height: 3)
            } else {
                Divider()
            }

            // チャート
            if let error = errorMessage {
                Spacer()
                Text(error)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
                Spacer()
            } else if displayCandles.isEmpty {
                Spacer()
                ProgressView("データ読み込み中...")
                Spacer()
            } else {
                CandlestickChartView(
                    candles: displayCandles,
                    dividerIndex: dividerIndex,
                    showsVolume: quizChartSource == .examples,
                    showsMovingAverages: quizChartSource == .examples
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }

            Divider()

            // クイズ操作
            VStack(spacing: 12) {
                if currentPattern != nil {
                    if !showAnswer {
                        Text(quizMode.prompt)
                            .font(.headline)

                        LazyVGrid(
                            columns: [GridItem(.flexible()), GridItem(.flexible())],
                            spacing: 10
                        ) {
                            ForEach(answerOptions, id: \.self) { answer in
                                Button {
                                    submitAnswer(answer)
                                } label: {
                                    Text(answerLabel(for: answer))
                                        .frame(maxWidth: .infinity, minHeight: 44)
                                        .lineLimit(2)
                                        .minimumScaleFactor(0.8)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    } else if let pattern = currentPattern, let isCorrect {
                        Label(
                            isCorrect ? String(localized: "正解！") : String(localized: "不正解"),
                            systemImage: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill"
                        )
                        .font(.headline)
                        .foregroundStyle(isCorrect ? Color.green : Color.orange)

                        if !isCorrect, let correctAnswer {
                            Text("正解: \(answerLabel(for: correctAnswer))")
                                .font(.subheadline).bold()
                        }

                        Text(pattern.localizedDescription)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Button {
                            nextQuestion()
                        } label: {
                            Text(isLastQuestion ? String(localized: "結果を見る") : String(localized: "次の問題"))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(isCompletingQuiz)
                    }
                }
            }
            .frame(maxWidth: 600)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private func loadAllPatterns() {
        var loaded: [QuizPattern] = []
        for name in patternNames {
            guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
                  let data = try? Data(contentsOf: url),
                  let pattern = try? JSONDecoder().decode(QuizPattern.self, from: data) else {
                continue
            }
            loaded.append(pattern)
        }
        if loaded.isEmpty {
            errorMessage = String(localized: "JSONが見つかりません。\nXcodeで全パターンのJSONをターゲットに追加してください。", comment: "開発者向けのエラー表示")
            return
        }
        allPatterns = loaded
        pickRandom()
    }

    private func pickRandom() {
        if isDailyChallenge {
            guard !dailyQueue.isEmpty else { return }
            let question = dailyQueue.removeFirst()
            currentPattern = question.pattern
            currentExample = question.example
            patternChoices = question.choices
            return
        }

        let pattern: QuizPattern
        if !weaknessMode && quizChartSource == .ideals {
            if patternQueue.isEmpty { buildPatternQueue() }
            guard !patternQueue.isEmpty else { return }
            pattern = patternQueue.removeFirst()
        } else {
            let available: [QuizPattern]
            switch quizChartSource {
            case .examples:
                available = allPatterns.filter { !$0.examples.isEmpty }
            case .ideals:
                available = allPatterns.filter { !(idealPatternCandles[$0.pattern] ?? []).isEmpty }
            }
            let candidates = available.count > 1
                ? available.filter { $0.pattern != currentPattern?.pattern }
                : available
            guard let picked = weaknessMode
                ? weightedRandom(from: candidates)
                : candidates.randomElement()
            else { return }
            pattern = picked
        }
        currentPattern = pattern
        currentExample = quizChartSource == .examples ? pattern.examples.randomElement() : nil
        patternChoices = makePatternChoices(correctPattern: pattern.pattern)
    }

#if DEBUG
    private func configureScreenshotStateIfNeeded() {
        guard let argument = ProcessInfo.processInfo.arguments.first(where: {
            $0.hasPrefix("--screenshot-state=")
        }) else { return }

        let state = String(argument.dropFirst("--screenshot-state=".count))

        // スクショごとに見た目が被らないよう、画面ごとに別のパターンを表示する
        let screenshotPatterns: [String: (pattern: String, choices: [String])] = [
            "direction": ("宵の明星", ["宵の明星", "明けの明星", "三羽烏", "赤三兵"]),
            "pattern": ("陽の包み線", ["陽のはらみ線", "陽の包み線", "毛抜き底", "切り込み線"]),
            "answer": ("三羽烏", ["三羽烏", "赤三兵", "宵の明星", "明けの明星"]),
            "ideal": ("赤三兵", ["赤三兵", "三羽烏", "明けの明星", "宵の明星"])
        ]
        let screenshotPattern = screenshotPatterns[state] ?? screenshotPatterns["ideal"]!

        if let pattern = allPatterns.first(where: { $0.pattern == screenshotPattern.pattern }),
           let example = pattern.examples.first {
            currentPattern = pattern
            currentExample = example
            patternChoices = screenshotPattern.choices
        }

        selectedAnswer = nil
        showAnswer = false
        questionNumber = 0

        switch state {
        case "direction":
            quizMode = .direction
            appScreen = .quiz
        case "pattern":
            quizMode = .patternName
            appScreen = .quiz
        case "answer":
            quizMode = .direction
            selectedAnswer = currentPattern?.direction
            showAnswer = true
            questionNumber = 1
            appScreen = .quiz
        case "ideal":
            quizChartSource = .ideals
            quizMode = .patternName
            currentExample = nil
            appScreen = .quiz
        case "study":
            selectedTab = .study
            appScreen = .title
        case "settings":
            selectedTab = .settings
            appScreen = .title
        case "results":
            // 間違いが多くて下に長くなる結果画面を確認するためのダミー結果
            quizChartSource = .ideals
            quizMode = .patternName
            questionResults = allPatterns.prefix(10).enumerated().map { index, pattern in
                let isCorrect = index % 3 == 0
                return QuestionResult(
                    questionNumber: index + 1,
                    patternID: pattern.pattern,
                    patternName: pattern.localizedName,
                    patternDescription: pattern.localizedDescription,
                    signalDirection: pattern.direction,
                    chartSubtitle: String(localized: "お手本チャート（模式図）"),
                    candles: idealPatternCandles[pattern.pattern] ?? [],
                    dividerIndex: nil,
                    showsMarketDetails: false,
                    selectedAnswer: isCorrect ? pattern.localizedName : allPatterns[(index + 1) % allPatterns.count].localizedName,
                    correctAnswer: pattern.localizedName,
                    isCorrect: isCorrect
                )
            }
            questionNumber = questionResults.count
            correctCount = questionResults.filter(\.isCorrect).count
            isIncorrectResultsExpanded = true
            appScreen = .results
        default:
            appScreen = .title
        }
    }
#endif

    private func makePatternChoices(correctPattern: String) -> [String] {
        let distractors = allPatterns
            .map(\.pattern)
            .filter { $0 != correctPattern }
            .shuffled()
            .prefix(3)
        return ([correctPattern] + Array(distractors)).shuffled()
    }

    private func answerLabel(for answer: String) -> String {
        switch answer {
        case "bullish":
            return String(localized: "上昇 ↗", comment: "回答ボタン: 上昇")
        case "bearish":
            return String(localized: "下落 ↘", comment: "回答ボタン: 下落")
        default:
            return PatternText.name(for: answer)
        }
    }

    private var quizSubtitle: String {
        switch quizChartSource {
        case .examples:
            guard let ex = currentExample else { return String(localized: "実例チャート") }
            return "\(ex.ticker) \(ex.name)  \(ex.quizCandles.last?.date ?? "")"
        case .ideals:
            return String(localized: "お手本チャート（模式図）")
        }
    }

    private func submitAnswer(_ answer: String) {
        guard !showAnswer else { return }

        let isCorrect = answer == correctAnswer
        let feedbackGenerator = UINotificationFeedbackGenerator()
        feedbackGenerator.notificationOccurred(isCorrect ? .success : .error)
        SoundEffectPlayer.shared.play(isCorrect ? .correct : .wrong)

        withAnimation {
            selectedAnswer = answer
            showAnswer = true
            questionNumber += 1
        }
    }

    private var resultsScreen: some View {
        NavigationStack {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: correctCount > (questionNumber / 2) ? "star.fill" : "chart.xyaxis.line")
                    .font(.system(size: 64))
                    .foregroundStyle(correctCount > (questionNumber / 2) ? .yellow : .secondary)

                VStack(spacing: 8) {
                    Text(isDailyChallenge ? String(localized: "デイリーチャレンジ完了！") : String(localized: "セット終了！"))
                        .font(.largeTitle.bold())
                    if isDailyChallenge {
                        Text(DailyChallenge.emojiSummary(questionResults.map(\.isCorrect)))
                            .font(.title)
                        if dailyStreak > 0 {
                            Label("\(dailyStreak)日連続", systemImage: "flame.fill")
                                .font(.headline)
                                .foregroundStyle(.orange)
                        }
                    }
                    Text("\(questionNumber)問中 \(correctCount)問正解")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("正解率 \(questionNumber > 0 ? Double(correctCount) / Double(questionNumber) : 0, format: .percent.precision(.fractionLength(0)))", comment: "結果画面の正解率")
                        .font(.title3.bold())
                        .foregroundStyle(correctCount >= questionNumber * 7 / 10 ? .green : .orange)
                    if bestStreakThisSession >= 2 {
                        HStack(spacing: 4) {
                            Image(systemName: "bolt.fill")
                                .foregroundStyle(.orange)
                            Text("最大\(bestStreakThisSession)連続正解")
                                .foregroundStyle(.orange)
                            if bestStreakThisSession == allTimeBestStreak {
                                Text("🏆 自己ベスト！")
                                    .foregroundStyle(.yellow)
                            }
                        }
                        .font(.subheadline.bold())
                    }
                }

                VStack(spacing: 12) {
                    if !isDailyChallenge {
                        Button {
                            startQuiz()
                        } label: {
                            Label("もう一度", systemImage: "arrow.clockwise")
                                .font(.headline)
                                .frame(maxWidth: .infinity, minHeight: 50)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(isCompletingQuiz)
                    }

                    Button {
                        let certificate = ResultCertificateView(
                            correctCount: correctCount,
                            questionCount: questionNumber,
                            bestStreak: bestStreakThisSession,
                            mode: isDailyChallenge ? String(localized: "デイリーチャレンジ") : quizMode.title,
                            chartSource: quizChartSource.label,
                            date: resultDate
                        )
                        let renderer = ImageRenderer(content: certificate)
                        renderer.scale = 3
                        if let image = renderer.uiImage {
                            shareImage = ResultShareImage(image: image, text: resultShareText)
                        } else {
                            showsShareError = true
                        }
                    } label: {
                        Label("結果をSNSで共有", systemImage: "square.and.arrow.up")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(isCompletingQuiz)
                }
                .frame(maxWidth: 400)

                VStack(alignment: .leading, spacing: 12) {
                    Label("チャートを振り返る", systemImage: "chart.xyaxis.line")
                        .font(.title2.bold())

                    resultSection(
                        title: "間違えたチャート",
                        systemImage: "xmark.circle.fill",
                        color: .orange,
                        results: incorrectQuestionResults,
                        isExpanded: $isIncorrectResultsExpanded
                    )

                    resultSection(
                        title: "正解したチャート",
                        systemImage: "checkmark.circle.fill",
                        color: .green,
                        results: correctQuestionResults,
                        isExpanded: $isCorrectResultsExpanded
                    )
                }
                .frame(maxWidth: 760)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity)
        }
        .background(Color.secondary.opacity(0.04).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // 振り返りのチャートを下までスクロールしても、すぐタイトルに戻れるようにする
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    returnToTitle()
                } label: {
                    Label("タイトル", systemImage: "chevron.left")
                }
                .disabled(isCompletingQuiz)
            }
        }
        } // NavigationStack
        .sheet(item: $shareImage) { item in
            ResultShareSheet(item: item)
        }
        .alert("共有画像を作成できませんでした", isPresented: $showsShareError) {
            Button("閉じる", role: .cancel) { }
        } message: {
            Text("もう一度お試しください。")
        }
    }

    private func resultSection(
        title: LocalizedStringKey,
        systemImage: String,
        color: Color,
        results: [QuestionResult],
        isExpanded: Binding<Bool>
    ) -> some View {
        DisclosureGroup(isExpanded: isExpanded) {
            if results.isEmpty {
                Text("該当するチャートはありません")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 12)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(results) { result in
                        resultChartCard(result)
                    }
                }
                .padding(.top, 12)
            }
        } label: {
            HStack {
                Label(title, systemImage: systemImage)
                    .font(.headline)
                    .foregroundStyle(color)
                Spacer()
                Text("\(results.count)問")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func resultChartCard(_ result: QuestionResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("第\(result.questionNumber)問")
                    .font(.caption.bold())
                    .foregroundStyle(result.isCorrect ? .green : .orange)
                Text(result.patternName)
                    .font(.headline)
                Spacer()
                Text(signalLabel(for: result.signalDirection))
                    .font(.caption.bold())
                    .foregroundStyle(result.signalDirection == "bullish" ? .red : .blue)
            }

            Text(result.chartSubtitle)
                .font(.caption)
                .foregroundStyle(.secondary)

            CandlestickChartView(
                candles: result.candles,
                dividerIndex: result.dividerIndex,
                showsVolume: result.showsMarketDetails,
                showsMovingAverages: result.showsMarketDetails
            )
            .frame(height: 180)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.06))
            )

            VStack(alignment: .leading, spacing: 4) {
                Text("あなたの回答: \(result.selectedAnswer)")
                    .foregroundStyle(result.isCorrect ? .green : .orange)
                if !result.isCorrect {
                    Text("正解: \(result.correctAnswer)")
                        .bold()
                }
                Text(result.patternDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)

            // 基本形で解いたときも、実際の相場でどう現れるかを図鑑の実例で確認できるようにする
            if let pattern = allPatterns.first(where: { $0.pattern == result.patternID }),
               !pattern.examples.isEmpty {
                NavigationLink {
                    PatternStudyDetailView(pattern: pattern)
                } label: {
                    HStack {
                        Label("実戦チャートの実例を見る", systemImage: "chart.xyaxis.line")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                    }
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity, minHeight: 36)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    (result.isCorrect ? Color.green : Color.orange).opacity(0.25),
                    lineWidth: 1
                )
        )
    }

    private func startQuiz() {
        showAnswer = false
        selectedAnswer = nil
        isCompletingQuiz = false
        questionNumber = 0
        correctCount = 0
        currentStreak = 0
        bestStreakThisSession = 0
        questionResults = []
        isCorrectResultsExpanded = false
        isIncorrectResultsExpanded = false
        interstitialAdManager.loadAd()
        SoundEffectPlayer.shared.prepare()
        buildPatternQueue()
        pickRandom()
        withAnimation(.easeInOut(duration: 0.25)) {
            appScreen = .quiz
        }
    }

    private func startDailyChallenge() {
        guard !isDailyCompletedToday else { return }
        let now = Date()
        let questions = DailyChallenge.questions(for: now, from: allPatterns)
        guard !questions.isEmpty else { return }

        // タイトル画面の設定はデイリー終了後に元へ戻す
        if settingsBeforeDaily == nil {
            settingsBeforeDaily = (quizChartSource, quizMode, questionLimit, weaknessMode)
        }
        isDailyChallenge = true
        dailyStartDate = now
        dailyQueue = questions
        quizChartSource = .examples
        quizMode = .patternName
        questionLimit = questions.count
        weaknessMode = false
        startQuiz()
    }

    private func completeDailyChallenge() {
        // 日付をまたいで回答しても、開始した日の分として記録する
        let day = DailyChallenge.dayKey(for: dailyStartDate)
        guard dailyLastCompletedDay != day else { return }
        dailyStreak = dailyLastCompletedDay == DailyChallenge.previousDayKey(of: dailyStartDate)
            ? dailyStreak + 1
            : 1
        dailyBestStreak = max(dailyBestStreak, dailyStreak)
        dailyLastCompletedDay = day
        dailyLastResults = questionResults.map { $0.isCorrect ? "1" : "0" }.joined()
    }

    private func buildPatternQueue() {
        guard quizChartSource == .ideals else {
            patternQueue = []
            return
        }
        let available = allPatterns.filter { !(idealPatternCandles[$0.pattern] ?? []).isEmpty }
        patternQueue = available.shuffled()
    }

    private func returnToTitle() {
        if let saved = settingsBeforeDaily {
            quizChartSource = saved.source
            quizMode = saved.mode
            questionLimit = saved.limit
            weaknessMode = saved.weakness
            settingsBeforeDaily = nil
        }
        isDailyChallenge = false
        dailyQueue = []
        todayKey = DailyChallenge.dayKey()
        withAnimation(.easeInOut(duration: 0.25)) {
            appScreen = .title
            showAnswer = false
            selectedAnswer = nil
            isCompletingQuiz = false
        }
    }

    private func nextQuestion() {
        guard !isCompletingQuiz else { return }

        if let pattern = currentPattern, let correct = isCorrect {
            saveQuestionResult(pattern: pattern, isCorrect: correct)
            if correct {
                correctCount += 1
                currentStreak += 1
                if currentStreak > bestStreakThisSession { bestStreakThisSession = currentStreak }
                if currentStreak > allTimeBestStreak { allTimeBestStreak = currentStreak }
            } else {
                currentStreak = 0
            }
            recordResult(patternName: pattern.pattern, correct: correct)
        }

        if isLastQuestion {
            isIncorrectResultsExpanded = !incorrectQuestionResults.isEmpty
            isCorrectResultsExpanded = incorrectQuestionResults.isEmpty && !correctQuestionResults.isEmpty
            if isDailyChallenge { completeDailyChallenge() }

            // 先に結果画面へ切り替えてから広告を出し、閉じたときに最後の問題が一瞬見えないようにする
            isCompletingQuiz = true
            showAnswer = false
            selectedAnswer = nil
            resultDate = Date()
            appScreen = .results

            if shouldRequestReviewForCurrentVersion {
                lastReviewRequestVersion = currentAppVersion
                Task { @MainActor in
                    // 結果画面へ切り替わってからレビュー依頼を表示する
                    try? await Task.sleep(for: .milliseconds(500))
                    requestReview()
                    isCompletingQuiz = false
                }
                return
            }

            Task { @MainActor in
                interstitialAdManager.present {
                    isCompletingQuiz = false
                }
            }
            return
        }

        showAnswer = false
        selectedAnswer = nil
        pickRandom()
    }

    private func saveQuestionResult(pattern: QuizPattern, isCorrect: Bool) {
        guard let selectedAnswer, let correctAnswer else { return }

        questionResults.append(
            QuestionResult(
                questionNumber: questionNumber,
                patternID: pattern.pattern,
                patternName: pattern.localizedName,
                patternDescription: pattern.localizedDescription,
                signalDirection: pattern.direction,
                chartSubtitle: quizSubtitle,
                candles: displayCandles,
                dividerIndex: dividerIndex,
                showsMarketDetails: quizChartSource == .examples,
                selectedAnswer: answerLabel(for: selectedAnswer),
                correctAnswer: answerLabel(for: correctAnswer),
                isCorrect: isCorrect
            )
        )
    }

    private var currentAppVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "unknown"
    }

    private var shouldRequestReviewForCurrentVersion: Bool {
        questionLimit != nil && lastReviewRequestVersion != currentAppVersion
    }
}

private struct PatternStudyDetailView: View {
    let pattern: QuizPattern

    @State private var exampleIndex = 0

    private var signalColor: Color {
        pattern.direction == "bullish" ? .red : .blue
    }

    private var signalLabel: String {
        SakataChartQuiz.signalLabel(for: pattern.direction)
    }

    private var currentExample: QuizExample? {
        guard pattern.examples.indices.contains(exampleIndex) else { return nil }
        return pattern.examples[exampleIndex]
    }

    private var displayedCandles: [Candle] {
        guard let currentExample else { return [] }
        return currentExample.quizCandles + currentExample.answerCandles
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(signalColor)
                        .frame(width: 18, height: 18)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(pattern.localizedName)
                            .font(.title.bold())

                        Text(signalLabel)
                            .font(.subheadline.bold())
                            .foregroundStyle(signalColor)
                    }
                }

                studyCard(title: "パターンの意味", systemImage: "book.closed.fill") {
                    Text(pattern.localizedDescription)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let idealCandles = idealPatternCandles[pattern.pattern], !idealCandles.isEmpty {
                    studyCard(title: "手本チャート（模式図）", systemImage: "star.fill") {
                        CandlestickChartView(
                            candles: idealCandles,
                            dividerIndex: nil,
                            showsVolume: false,
                            showsMovingAverages: false
                        )
                            .frame(height: 280)
                    }
                }

                if let currentExample {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("実例チャート")
                                    .font(.headline)

                                Text("\(currentExample.ticker)  \(currentExample.name)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        CandlestickChartView(
                            candles: displayedCandles,
                            dividerIndex: currentExample.quizCandles.count
                        )
                        .frame(height: 280)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.secondary.opacity(0.06))
                        )

                        HStack(spacing: 16) {
                            Label("パターン成立まで", systemImage: "chart.xyaxis.line")
                            Label("その後（薄色）", systemImage: "arrow.right")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        if pattern.examples.count > 1 {
                            HStack {
                                Button {
                                    showPreviousExample()
                                } label: {
                                    Label("前の実例", systemImage: "chevron.left")
                                }
                                .disabled(exampleIndex == 0)

                                Spacer()

                                Text("実例 \(exampleIndex + 1) / \(pattern.examples.count)")
                                    .font(.footnote.monospacedDigit())
                                    .foregroundStyle(.secondary)

                                Spacer()

                                Button {
                                    showNextExample()
                                } label: {
                                    Label("次の実例", systemImage: "chevron.right")
                                        .labelStyle(.titleAndIcon)
                                }
                                .disabled(exampleIndex == pattern.examples.count - 1)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                } else {
                    ContentUnavailableView(
                        "実例がありません",
                        systemImage: "chart.xyaxis.line",
                        description: Text("このパターンの実例データを読み込めませんでした。")
                    )
                }

                studyCard(title: "見方", systemImage: "lightbulb.fill") {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(
                            signalLabel,
                            systemImage: pattern.direction == "bullish" ? "arrow.up.right" : "arrow.down.right"
                        )
                        .foregroundStyle(signalColor)

                        Text("オレンジ色の縦線より左がパターン成立まで、右の薄いローソク足が成立後の値動きです。")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: 760)
            .padding(20)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(pattern.localizedName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func showPreviousExample() {
        guard exampleIndex > 0 else { return }
        withAnimation {
            exampleIndex -= 1
        }
    }

    private func showNextExample() {
        guard exampleIndex < pattern.examples.count - 1 else { return }
        withAnimation {
            exampleIndex += 1
        }
    }

    private func studyCard<Content: View>(
        title: LocalizedStringKey,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.headline)

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.secondary.opacity(0.06))
        )
    }
}

#Preview {
    ContentView(adRemoval: AdRemovalSubscription())
}
