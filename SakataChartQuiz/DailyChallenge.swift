import Foundation

/// 日付から決まる「今日の問題」。同じ日・同じアプリバージョンなら全ユーザーで同じ問題になる。
struct DailyQuestion {
    let pattern: QuizPattern
    let example: QuizExample
    let choices: [String]
}

enum DailyChallenge {
    static let questionCount = 5

    /// 端末のローカル日付を "yyyy-MM-dd" で表す
    static func dayKey(for date: Date = Date(), calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func previousDayKey(of date: Date = Date(), calendar: Calendar = .current) -> String {
        let yesterday = calendar.date(byAdding: .day, value: -1, to: date) ?? date
        return dayKey(for: yesterday, calendar: calendar)
    }

    /// 標準ライブラリの shuffled() は実装が保証されないため、独自の乱数とシャッフルで再現性を確保する
    static func questions(for date: Date = Date(), from patterns: [QuizPattern]) -> [DailyQuestion] {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let seed = UInt64((c.year ?? 0) * 10_000 + (c.month ?? 0) * 100 + (c.day ?? 0))
        var rng = SplitMix64(seed: seed)

        let candidates = patterns.filter { !$0.examples.isEmpty }
        let allNames = patterns.map(\.pattern)
        let picked = rng.shuffle(candidates).prefix(questionCount)

        return picked.map { pattern in
            let example = pattern.examples[rng.index(below: pattern.examples.count)]
            let distractors = rng.shuffle(allNames.filter { $0 != pattern.pattern }).prefix(3)
            let choices = rng.shuffle([pattern.pattern] + distractors)
            return DailyQuestion(pattern: pattern, example: example, choices: choices)
        }
    }

    /// Wordle風の結果表示（例: 🟩🟥🟩🟩🟩）
    static func emojiSummary(_ results: [Bool]) -> String {
        results.map { $0 ? "🟩" : "🟥" }.joined()
    }
}

struct SplitMix64 {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func index(below upperBound: Int) -> Int {
        precondition(upperBound > 0)
        return Int(next() % UInt64(upperBound))
    }

    mutating func shuffle<C: Collection>(_ items: C) -> [C.Element] {
        var array = Array(items)
        guard array.count > 1 else { return array }
        for i in stride(from: array.count - 1, to: 0, by: -1) {
            array.swapAt(i, index(below: i + 1))
        }
        return array
    }
}
