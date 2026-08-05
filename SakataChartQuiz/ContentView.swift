import SwiftUI

struct ContentView: View {
    @State private var allPatterns: [QuizPattern] = []
    @State private var currentPattern: QuizPattern?
    @State private var currentExample: QuizExample?
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

    var body: some View {
        VStack(spacing: 0) {
            // ヘッダー
            if let ex = currentExample, let pattern = currentPattern {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 8) {
                            if showAnswer {
                                Circle()
                                    .fill(pattern.direction == "bullish" ? Color.red : Color.blue)
                                    .frame(width: 14, height: 14)
                            }
                            Text(showAnswer ? pattern.pattern : "？？？")
                                .font(.title2).bold()
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

            // ボタン
            HStack(spacing: 16) {
                if !showAnswer {
                    Button("答えを見る") {
                        withAnimation { showAnswer = true }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                } else {
                    Button("次の問題") {
                        nextQuestion()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    if let pattern = currentPattern {
                        Text(pattern.description)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: 400)
                    }
                }
            }
            .padding(16)
        }
        .onAppear { loadAllPatterns() }
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
    }

    private func nextQuestion() {
        showAnswer = false
        pickRandom()
    }
}

#Preview {
    ContentView()
}
