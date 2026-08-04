import Foundation

struct Candle: Codable, Identifiable {
    var id: String { date }
    let date: String
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Int
}

struct QuizExample: Codable, Identifiable {
    let id: String
    let ticker: String
    let name: String
    let quizCandles: [Candle]
    let answerCandles: [Candle]

    enum CodingKeys: String, CodingKey {
        case id, ticker, name
        case quizCandles = "quiz_candles"
        case answerCandles = "answer_candles"
    }
}

struct QuizPattern: Codable {
    let pattern: String
    let direction: String
    let description: String
    let examples: [QuizExample]
}
