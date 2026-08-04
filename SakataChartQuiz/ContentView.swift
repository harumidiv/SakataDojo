import SwiftUI

struct ContentView: View {
    @State private var quizPattern: QuizPattern?
    @State private var currentExample: QuizExample?
    @State private var showAnswer = false
    @State private var errorMessage: String?

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
            if let ex = currentExample, let pattern = quizPattern {
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
                        nextExample()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    if let pattern = quizPattern {
                        Text(pattern.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: 400)
                    }
                }
            }
            .padding(16)
        }
        .onAppear { loadPattern() }
    }

    private func loadPattern() {
        guard let url = Bundle.main.url(forResource: "赤三兵", withExtension: "json") else {
            errorMessage = "赤三兵.json がバンドルに見つかりません。\nXcodeでファイルをターゲットに追加してください。"
            return
        }
        guard let data = try? Data(contentsOf: url) else {
            errorMessage = "JSONの読み込みに失敗しました。"
            return
        }
        guard let pattern = try? JSONDecoder().decode(QuizPattern.self, from: data) else {
            errorMessage = "JSONのパースに失敗しました。"
            return
        }
        quizPattern = pattern
        currentExample = pattern.examples.randomElement()
    }

    private func nextExample() {
        currentExample = quizPattern?.examples.randomElement()
        showAnswer = false
    }
}

#Preview {
    ContentView()
}
