import SwiftUI

enum BasicsTopic: String, CaseIterable, Identifiable {
    case fundamentals
    case sakataHistory

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .fundamentals: "ローソク足の基本"
        case .sakataHistory: "酒田の相場と酒田五法"
        }
    }

    var detail: LocalizedStringKey {
        switch self {
        case .fundamentals: "始値・高値・安値・終値と、実体やひげをクイズで学ぼう"
        case .sakataHistory: "本間宗久と米相場、酒田五法の成り立ちをまとめて学ぼう"
        }
    }

    var symbol: String {
        switch self {
        case .fundamentals: "chart.bar.xaxis"
        case .sakataHistory: "building.columns"
        }
    }

    var pageRange: ClosedRange<Int> {
        switch self {
        case .fundamentals: 0...18
        case .sakataHistory: 19...21
        }
    }
}

enum BasicsPage {
    case lesson(BasicsLesson)
    case question(BasicsQuestion)

    var requiresAnswer: Bool {
        if case .question = self { return true }
        return false
    }
}

enum BasicsSample {
    case bullish
    case bearish
    case spinningTop
    case doji

    var candle: Candle {
        switch self {
        case .bullish: Candle(date: "1", open: 100, high: 122, low: 92, close: 112, volume: 0)
        case .bearish: Candle(date: "2", open: 112, high: 120, low: 88, close: 100, volume: 0)
        case .spinningTop: Candle(date: "3", open: 101, high: 118, low: 86, close: 105, volume: 0)
        case .doji: Candle(date: "4", open: 100, high: 120, low: 90, close: 100, volume: 0)
        }
    }

    var description: LocalizedStringKey {
        switch self {
        case .bullish: "赤い実体の上下にひげがあるローソク足"
        case .bearish: "青い実体の上下にひげがあるローソク足"
        case .spinningTop: "短い実体と、上下に長いひげがあるローソク足"
        case .doji: "実体がほぼ横線で、上下にひげがあるローソク足"
        }
    }
}

enum BasicsPoint {
    case high
    case low
    case bodyTop
    case bodyBottom
    case bodyMiddle
    case upperWick
    case lowerWick

    var identifiesPart: Bool {
        switch self {
        case .bodyMiddle, .upperWick, .lowerWick: true
        case .high, .low, .bodyTop, .bodyBottom: false
        }
    }

    func price(in candle: Candle) -> Double {
        switch self {
        case .high: candle.high
        case .low: candle.low
        case .bodyTop: max(candle.open, candle.close)
        case .bodyBottom: min(candle.open, candle.close)
        case .bodyMiddle: (candle.open + candle.close) / 2
        case .upperWick: (candle.high + max(candle.open, candle.close)) / 2
        case .lowerWick: (candle.low + min(candle.open, candle.close)) / 2
        }
    }

    var description: LocalizedStringKey {
        switch self {
        case .high: "上ひげの先に印がある図"
        case .low: "下ひげの先に印がある図"
        case .bodyTop: "実体の上端に印がある図"
        case .bodyBottom: "実体の下端に印がある図"
        case .bodyMiddle: "太い部分の中央に印がある図"
        case .upperWick: "上に伸びる細い線の途中に印がある図"
        case .lowerWick: "下に伸びる細い線の途中に印がある図"
        }
    }
}

enum BasicsLesson {
    case prices
    case parts
    case bullish
    case bearish
    case spinningTop
    case doji
    case homma
    case riceMarket
    case sakataGoho

    var title: LocalizedStringKey {
        switch self {
        case .prices: "1本に含まれる4つの価格"
        case .parts: "実体とひげ"
        case .bullish: "陽線の読み方"
        case .bearish: "陰線の読み方"
        case .spinningTop: "コマ足の読み方"
        case .doji: "十字線の読み方"
        case .homma: "本間宗久ってどんな人？"
        case .riceMarket: "酒田と米相場の物語"
        case .sakataGoho: "酒田五法はどう生まれた？"
        }
    }

