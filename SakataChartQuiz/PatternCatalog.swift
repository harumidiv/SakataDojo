import Foundation

/// パターン図鑑の分類。酒田五法（三山〜三法）を先に、それ以外の組み合わせを後に並べる
enum PatternCategory: String, CaseIterable, Identifiable {
    case sanzan, sansen, sanku, sanpei, sanpo, gap, twoCandle, oneCandle

    var id: Self { self }

    var title: String { PatternText.category(self) }

    var systemImage: String {
        switch self {
        case .sanzan: return "mountain.2.fill"
        case .sansen: return "sparkles"
        case .sanku: return "arrow.up.and.down.square"
        case .sanpei: return "chart.bar.fill"
        case .sanpo: return "rectangle.split.3x1"
        case .gap: return "arrow.up.right.and.arrow.down.left"
        case .twoCandle: return "square.split.2x1"
        case .oneCandle: return "line.3.horizontal"
        }
    }
}

struct PatternCatalogEntry {
    let id: String
    let category: PatternCategory
    /// 名前順に並べるための読み（日本語表示のときに使う）
    let reading: String
}

enum PatternCatalog {
    /// 全パターン。JSONファイル名・IdealPatternsのキー・苦手記録のキーはこの id を使う
    static let entries: [PatternCatalogEntry] = [
        .init(id: "赤三兵", category: .sanpei, reading: "あかさんぺい"),
        .init(id: "三羽烏", category: .sanpei, reading: "さんばがらす"),
        .init(id: "赤三兵思案星", category: .sanpei, reading: "あかさんぺいしあんぼし"),
        .init(id: "明けの明星", category: .sansen, reading: "あけのみょうじょう"),
        .init(id: "宵の明星", category: .sansen, reading: "よいのみょうじょう"),
        .init(id: "逆三尊", category: .sanzan, reading: "ぎゃくさんぞん"),
        .init(id: "三尊", category: .sanzan, reading: "さんぞん"),
        .init(id: "三空叩き込み", category: .sanku, reading: "さんくうたたきこみ"),
        .init(id: "下放れ三手放れ寄せ線", category: .sanku, reading: "したばなれさんてばなれよせせん"),
        .init(id: "三空踏み上げ", category: .sanku, reading: "さんくうふみあげ"),
        .init(id: "上放れ三手放れ寄せ線", category: .sanku, reading: "うわばなれさんてばなれよせせん"),
        .init(id: "上げ三法", category: .sanpo, reading: "あげさんぽう"),
        .init(id: "下げ三法", category: .sanpo, reading: "さげさんぽう"),
        .init(id: "上放れタスキ", category: .gap, reading: "うわばなれたすき"),
        .init(id: "上放れ並び赤", category: .gap, reading: "うわばなれならびあか"),
        .init(id: "上放れ並び黒", category: .gap, reading: "うわばなれならびくろ"),
        .init(id: "下放れの星", category: .gap, reading: "したばなれのほし"),
        .init(id: "下放れタスキ", category: .gap, reading: "したばなれたすき"),
        .init(id: "下放れ並び赤", category: .gap, reading: "したばなれならびあか"),
        .init(id: "下放れ二本黒", category: .gap, reading: "したばなれにほんぐろ"),
        .init(id: "上放れの星", category: .gap, reading: "うわばなれのほし"),
        .init(id: "陽の包み線", category: .twoCandle, reading: "ようのつつみせん"),
        .init(id: "陽のはらみ線", category: .twoCandle, reading: "ようのはらみせん"),
        .init(id: "切り込み線", category: .twoCandle, reading: "きりこみせん"),
        .init(id: "毛抜き底", category: .twoCandle, reading: "けぬきぞこ"),
        .init(id: "最後の抱き陰線", category: .twoCandle, reading: "さいごのだきいんせん"),
        .init(id: "陽のたすき線", category: .twoCandle, reading: "ようのたすきせん"),
        .init(id: "陰の包み線", category: .twoCandle, reading: "いんのつつみせん"),
        .init(id: "陰のはらみ線", category: .twoCandle, reading: "いんのはらみせん"),
        .init(id: "かぶせ線", category: .twoCandle, reading: "かぶせせん"),
        .init(id: "毛抜き天井", category: .twoCandle, reading: "けぬきてんじょう"),
        .init(id: "最後の抱き陽線", category: .twoCandle, reading: "さいごのだきようせん"),
        .init(id: "陰のたすき線", category: .twoCandle, reading: "いんのたすきせん"),
        .init(id: "あて首線", category: .twoCandle, reading: "あてくびせん"),
        .init(id: "入り首線", category: .twoCandle, reading: "いりくびせん"),
        .init(id: "差し込み線", category: .twoCandle, reading: "さしこみせん"),
        .init(id: "カラカサ", category: .oneCandle, reading: "からかさ"),
        .init(id: "トンボ", category: .oneCandle, reading: "とんぼ"),
        .init(id: "トンカチ", category: .oneCandle, reading: "とんかち"),
        .init(id: "首吊り線", category: .oneCandle, reading: "くびつりせん"),
        .init(id: "流れ星", category: .oneCandle, reading: "ながれぼし"),
        .init(id: "塔婆", category: .oneCandle, reading: "とうば"),
    ]

    static let ids: [String] = entries.map(\.id)

    private static let byID: [String: PatternCatalogEntry] = Dictionary(
        uniqueKeysWithValues: entries.map { ($0.id, $0) }
    )

    static func category(for id: String) -> PatternCategory {
        byID[id]?.category ?? .oneCandle
    }

    static func sortKey(for pattern: QuizPattern) -> String {
        let isJapanese = Locale.current.language.languageCode?.identifier == "ja"
        if isJapanese, let reading = byID[pattern.pattern]?.reading {
            return reading
        }
        return pattern.localizedName
    }

    static func order(of id: String) -> Int {
        ids.firstIndex(of: id) ?? Int.max
    }

    // MARK: - 旧IDからの移行

    /// v1.3以前のID → 現在のID。苦手記録（patternMistakes）のキーを一度だけ付け替える
    static let legacyIDs: [String: String] = [
        "最後の抱き線陰": "最後の抱き陰線",
        "最後の抱き線陽": "最後の抱き陽線",
        "陽のたすき": "上放れタスキ",
        "陰のたすき": "下放れタスキ",
        "下放れ二本の陰線": "下放れ二本黒",
        "包み足陽線": "陽の包み線",
        "包み足陰線": "陰の包み線",
        "はらみ足陽線": "陽のはらみ線",
        "はらみ足陰線": "陰のはらみ線",
        "上放れ十字線": "上放れの星",
        "下放れ十字線": "下放れの星",
        "行き詰まり線": "赤三兵思案星",
        // 旧「トンカチ」は上昇後の上ヒゲ（=流れ星）だった。新しい「トンカチ」は底値圏の別パターン
        "トンカチ": "流れ星",
    ]

    static let currentMigrationVersion = 1

    static func migrateMistakes(_ mistakes: [String: Int]) -> [String: Int] {
        var migrated: [String: Int] = [:]
        for (id, count) in mistakes {
            migrated[legacyIDs[id] ?? id, default: 0] += count
        }
        return migrated
    }
}
