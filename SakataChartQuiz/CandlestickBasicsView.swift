import SwiftUI

struct CandlestickBasicsView: View {
    let adAccess: AdRemovalSubscription.Access
    let canRequestAds: Bool

    @ScaledMetric(relativeTo: .body) private var answerIconSpace: CGFloat = 24
    @State private var pageIndex = 0
    @State private var answers: [Int: BasicsChoice] = [:]
    @State private var showsHint = false
    @State private var isFinished = false

    private static let pages: [BasicsPage] = [
        .lesson(.prices),
        .question(.high), .question(.low),
        .lesson(.bullish),
        .question(.bullishTop), .question(.bullishBottom), .question(.bullishType),
        .lesson(.bearish),
        .question(.bearishTop), .question(.bearishBottom), .question(.bearishType),
        .lesson(.spinningTop), .question(.spinningTopType),
        .lesson(.doji), .question(.dojiType)
    ]

    private var page: BasicsPage { Self.pages[pageIndex] }
    private var selectedAnswer: BasicsChoice? { answers[pageIndex] }
    private var isLastPage: Bool { pageIndex == Self.pages.count - 1 }
    private var reservesBannerSpace: Bool { adAccess != .subscribed }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if isFinished {
                        result
                    } else {
                        ProgressView(value: Double(pageIndex + 1), total: Double(Self.pages.count)) {
                            Text("\(pageIndex + 1) / \(Self.pages.count)")
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityLabel(Text("学習の進み具合"))

                        switch page {
                        case .lesson(let lesson):
                            lessonContent(lesson)
                        case .question(let question):
                            questionContent(question)
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
                .id("basicsTop")
            }
            .onChange(of: pageIndex) {
                showsHint = false
                proxy.scrollTo("basicsTop", anchor: .top)
            }
            .onChange(of: isFinished) { proxy.scrollTo("basicsTop", anchor: .top) }
            .onChange(of: answers.count) { oldValue, newValue in
                if newValue > oldValue {
                    proxy.scrollTo("basicsFeedback")
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                if !isFinished {
                    pageControls
                }
                if reservesBannerSpace {
                    CandlestickBasicsBanner(loadsAd: adAccess == .free && canRequestAds)
                }
            }
        }
        .ignoresSafeArea(.container, edges: reservesBannerSpace ? .bottom : [])
        .navigationTitle("ローソク足の基礎")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarVisibility(.hidden, for: .tabBar)
        .onAppear { SoundEffectPlayer.shared.prepare() }
    }

    private func lessonContent(_ lesson: BasicsLesson) -> some View {
        Group {
            Text(lesson.title)
                .font(.title.bold())
                .accessibilityAddTraits(.isHeader)

            if lesson.showsPrices {
                CandlestickPriceDiagram(sample: lesson.sample)
            } else {
                diagram(sample: lesson.sample)
            }

            Text(lesson.explanation)
        }
    }

    private func questionContent(_ question: BasicsQuestion) -> some View {
        Group {
            Text(question.prompt)
                .font(.title2.bold())
                .accessibilityAddTraits(.isHeader)

            diagram(sample: question.sample, point: question.point)

            VStack(spacing: 8) {
                ForEach(question.choices) { choice in
                    answerButton(choice, for: question)
                }
            }

            if let selectedAnswer {
                feedback(question, isCorrect: selectedAnswer == question.correct)
                    .id("basicsFeedback")
            } else {
                DisclosureGroup("ヒント", isExpanded: $showsHint) {
                    Text(question.hint)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 6)
                }
            }
        }
    }

    private func answerButton(_ choice: BasicsChoice, for question: BasicsQuestion) -> some View {
        let isSelected = selectedAnswer == choice
        let showsCorrect = selectedAnswer != nil && choice == question.correct
        let tint: Color = showsCorrect ? .green : isSelected ? .red : .secondary

        return Button {
            guard selectedAnswer == nil else { return }
            answers[pageIndex] = choice
            SoundEffectPlayer.shared.play(choice == question.correct ? .correct : .wrong)
        } label: {
            Text(choice.title)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 14 + answerIconSpace)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, minHeight: 44)
                .overlay(alignment: .trailing) {
                    Group {
                        if showsCorrect {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .accessibilityLabel(Text("正解"))
                        } else if isSelected {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red)
                                .accessibilityLabel(Text("不正解"))
                        }
                    }
                    .padding(.trailing, 14)
                }
                .foregroundStyle(.primary)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .disabled(selectedAnswer != nil)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func feedback(_ question: BasicsQuestion, isCorrect: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if isCorrect {
                Label("正解", systemImage: "checkmark.circle.fill")
            } else {
                Label("不正解", systemImage: "xmark.circle.fill")
            }

            Text(question.explanation)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background((isCorrect ? Color.green : Color.red).opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }

    private func diagram(sample: BasicsSample, point: BasicsPoint? = nil) -> some View {
        let candle = sample.candle

        return CandlestickChartView(
            candles: [candle],
            dividerIndex: nil,
            showsVolume: false,
            showsMovingAverages: false,
            highlightedPrice: point?.price(in: candle)
        )
        .frame(width: 100, height: 118)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement()
        .accessibilityLabel(Text(sample.description))
        .accessibilityValue(point.map { Text($0.description) } ?? Text(verbatim: ""))
    }

    private var pageControls: some View {
        HStack(spacing: 12) {
            Button {
                pageIndex -= 1
            } label: {
                Label("前へ", systemImage: "chevron.backward")
                    .frame(minHeight: 36)
            }
            .buttonStyle(.bordered)
            .disabled(pageIndex == 0)

            Button {
                if isLastPage {
                    isFinished = true
                } else {
                    pageIndex += 1
                }
            } label: {
                Text(isLastPage ? "結果を見る" : "次へ")
                    .frame(maxWidth: .infinity, minHeight: 36)
            }
            .buttonStyle(.borderedProminent)
            .disabled(page.requiresAnswer && selectedAnswer == nil)
        }
        .frame(maxWidth: 520)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(.bar)
    }

    private var result: some View {
        let questions: [Bool] = Self.pages.enumerated().compactMap { index, page in
            if case .question(let question) = page {
                return answers[index] == question.correct
            }
            return nil
        }
        let correctCount = questions.count(where: { $0 })

        return Group {
            Label("基礎レッスン完了", systemImage: "checkmark.circle")
                .font(.title.bold())
                .accessibilityAddTraits(.isHeader)

            Text("\(questions.count)問中\(correctCount)問正解")
                .font(.title3.monospacedDigit())

            Button("最初から学び直す") {
                pageIndex = 0
                answers = [:]
                isFinished = false
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }
}
