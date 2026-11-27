import SwiftUI

struct CandlestickBasicsView: View {
    let adAccess: AdRemovalSubscription.Access
    let canRequestAds: Bool

    @ScaledMetric(relativeTo: .body) private var answerIconSpace: CGFloat = 24
    @State private var selectedTopic: BasicsTopic?
    @State private var pageIndex = 0
    @State private var answers: [Int: BasicsChoice] = [:]
    @State private var showsHint = false
    @State private var isFinished = false
    @State private var commentPartIndex = 0

    private static let pages: [BasicsPage] = [
        .lesson(.prices),
        .question(.high), .question(.low),
        .lesson(.parts),
        .question(.body), .question(.upperWick), .question(.lowerWick),
        .lesson(.bullish),
        .question(.bullishTop), .question(.bullishBottom), .question(.bullishType),
        .lesson(.bearish),
        .question(.bearishTop), .question(.bearishBottom), .question(.bearishType),
        .lesson(.spinningTop), .question(.spinningTopType),
        .lesson(.doji), .question(.dojiType),
        .lesson(.homma), .lesson(.riceMarket), .lesson(.sakataGoho)
    ]

    private var activePages: [BasicsPage] {
        guard let selectedTopic else { return [] }
        return Array(Self.pages[selectedTopic.pageRange])
    }
    private var page: BasicsPage { activePages[pageIndex] }
    private var selectedAnswer: BasicsChoice? { answers[pageIndex] }
    private var isLastPage: Bool { pageIndex == activePages.count - 1 }
    private var reservesBannerSpace: Bool { adAccess != .subscribed }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if selectedTopic == nil {
                        topicPicker
                    } else if isFinished {
                        result
                    } else {
                        ProgressView(value: Double(pageIndex + 1), total: Double(activePages.count)) {
                            Text("\(pageIndex + 1) / \(activePages.count)")
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
                commentPartIndex = 0
                proxy.scrollTo("basicsTop", anchor: .top)
            }
            .onChange(of: isFinished) { proxy.scrollTo("basicsTop", anchor: .top) }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                if selectedTopic == nil {
                    // With a banner below, the tanuki walks along the ad's top edge.
                    TopicPickerMascot(footDrop: reservesBannerSpace ? CandlestickBasicsBanner.topPadding : 0)
                        .zIndex(1)
                } else if !isFinished {
                    mascotDock
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        .padding(.bottom, 12)
                        .frame(maxWidth: 560)
                        .frame(maxWidth: .infinity)
                    pageControls
                }
                if reservesBannerSpace {
                    CandlestickBasicsBanner(
                        loadsAd: adAccess == .free && canRequestAds,
                        showsBarBackground: selectedTopic != nil
                    )
                }
            }
            .background {
                // On the topic picker the port's quay carries on behind the banner and into the safe area.
                if selectedTopic == nil {
                    SakataPortGround().ignoresSafeArea()
                } else {
                    Color(uiColor: .systemBackground).ignoresSafeArea()
                }
            }
        }
        .navigationTitle("初心者モード")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(selectedTopic != nil)
        .toolbar {
            if selectedTopic != nil {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        returnToTopicPicker()
                    } label: {
                        Label("テーマ", systemImage: "chevron.backward")
                    }
                    .accessibilityHint("テーマ選択画面に戻る")
                }
            }
        }
        .toolbarVisibility(.hidden, for: .tabBar)
        .onAppear {
            SoundEffectPlayer.shared.prepare()
            MascotVoicePlayer.shared.prepare()
        }
        .onDisappear { MascotVoicePlayer.shared.suspend() }
    }

    private func returnToTopicPicker() {
        selectedTopic = nil
        pageIndex = 0
        answers = [:]
        isFinished = false
        commentPartIndex = 0
    }

    private var topicPicker: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("今日は何を学ぶ？")
                    .font(.title.bold())
                    .accessibilityAddTraits(.isHeader)
                Text("気になるテーマを選んでね。たぬきが案内するよ！")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 4)

            ForEach(BasicsTopic.allCases) { topic in
                Button {
                    selectedTopic = topic
                    pageIndex = 0
                    answers = [:]
                    isFinished = false
                    commentPartIndex = 0
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: topic.symbol)
                            .font(.title2)
                            .foregroundStyle(.orange)
                            .frame(width: 44, height: 44)
                            .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                        VStack(alignment: .leading, spacing: 5) {
                            Text(topic.title)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text(topic.detail)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.forward")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
                    .contentShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func lessonContent(_ lesson: BasicsLesson) -> some View {
        Group {
            Text(lesson.title)
                .font(.title.bold())
                .accessibilityAddTraits(.isHeader)

            switch lesson {
            case .prices, .bullish, .bearish:
                CandlestickAnnotatedDiagram(sample: lesson.sample, style: .prices)
            case .parts:
                CandlestickAnnotatedDiagram(sample: lesson.sample, style: .parts)
            case .spinningTop, .doji:
                diagram(sample: lesson.sample)
            case .homma, .riceMarket, .sakataGoho:
                historyCard(for: lesson)
            }

        }
    }

    private func historyCard(for lesson: BasicsLesson) -> some View {
        let symbol: String
        let eyebrow: LocalizedStringKey
        switch lesson {
        case .homma:
            symbol = "person.crop.circle.badge.questionmark"
            eyebrow = "人物を知ろう"
        case .riceMarket:
            symbol = "shippingbox.fill"
            eyebrow = "江戸時代の酒田"
        case .sakataGoho:
            symbol = "chart.xyaxis.line"
            eyebrow = "相場の見方"
        default:
            symbol = "book.closed.fill"
            eyebrow = "酒田の相場ばなし"
        }

        return VStack(alignment: .leading, spacing: 16) {
            Label(eyebrow, systemImage: symbol)
                .font(.headline)
                .foregroundStyle(.orange)
            Text(historySummary(for: lesson))
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .combine)
    }

    private func historySummary(for lesson: BasicsLesson) -> LocalizedStringKey {
        switch lesson {
        case .homma:
            "酒田生まれの米商人・相場師。大阪や江戸の米相場でも活躍し、その名は相場の教えとともに語り継がれているよ。"
        case .riceMarket:
            "米が集まる港町・酒田では、米の値動きが暮らしと商いを動かした。相場師たちは日々の変化を観察していたんだ。"
        case .sakataGoho:
            "三山・三川・三空・三兵・三法。5つの見方で値動きの型を整理する、酒田に伝わる相場の考え方だよ。"
        default:
            "酒田に伝わる相場の知恵を、たぬきと一緒に見ていこう。"
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

        }
    }

    @ViewBuilder
    private var mascotDock: some View {
        switch page {
        case .lesson(let lesson):
            let parts = lesson.explanationParts
            let asksToReplay = commentPartIndex >= parts.count
            let onTap: (() -> Void)? = parts.count > 1 ? { advanceComment(partCount: parts.count) } : nil
            BasicsMascotMessage(
                mood: .explaining,
                onTap: onTap,
                tapLabel: asksToReplay ? "もう一度聞く？" : "タップでつづき"
            ) {
                if asksToReplay {
                    Text("もう一度聞く？")
                } else {
                    TypingText(text: String(localized: parts[commentPartIndex]))
                }
            }
        case .question(let question):
            if let selectedAnswer {
                let parts = question.explanationParts
                let asksToReplay = commentPartIndex >= parts.count
                let onTap: (() -> Void)? = parts.count > 1 ? { advanceComment(partCount: parts.count) } : nil
                feedback(
                    question,
                    isCorrect: selectedAnswer == question.correct,
                    parts: parts,
                    onTap: onTap,
                    tapLabel: asksToReplay ? "もう一度聞く？" : "タップでつづき",
                    asksToReplay: asksToReplay
                )
            } else {
                BasicsMascotMessage(mood: showsHint ? .thinking : .idle) {
                    DisclosureGroup("ヒント", isExpanded: $showsHint) {
                        // Opening the hint has the tanuki read it out, typing it like its other lines.
                        TypingText(text: String(localized: question.hint))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 6)
                    }
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
            commentPartIndex = 0
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

    private func feedback(
        _ question: BasicsQuestion,
        isCorrect: Bool,
        parts: [LocalizedStringResource],
        onTap: (() -> Void)?,
        tapLabel: LocalizedStringResource,
        asksToReplay: Bool
    ) -> some View {
        BasicsMascotMessage(
            mood: isCorrect ? .celebrating : .thinking,
            fill: (isCorrect ? Color.green : Color.red).opacity(0.10),
            onTap: onTap,
            tapLabel: tapLabel
        ) {
            if isCorrect {
                Label("正解！", systemImage: "checkmark.circle.fill")
            } else {
                Label("おしい！", systemImage: "xmark.circle.fill")
            }

            if asksToReplay {
                Text("もう一度聞く？")
            } else {
                TypingText(text: String(localized: parts[commentPartIndex]))
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func advanceComment(partCount: Int) {
        if commentPartIndex >= partCount {
            commentPartIndex = 0
        } else {
            commentPartIndex += 1
        }
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
            // There's nothing to go back to on the first page, so "次へ" takes the full width.
            if pageIndex > 0 {
                Button {
                    pageIndex -= 1
                } label: {
                    Label("前へ", systemImage: "chevron.backward")
                        .frame(minHeight: 36)
                }
                .buttonStyle(.bordered)
            }

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
        let questions: [Bool] = activePages.enumerated().compactMap { index, page in
            if case .question(let question) = page {
                return answers[index] == question.correct
            }
            return nil
        }
        let correctCount = questions.count(where: { $0 })

        return Group {
            Label("学習完了！", systemImage: "checkmark.circle")
                .font(.title.bold())
                .accessibilityAddTraits(.isHeader)

            if !questions.isEmpty {
                Text("\(questions.count)問中\(correctCount)問正解")
                    .font(.title3.monospacedDigit())
            }

            Button("テーマを選び直す") {
                selectedTopic = nil
                pageIndex = 0
                isFinished = false
                commentPartIndex = 0
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }
}
