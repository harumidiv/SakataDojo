import SwiftUI

struct ContentView: View {
    @State private var allPatterns: [QuizPattern] = []
    @State private var currentPattern: QuizPattern?
    @State private var currentExample: QuizExample?
    @State private var showAnswer = false
    @State private var errorMessage: String?

    // true = 強いサイン（赤丸）、false = 弱いサイン（青丸）
    private let patternStrength: [String: Bool] = [
        "赤三兵": true,
        "明けの明星": true,
        "三羽烏": true,
        "宵の明星": true,
        "上放れ並び赤": true,
        "上放れ黒二本": true,
        "上放れ赤2本": true,
        "下放れ二本の陰線": true,
        "最後の抱き線陽": true,
        "最後の抱き線陰": true,
        "包み足陽線": true,
        "包み足陰線": true,
        "陽のたすき": false,
        "陰のたすき": false,
        "行き詰まり線": false,
        "はらみ足陽線": false,
        "はらみ足陰線": false,
        "切り込み線": false,
        "毛抜き底": false,
        "毛抜き天井": false,
        "かぶせ線": false,
        "カラカサ": false,
        "トンボ": false,
        "首吊り線": false,
        "トンカチ": false,
        "塔婆": false,
        "上放れ並び黒": false,
        "上放れ十字線": false,
        "上放れ三手放れ寄せ線": false,
        "下放れ並び赤": false,
        "下放れ十字線": false,
        "下放れ三手放れ寄せ線": false,
    ]

    private let patternNames = [
        "赤三兵", "明けの明星", "陽のたすき", "上放れ赤2本",
        "三羽烏", "宵の明星", "陰のたすき", "行き詰まり線",
        "包み足陽線", "はらみ足陽線", "切り込み線", "毛抜き底", "最後の抱き線陽",
        "包み足陰線", "はらみ足陰線", "かぶせ線", "毛抜き天井", "最後の抱き線陰",
        "カラカサ", "トンボ",
        "首吊り線", "トンカチ", "塔婆",
        "上放れ並び赤", "上放れ並び黒", "上放れ黒二本", "上放れ十字線", "上放れ三手放れ寄せ線",
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
                        Text(showAnswer ? pattern.pattern : "？？？")
                            .font(.title2).bold()
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
                        let isStrong = patternStrength[pattern.pattern]
                        HStack(alignment: .top, spacing: 6) {
                            if let strong = isStrong {
                                Circle()
                                    .fill(strong ? Color.red : Color.blue)
                                    .frame(width: 10, height: 10)
                                    .padding(.top, 3)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                if let strong = isStrong {
                                    Text(strong ? "強いサイン" : "弱いサイン")
                                        .font(.caption2).bold()
                                        .foregroundStyle(strong ? .red : .blue)
                                }
                                Text(pattern.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: 400, alignment: .leading)
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