    var sample: BasicsSample {
        switch self {
        case .prices, .parts, .bullish, .homma, .riceMarket, .sakataGoho: .bullish
        case .bearish: .bearish
        case .spinningTop: .spinningTop
        case .doji: .doji
        }
    }

    var explanationParts: [LocalizedStringResource] {
        switch self {
        case .prices:
            [
                "まずは1本の見方からいこう。1本で、1日など一定期間の値動きを表すんだ。",
                "実体は始値から終値まで。上ひげの先が高値、下ひげの先が安値だよ。",
                "高値や安値が実体の端と重なると、その側のひげは出ないんだ。"
            ]
        case .parts:
            [
                "色のついた太いところが実体だよ。始値から終値までの幅を表しているんだ。",
                "上に伸びた細い線が上ひげで、実体の上端から高値まで。",
                "下に伸びた線が下ひげで、実体の下端から安値までだよ。"
            ]
        case .bullish:
            [
                "終値が始値より高い足を陽線って呼ぶよ。このアプリでは赤色だね。",
                "だから、実体の上端が終値、下端が始値になるんだ。"
            ]
        case .bearish:
            [
                "終値が始値より低い足が陰線だよ。このアプリでは青色で表示しているんだ。",
                "実体の上端が始値、下端が終値になるよ。"
            ]
        case .spinningTop:
            [
                "実体が小さくて、上下のひげが長いね。こんな形をコマ足って呼ぶんだ。",
                "期間中に価格が動いたあと、終値が始値の近くに戻ってきた形だよ。"
            ]
        case .doji:
            [
                "始値と終値が同じか、ほとんど同じだと、実体が横線みたいに細くなるよ。",
                "この形が十字線なんだ。"
            ]
        case .homma:
            [
                "本間宗久は、江戸時代に酒田で生まれた米商人・相場師だよ。本間家の商いを支えたあと、大阪や江戸でも米相場に取り組んだんだ。",
                "相場の経験や教えは後の書物にも伝わっているよ。ローソク足を宗久ひとりが発明した、と言い切れる確かな記録があるわけではないんだ。"
            ]
        case .riceMarket:
            [
                "昔の酒田は、お米が集まる港町。米の値段は暮らしや商いに深く関わっていたんだ。",
                "相場師たちは値動きを観察して、売り買いの目安を探したんだね。ローソク足の読み方も、そんな相場の知恵と結びついて語られてきたよ。"
            ]
        case .sakataGoho:
            [
                "酒田五法は、三山・三川・三空・三兵・三法という値動きの型をまとめた呼び名だよ。相場の流れを、いくつかの形に分けて考えるんだ。",
                "宗久の相場術と結びつけて紹介されることが多いけれど、今の五法が宗久本人によって作られたと断定できる資料は限られているよ。経験則が後の時代に整理されて伝わった、と考えるのが慎重なんだ。"
            ]
        }
    }
}

enum BasicsChoice: String, Identifiable {
    case open, close, high, low
    case body, upperWick, lowerWick
    case bullish, bearish, spinningTop, doji

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .open: "始値"
        case .close: "終値"
        case .high: "高値"
        case .low: "安値"
        case .body: "実体"
        case .upperWick: "上ひげ"
        case .lowerWick: "下ひげ"
        case .bullish: "陽線"
        case .bearish: "陰線"
        case .spinningTop: "コマ足"
        case .doji: "十字線"
        }
    }
}

struct BasicsQuestion {
    let sample: BasicsSample
    var point: BasicsPoint? = nil
    let correct: BasicsChoice
    let choices: [BasicsChoice]
    let hint: LocalizedStringResource
    let explanationParts: [LocalizedStringResource]

    var prompt: LocalizedStringKey {
        guard let point else { return "このローソク足はどの種類？" }
        return point.identifiesPart ? "印が付いている部分の名前は？" : "印が示すのはどの価格？"
    }

