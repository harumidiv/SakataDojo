import SwiftUI

private enum AppScreen {
    case title
    case quiz
    case results
    case study
}

private enum QuizMode: String, CaseIterable, Identifiable {
    case direction = "上昇／下落"
    case patternName = "パターン名4択"

    var id: Self { self }

    var prompt: String {
        switch self {
        case .direction:
            return "このサインの方向は？"
        case .patternName:
            return "このローソク足パターンは？"
        }
    }

    var description: String {
        switch self {
        case .direction:
            return "チャートを見て、その後に上がるか下がるかを当てます"
        case .patternName:
            return "ローソク足の形から、パターン名を4つの候補から選びます"
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

    var title: String {
        switch self {
        case .examples:
            return "実戦チャートで挑戦"
        case .ideals:
            return "基本形チャートで練習"
        }
    }

    var description: String {
        switch self {
        case .examples:
            return "実際の日本株市場で発生したローソク足パターンです"
        case .ideals:
            return "特徴を強調した模式図で基本形を覚えます"
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

struct ContentView: View {
    @State private var allPatterns: [QuizPattern] = []
    @State private var currentPattern: QuizPattern?
    @State private var currentExample: QuizExample?
    @State private var quizChartSource: QuizChartSource = .examples
    @State private var quizMode: QuizMode = .direction
    @State private var appScreen: AppScreen = .title
    @State private var selectedAnswer: String?
    @State private var patternChoices: [String] = []
    @State private var showAnswer = false
    @State private var studySearchText = ""
    @State private var errorMessage: String?
    @State private var questionLimit: Int? = 10  // nil = 無限
    @State private var questionNumber: Int = 0
    @State private var correctCount: Int = 0
    @State private var patternQueue: [QuizPattern] = []

    private let patternNames = [
        "赤三兵", "明けの明星", "陽のたすき",
        "三羽烏", "宵の明星", "陰のたすき", "行き詰まり線",
        "包み足陽線", "はらみ足陽線", "切り込み線", "毛抜き底", "最後の抱き線陰",
        "包み足陰線", "はらみ足陰線", "かぶせ線", "毛抜き天井", "最後の抱き線陽",
        "カラカサ", "トンボ",
        "首吊り線", "トンカチ", "塔婆",
        "上放れ並び赤", "上放れ並び黒", "上放れ十字線", "上放れ三手放れ寄せ線",
        "下放れ並び赤", "下放れ二本の陰線", "下放れ十字線", "下放れ三手放れ寄せ線"
    ]

    private var displayCandles: [Candle] {
        switch quizChartSource {
        case .examples:
            guard let ex = currentExample else { return [] }
            return showAnswer ? ex.quizCandles + ex.answerCandles : ex.quizCandles
        case .ideals:
            guard let pattern = currentPattern else { return [] }
            return idealPatternCandles[pattern.pattern] ?? []
        }
    }

    private var dividerIndex: Int? {
        guard quizChartSource == .examples else { return nil }
        guard showAnswer, let ex = currentExample else { return nil }
        return ex.quizCandles.count
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

    private var filteredStudyPatterns: [QuizPattern] {
        guard !studySearchText.isEmpty else { return allPatterns }
        return allPatterns.filter {
            $0.pattern.localizedCaseInsensitiveContains(studySearchText)
                || $0.description.localizedCaseInsensitiveContains(studySearchText)
        }
    }

    var body: some View {
        Group {
            switch appScreen {
            case .title:
                titleScreen
            case .quiz:
                quizScreen
            case .results:
                resultsScreen
            case .study:
                studyScreen
            }
        }
        .onAppear {
            if allPatterns.isEmpty, errorMessage == nil {
                loadAllPatterns()
#if DEBUG
                configureScreenshotStateIfNeeded()
#endif
            }
        }
    }

    private var titleScreen: some View {
        NavigationStack {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 36)

                VStack(alignment: .leading, spacing: 12) {
                    Text("チャートを選択")
                        .font(.headline)

                    Picker("チャート", selection: $quizChartSource) {
                        ForEach(QuizChartSource.allCases) { source in
                            Label(source.rawValue, systemImage: source.systemImage)
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
                                    Text(mode.rawValue)
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

                Group {
                    if let error = errorMessage {
                        Text(error)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    } else if allPatterns.isEmpty {
                        ProgressView("問題を読み込み中...")
                    }
                }

                Spacer(minLength: 36)
            }
            .frame(maxWidth: 600)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
        }
        .background(Color.secondary.opacity(0.04).ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    openStudyGuide()
                } label: {
                    Image(systemName: "books.vertical.fill")
                }
                .disabled(allPatterns.isEmpty)
            }
        }
        } // NavigationStack
    }

    private var studyScreen: some View {
        NavigationStack {
            List {
                studySection(
                    title: "上昇サイン",
                    direction: "bullish",
                    color: .red
                )

                studySection(
                    title: "下落サイン",
                    direction: "bearish",
                    color: .blue
                )
            }
            .navigationTitle("パターン図鑑")
            .searchable(text: $studySearchText, prompt: "パターン名や説明を検索")
            .overlay {
                if filteredStudyPatterns.isEmpty {
                    ContentUnavailableView.search(text: studySearchText)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        returnToTitle()
                    } label: {
                        Label("タイトル", systemImage: "chevron.left")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func studySection(title: String, direction: String, color: Color) -> some View {
        let patterns = filteredStudyPatterns.filter { $0.direction == direction }
        if !patterns.isEmpty {
            Section {
                ForEach(patterns, id: \.pattern) { pattern in
                    NavigationLink {
                        PatternStudyDetailView(pattern: pattern)
                    } label: {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(color)
                                .frame(width: 12, height: 12)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(pattern.pattern)
                                    .font(.headline)

                                Text(pattern.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            } header: {
                Label(title, systemImage: direction == "bullish" ? "arrow.up.right" : "arrow.down.right")
                    .foregroundStyle(color)
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
                            Text(showAnswer ? pattern.pattern : "？？？")
                                .font(.title2).bold()
                            if showAnswer {
                                Text(pattern.direction == "bullish" ? "上昇サイン" : "下落サイン")
                                    .font(.caption).bold()
                                    .foregroundStyle(pattern.direction == "bullish" ? .red : .blue)
                            }
                        }
                        Text(quizSubtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let limit = questionLimit {
                        Text("\(questionNumber)/\(limit)")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }

            Divider()

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
                            isCorrect ? "正解！" : "不正解",
                            systemImage: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill"
                        )
                        .font(.headline)
                        .foregroundStyle(isCorrect ? Color.green : Color.orange)

                        if !isCorrect, let correctAnswer {
                            Text("正解: \(answerLabel(for: correctAnswer))")
                                .font(.subheadline).bold()
                        }

                        Text(pattern.description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Button("次の問題") {
                            nextQuestion()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
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
            errorMessage = "JSONが見つかりません。\nXcodeで全パターンのJSONをターゲットに追加してください。"
            return
        }
        allPatterns = loaded
        pickRandom()
    }

    private func pickRandom() {
        let pattern: QuizPattern
        if quizChartSource == .ideals {
            if patternQueue.isEmpty { buildPatternQueue() }
            guard !patternQueue.isEmpty else { return }
            pattern = patternQueue.removeFirst()
        } else {
            let available = allPatterns.filter { !$0.examples.isEmpty }
            let candidates = available.count > 1
                ? available.filter { $0.pattern != currentPattern?.pattern }
                : available
            guard let picked = candidates.randomElement() else { return }
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

        if let pattern = allPatterns.first(where: { $0.pattern == "赤三兵" }),
           let example = pattern.examples.first {
            currentPattern = pattern
            currentExample = example
            patternChoices = ["赤三兵", "三羽烏", "明けの明星", "宵の明星"]
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
            appScreen = .study
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
            return "上昇 ↗"
        case "bearish":
            return "下落 ↘"
        default:
            return answer
        }
    }

    private var quizSubtitle: String {
        switch quizChartSource {
        case .examples:
            guard let ex = currentExample else { return "実例チャート" }
            return "\(ex.ticker) \(ex.name)  \(ex.quizCandles.last?.date ?? "")"
        case .ideals:
            return "お手本チャート（模式図）"
        }
    }

    private func submitAnswer(_ answer: String) {
        guard !showAnswer else { return }
        withAnimation {
            selectedAnswer = answer
            showAnswer = true
            questionNumber += 1
        }
    }

    private var resultsScreen: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: correctCount > (questionNumber / 2) ? "star.fill" : "chart.xyaxis.line")
                .font(.system(size: 64))
                .foregroundStyle(correctCount > (questionNumber / 2) ? .yellow : .secondary)

            VStack(spacing: 8) {
                Text("セット終了！")
                    .font(.largeTitle.bold())
                Text("\(questionNumber)問中 \(correctCount)問正解")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text(String(format: "正解率 %.0f%%", questionNumber > 0 ? Double(correctCount) / Double(questionNumber) * 100 : 0))
                    .font(.title3.bold())
                    .foregroundStyle(correctCount >= questionNumber * 7 / 10 ? .green : .orange)
            }

            VStack(spacing: 12) {
                Button {
                    startQuiz()
                } label: {
                    Label("もう一度", systemImage: "arrow.clockwise")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button {
                    returnToTitle()
                } label: {
                    Text("タイトルに戻る")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .frame(maxWidth: 400)

            Spacer()
        }
        .padding(.horizontal, 32)
    }

    private func startQuiz() {
        showAnswer = false
        selectedAnswer = nil
        questionNumber = 0
        correctCount = 0
        buildPatternQueue()
        pickRandom()
        withAnimation(.easeInOut(duration: 0.25)) {
            appScreen = .quiz
        }
    }

    private func buildPatternQueue() {
        guard quizChartSource == .ideals else {
            patternQueue = []
            return
        }
        let available = allPatterns.filter { !(idealPatternCandles[$0.pattern] ?? []).isEmpty }
        patternQueue = available.shuffled()
    }

    private func openStudyGuide() {
        studySearchText = ""
        withAnimation(.easeInOut(duration: 0.25)) {
            appScreen = .study
        }
    }

    private func returnToTitle() {
        withAnimation(.easeInOut(duration: 0.25)) {
            appScreen = .title
            showAnswer = false
            selectedAnswer = nil
        }
    }

    private func nextQuestion() {
        if isCorrect == true { correctCount += 1 }
        showAnswer = false
        selectedAnswer = nil
        if let limit = questionLimit, questionNumber >= limit {
            withAnimation(.easeInOut(duration: 0.25)) { appScreen = .results }
            return
        }
        pickRandom()
    }
}

private struct PatternStudyDetailView: View {
    let pattern: QuizPattern

    @State private var exampleIndex = 0

    private var signalColor: Color {
        pattern.direction == "bullish" ? .red : .blue
    }

    private var signalLabel: String {
        pattern.direction == "bullish" ? "上昇サイン" : "下落サイン"
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
                        Text(pattern.pattern)
                            .font(.title.bold())

                        Text(signalLabel)
                            .font(.subheadline.bold())
                            .foregroundStyle(signalColor)
                    }
                }

                studyCard(title: "パターンの意味", systemImage: "book.closed.fill") {
                    Text(pattern.description)
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
        .navigationTitle(pattern.pattern)
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
        title: String,
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
    ContentView()
}
