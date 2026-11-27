import SwiftUI

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

    func price(in candle: Candle) -> Double {
        switch self {
        case .high: candle.high
        case .low: candle.low
        case .bodyTop: max(candle.open, candle.close)
        case .bodyBottom: min(candle.open, candle.close)
        }
    }

    var description: LocalizedStringKey {
        switch self {
        case .high: "上ひげの先に印がある図"
        case .low: "下ひげの先に印がある図"
        case .bodyTop: "実体の上端に印がある図"
        case .bodyBottom: "実体の下端に印がある図"
        }
    }
}

enum BasicsLesson {
    case prices
    case bullish
    case bearish
    case spinningTop
    case doji

    var title: LocalizedStringKey {
        switch self {
        case .prices: "1本に含まれる4つの価格"
        case .bullish: "陽線の読み方"
        case .bearish: "陰線の読み方"
        case .spinningTop: "コマ足の読み方"
        case .doji: "十字線の読み方"
        }
    }

    var sample: BasicsSample {
        switch self {
        case .prices, .bullish: .bullish
        case .bearish: .bearish
        case .spinningTop: .spinningTop
        case .doji: .doji
        }
    }

    var showsPrices: Bool {
        switch self {
        case .prices, .bullish, .bearish: true
        case .spinningTop, .doji: false
        }
    }

    var explanation: LocalizedStringKey {
        switch self {
        case .prices:
            "1本は、1日など一定期間の値動きを表します。実体は最初の価格（始値）から最後の価格（終値）までの範囲です。上ひげの先は高値、下ひげの先は安値です。高値や安値が実体の端と重なる側にはひげが出ません。"
        case .bullish:
            "終値が始値より高いと陽線です。このアプリでは赤で表示します。実体の上端が終値、下端が始値です。"
        case .bearish:
            "終値が始値より低いと陰線です。このアプリでは青で表示します。実体の上端が始値、下端が終値です。"
        case .spinningTop:
            "上下のひげに比べて実体が小さい形をコマ足と呼びます。期間中に価格が動き、終値は始値の近くに戻っています。"
        case .doji:
            "始値と終値が同じかほぼ同じときにできる形が十字線です。実体は横線のように細く見えます。"
        }
    }
}

enum BasicsChoice: String, Identifiable {
    case open, close, high, low
    case bullish, bearish, spinningTop, doji

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .open: "始値"
        case .close: "終値"
        case .high: "高値"
        case .low: "安値"
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
    let hint: LocalizedStringKey
    let explanation: LocalizedStringKey

    var prompt: LocalizedStringKey {
        if point != nil { return "印が示すのはどの価格？" }
        return "このローソク足はどの種類？"
    }

    static let high = BasicsQuestion(
        sample: .bullish, point: .high, correct: .high, choices: [.open, .high, .close],
        hint: "実体より上に伸びる細い線に注目しましょう。",
        explanation: "上ひげの先は、その期間で最も高かった価格です。"
    )
    static let low = BasicsQuestion(
        sample: .bearish, point: .low, correct: .low, choices: [.high, .close, .low],
        hint: "実体より下に伸びる細い線に注目しましょう。",
        explanation: "下ひげの先は、その期間で最も低かった価格です。"
    )
    static let bullishTop = BasicsQuestion(
        sample: .bullish, point: .bodyTop, correct: .close, choices: [.close, .high, .open],
        hint: "陽線では、取引が始まったときより終わったときの価格が上にあります。",
        explanation: "陽線では終値が始値より高く、実体の上端が終値になります。"
    )
    static let bullishBottom = BasicsQuestion(
        sample: .bullish, point: .bodyBottom, correct: .open, choices: [.low, .open, .close],
        hint: "陽線の実体の下端です。上端の終値と比べてみましょう。",
        explanation: "陽線の実体の下端は始値です。下ひげの先が安値です。"
    )
    static let bullishType = BasicsQuestion(
        sample: .bullish, correct: .bullish, choices: [.bearish, .bullish],
        hint: "このアプリでは、実体の色で始値と終値の上下関係を確認できます。",
        explanation: "このアプリでは赤が陽線です。終値が始値を上回ったことを表します。"
    )
    static let bearishTop = BasicsQuestion(
        sample: .bearish, point: .bodyTop, correct: .open, choices: [.high, .close, .open],
        hint: "陰線では、取引が終わったときより始まったときの価格が上にあります。",
        explanation: "陰線では始値が終値より高いため、実体の上端が始値です。"
    )
    static let bearishBottom = BasicsQuestion(
        sample: .bearish, point: .bodyBottom, correct: .close, choices: [.close, .open, .low],
        hint: "陰線では、取引が始まったときより終わったときの価格が下にあります。",
        explanation: "陰線の実体の下端は終値です。下ひげの先が安値です。"
    )
    static let bearishType = BasicsQuestion(
        sample: .bearish, correct: .bearish, choices: [.bullish, .bearish],
        hint: "このアプリでは、実体の色で始値と終値の上下関係を確認できます。",
        explanation: "このアプリでは青が陰線です。終値が始値を下回ったことを表します。"
    )
    static let spinningTopType = BasicsQuestion(
        sample: .spinningTop, correct: .spinningTop, choices: [.doji, .spinningTop, .bearish],
        hint: "上下のひげと、実体の縦の長さを比べてみましょう。",
        explanation: "コマ足は、上下にひげがあり、実体が小さいのが特徴です。"
    )
    static let dojiType = BasicsQuestion(
        sample: .doji, correct: .doji, choices: [.spinningTop, .bullish, .doji],
        hint: "始値と終値がほとんど重なると、実体はどう見えますか？",
        explanation: "十字線は始値と終値が同じかほぼ同じで、実体が横線のように見えます。"
    )
}