    static let high = BasicsQuestion(
        sample: .bullish, point: .high, correct: .high, choices: [.open, .high, .close],
        hint: "実体から上に伸びている細い線の先を見てみよう。そこがいちばん高いところだよ。",
        explanationParts: ["正解、上ひげの先は、この期間でいちばん高かった価格だよ。"]
    )
    static let low = BasicsQuestion(
        sample: .bearish, point: .low, correct: .low, choices: [.high, .close, .low],
        hint: "実体から下に伸びている線の先を見てみよう。",
        explanationParts: ["そう、下ひげの先が、この期間でいちばん低かった価格だよ。"]
    )
    static let body = BasicsQuestion(
        sample: .bullish, point: .bodyMiddle, correct: .body, choices: [.upperWick, .body, .lowerWick],
        hint: "色のついた、太いところに注目してみよう。",
        explanationParts: ["正解。色のついた太い部分が実体で、始値と終値の間を表しているよ。"]
    )
    static let upperWick = BasicsQuestion(
        sample: .bearish, point: .upperWick, correct: .upperWick, choices: [.upperWick, .lowerWick, .body],
        hint: "実体から上に伸びる細い線を探してみよう。",
        explanationParts: ["正解、これが上ひげだよ。", "実体の上端から高値までを表しているんだ。"]
    )
    static let lowerWick = BasicsQuestion(
        sample: .bullish, point: .lowerWick, correct: .lowerWick, choices: [.body, .upperWick, .lowerWick],
        hint: "実体から下に伸びている細い線を探してみよう。",
        explanationParts: ["正解、これが下ひげだよ。", "実体の下端から安値までを表しているんだ。"]
    )
    static let bullishTop = BasicsQuestion(
        sample: .bullish, point: .bodyTop, correct: .close, choices: [.close, .high, .open],
        hint: "陽線は、始値と終値のどっちが高かったかな？",
        explanationParts: ["そう、陽線は終値が始値より高いね。", "だから実体の上端が終値になるんだ。"]
    )
    static let bullishBottom = BasicsQuestion(
        sample: .bullish, point: .bodyBottom, correct: .open, choices: [.low, .open, .close],
        hint: "陽線の実体の下端を見てみよう。上端の終値と比べるとわかるよ。",
        explanationParts: ["正解。陽線の実体の下端は始値だよ。", "下ひげの先が安値だね。"]
    )
    static let bullishType = BasicsQuestion(
        sample: .bullish, correct: .bullish, choices: [.bearish, .bullish],
        hint: "このアプリでは、実体の色がヒントになるよ。",
        explanationParts: ["正解。このアプリでは赤が陽線。", "終値が始値より高くなった印だよ。"]
    )
    static let bearishTop = BasicsQuestion(
        sample: .bearish, point: .bodyTop, correct: .open, choices: [.high, .close, .open],
        hint: "陰線は、始値と終値のどっちが高かったかな？",
        explanationParts: ["そう、陰線は始値のほうが高いね。", "だから実体の上端が始値になるんだ。"]
    )
    static let bearishBottom = BasicsQuestion(
        sample: .bearish, point: .bodyBottom, correct: .close, choices: [.close, .open, .low],
        hint: "陰線の実体の下端を見てみよう。終値と安値は同じかな？",
        explanationParts: ["正解、陰線の実体の下端は終値だよ。", "下ひげの先が安値になるんだ。"]
    )
    static let bearishType = BasicsQuestion(
        sample: .bearish, correct: .bearish, choices: [.bullish, .bearish],
        hint: "このアプリでは、実体の色がヒントになるよ。",
        explanationParts: ["そう、このアプリでは青が陰線。", "終値が始値より低くなった印だよ。"]
    )
    static let spinningTopType = BasicsQuestion(
        sample: .spinningTop, correct: .spinningTop, choices: [.doji, .spinningTop, .bearish],
        hint: "実体の大きさと、上下のひげの長さを比べてみよう。",
        explanationParts: ["正解、コマ足は実体が小さくて、上下にひげがある形だよ。"]
    )
    static let dojiType = BasicsQuestion(
        sample: .doji, correct: .doji, choices: [.spinningTop, .bullish, .doji],
        hint: "始値と終値がほとんど同じなら、実体はどんな形に見えるかな？",
        explanationParts: ["そう、十字線は始値と終値が同じか近くて、", "実体が横線みたいに細く見えるんだ。"]
    )
}
