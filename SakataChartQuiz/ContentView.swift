import SwiftUI

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

struct ContentView: View {
    @State private var allPatterns: [QuizPattern] = []
    @State private var currentPattern: QuizPattern?
    @State private var currentExample: QuizExample?
    @State private var quizMode: QuizMode = .direction
    @State private var isQuizActive = false
    @State private var selectedAnswer: String?
    @State private var patternChoices: [String] = []
    @State private var showAnswer = false
    @State private var errorMessage: String?

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
        guard let ex = currentExample else { return [] }
        return showAnswer ? ex.quizCandles + ex.answerCandles : ex.quizCandles
    }

    private var dividerIndex: Int? {
        guard showAnswer, let ex = currentExample else { return nil }
        return ex.quizCandles.count
    }

    private var resultText: String? {
        guard showAnswer, let ex = currentExample,
              let base = ex.quizCandles.last?.close,
              let last = ex.answerCandles.last?.close else { return nil }
        let pct = (last - base) / base * 100
        let sign = pct >= 0 ? "+" : ""
        return "\(ex.answerCandles.count)日後: \(sign)\(String(format: "%.1f", pct))%"
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

    var body: some View {
        Group {
            if isQuizActive {
                quizScreen
            } else {
                titleScreen
            }
        }
        .onAppear {
            if allPatterns.isEmpty, errorMessage == nil {
                loadAllPatterns()
            }
        }
    }

    private var titleScreen: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 36)

                Image(systemName: "chart.xyaxis.line")
                    .font(.system(size: 64, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)

                VStack(spacing: 8) {
                    Text("酒田チャートクイズ")
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)

                    Text("実際の株価チャートでローソク足パターンを学ぼう")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
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
                    } else {
                        Label("\(allPatterns.count)パターンから出題", systemImage: "checkmark.circle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 36)
            }
            .frame(maxWidth: 600)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
        }
        .background(Color.secondary.opacity(0.04).ignoresSafeArea())
    }

    private var quizScreen: some View {
        VStack(spacing: 0) {
            // ヘッダー
            if let ex = currentExample, let pattern = currentPattern {
                HStack(spacing: 12) {
                    Button {
                        returnToTitle()
                    } label: {
                        Label("タイトル", systemImage: "chevron.left")
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
                        Text("\(ex.ticker) \(ex.name)  \(ex.quizCandles.last?.date ?? "")")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let result = resultText {
                        Text(result)
                            .font(.title3).bold()
                            .foregroundStyle(result.contains("+") ? .red : .blue)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.secondary.opacity(0.1))
                            )
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
                CandlestickChartView(candles: displayCandles, dividerIndex: dividerIndex)
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
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

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
        guard let pattern = allPatterns.randomElement(),
              let example = pattern.examples.randomElement() else { return }
        currentPattern = pattern
        currentExample = example
        patternChoices = makePatternChoices(correctPattern: pattern.pattern)
    }

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

    private func submitAnswer(_ answer: String) {
        guard !showAnswer else { return }
        withAnimation {
            selectedAnswer = answer
            showAnswer = true
        }
    }

    private func startQuiz() {
        showAnswer = false
        selectedAnswer = nil
        pickRandom()
        withAnimation(.easeInOut(duration: 0.25)) {
            isQuizActive = true
        }
    }

    private func returnToTitle() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isQuizActive = false
            showAnswer = false
            selectedAnswer = nil
        }
    }

    private func nextQuestion() {
        showAnswer = false
        selectedAnswer = nil
        pickRandom()
    }
}

#Preview {
    ContentView()
}
