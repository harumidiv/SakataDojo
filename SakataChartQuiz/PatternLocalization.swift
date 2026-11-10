import Foundation

// パターン名・説明文はJSON由来のため、表示用にString Catalogへ載せるキーをここで定義する
// （generate_quiz.pyでJSONを更新したら、このファイルも合わせて更新すること）
extension QuizPattern {
    var localizedName: String { PatternText.name(for: pattern) }

    var localizedDescription: String { PatternText.description(for: pattern) ?? description }
}

enum PatternText {
    static func name(for pattern: String) -> String {
        switch pattern {
        case "かぶせ線": return String(localized: "pattern.name.かぶせ線", defaultValue: "かぶせ線", comment: "酒田五法のローソク足パターン名")
        case "はらみ足陰線": return String(localized: "pattern.name.はらみ足陰線", defaultValue: "はらみ足陰線", comment: "酒田五法のローソク足パターン名")
        case "はらみ足陽線": return String(localized: "pattern.name.はらみ足陽線", defaultValue: "はらみ足陽線", comment: "酒田五法のローソク足パターン名")
        case "カラカサ": return String(localized: "pattern.name.カラカサ", defaultValue: "カラカサ", comment: "酒田五法のローソク足パターン名")
        case "トンカチ": return String(localized: "pattern.name.トンカチ", defaultValue: "トンカチ", comment: "酒田五法のローソク足パターン名")
        case "トンボ": return String(localized: "pattern.name.トンボ", defaultValue: "トンボ", comment: "酒田五法のローソク足パターン名")
        case "三羽烏": return String(localized: "pattern.name.三羽烏", defaultValue: "三羽烏", comment: "酒田五法のローソク足パターン名")
        case "上放れ三手放れ寄せ線": return String(localized: "pattern.name.上放れ三手放れ寄せ線", defaultValue: "上放れ三手放れ寄せ線", comment: "酒田五法のローソク足パターン名")
        case "上放れ並び赤": return String(localized: "pattern.name.上放れ並び赤", defaultValue: "上放れ並び赤", comment: "酒田五法のローソク足パターン名")
        case "上放れ並び黒": return String(localized: "pattern.name.上放れ並び黒", defaultValue: "上放れ並び黒", comment: "酒田五法のローソク足パターン名")
        case "上放れ十字線": return String(localized: "pattern.name.上放れ十字線", defaultValue: "上放れ十字線", comment: "酒田五法のローソク足パターン名")
        case "下放れ三手放れ寄せ線": return String(localized: "pattern.name.下放れ三手放れ寄せ線", defaultValue: "下放れ三手放れ寄せ線", comment: "酒田五法のローソク足パターン名")
        case "下放れ並び赤": return String(localized: "pattern.name.下放れ並び赤", defaultValue: "下放れ並び赤", comment: "酒田五法のローソク足パターン名")
        case "下放れ二本の陰線": return String(localized: "pattern.name.下放れ二本の陰線", defaultValue: "下放れ二本の陰線", comment: "酒田五法のローソク足パターン名")
        case "下放れ十字線": return String(localized: "pattern.name.下放れ十字線", defaultValue: "下放れ十字線", comment: "酒田五法のローソク足パターン名")
        case "切り込み線": return String(localized: "pattern.name.切り込み線", defaultValue: "切り込み線", comment: "酒田五法のローソク足パターン名")
        case "包み足陰線": return String(localized: "pattern.name.包み足陰線", defaultValue: "包み足陰線", comment: "酒田五法のローソク足パターン名")
        case "包み足陽線": return String(localized: "pattern.name.包み足陽線", defaultValue: "包み足陽線", comment: "酒田五法のローソク足パターン名")
        case "塔婆": return String(localized: "pattern.name.塔婆", defaultValue: "塔婆", comment: "酒田五法のローソク足パターン名")
        case "宵の明星": return String(localized: "pattern.name.宵の明星", defaultValue: "宵の明星", comment: "酒田五法のローソク足パターン名")
        case "明けの明星": return String(localized: "pattern.name.明けの明星", defaultValue: "明けの明星", comment: "酒田五法のローソク足パターン名")
        case "最後の抱き線陰": return String(localized: "pattern.name.最後の抱き線陰", defaultValue: "最後の抱き線陰", comment: "酒田五法のローソク足パターン名")
        case "最後の抱き線陽": return String(localized: "pattern.name.最後の抱き線陽", defaultValue: "最後の抱き線陽", comment: "酒田五法のローソク足パターン名")
        case "毛抜き天井": return String(localized: "pattern.name.毛抜き天井", defaultValue: "毛抜き天井", comment: "酒田五法のローソク足パターン名")
        case "毛抜き底": return String(localized: "pattern.name.毛抜き底", defaultValue: "毛抜き底", comment: "酒田五法のローソク足パターン名")
        case "行き詰まり線": return String(localized: "pattern.name.行き詰まり線", defaultValue: "行き詰まり線", comment: "酒田五法のローソク足パターン名")
        case "赤三兵": return String(localized: "pattern.name.赤三兵", defaultValue: "赤三兵", comment: "酒田五法のローソク足パターン名")
        case "陰のたすき": return String(localized: "pattern.name.陰のたすき", defaultValue: "陰のたすき", comment: "酒田五法のローソク足パターン名")
        case "陽のたすき": return String(localized: "pattern.name.陽のたすき", defaultValue: "陽のたすき", comment: "酒田五法のローソク足パターン名")
        case "首吊り線": return String(localized: "pattern.name.首吊り線", defaultValue: "首吊り線", comment: "酒田五法のローソク足パターン名")
        default: return pattern
        }
    }

    static func description(for pattern: String) -> String? {
        switch pattern {
        case "かぶせ線": return String(localized: "pattern.description.かぶせ線", defaultValue: "陽線の後、高く始まって陽線の半値以下まで食い込む陰線。天井からの反落サイン。", comment: "ローソク足パターン「かぶせ線」の説明文")
        case "はらみ足陰線": return String(localized: "pattern.description.はらみ足陰線", defaultValue: "大陽線の実体内に小陰線が収まる。買い勢力の弱まりを示す反転サイン。", comment: "ローソク足パターン「はらみ足陰線」の説明文")
        case "はらみ足陽線": return String(localized: "pattern.description.はらみ足陽線", defaultValue: "大陰線の実体内に小陽線が収まる。売り勢力の弱まりを示す反転サイン。", comment: "ローソク足パターン「はらみ足陽線」の説明文")
        case "カラカサ": return String(localized: "pattern.description.カラカサ", defaultValue: "下降トレンド後の下ヒゲが長い足。底値圏での強い買い意欲を示す反転サイン。", comment: "ローソク足パターン「カラカサ」の説明文")
        case "トンカチ": return String(localized: "pattern.description.トンカチ", defaultValue: "上昇トレンド後の上ヒゲが長い足。高値で売りに押された天井転換サイン。", comment: "ローソク足パターン「トンカチ」の説明文")
        case "トンボ": return String(localized: "pattern.description.トンボ", defaultValue: "下降トレンド後の下ヒゲのみの十字線。売り方の失速と買い方の出現を示す反転サイン。", comment: "ローソク足パターン「トンボ」の説明文")
        case "三羽烏": return String(localized: "pattern.description.三羽烏", defaultValue: "高値圏で3本の陰線が続き、終値が順に下降。上昇から下降への転換サイン。", comment: "ローソク足パターン「三羽烏」の説明文")
        case "上放れ三手放れ寄せ線": return String(localized: "pattern.description.上放れ三手放れ寄せ線", defaultValue: "上方へ窓を空けた後、3本の陽線が高値を更新し、十字線が出現。買い勢力の行き詰まりを示す天井サイン。", comment: "ローソク足パターン「上放れ三手放れ寄せ線」の説明文")
        case "上放れ並び赤": return String(localized: "pattern.description.上放れ並び赤", defaultValue: "ギャップアップ後に同じ大きさの陽線が2本並ぶ。強い買い勢いの継続サイン。", comment: "ローソク足パターン「上放れ並び赤」の説明文")
        case "上放れ並び黒": return String(localized: "pattern.description.上放れ並び黒", defaultValue: "上昇途中のギャップアップ後に同程度の陰線が2本並ぶ。押し目からの上昇継続候補だが、確認を要する弱いサイン。", comment: "ローソク足パターン「上放れ並び黒」の説明文")
        case "上放れ十字線": return String(localized: "pattern.description.上放れ十字線", defaultValue: "上昇中のギャップアップ後に十字線出現。買い勢力の迷いを示す天井転換警戒サイン。", comment: "ローソク足パターン「上放れ十字線」の説明文")
        case "下放れ三手放れ寄せ線": return String(localized: "pattern.description.下放れ三手放れ寄せ線", defaultValue: "下方へ窓を空けた後、3本の陰線が安値を更新し、十字線が出現。売り勢力の行き詰まりを示す底値サイン。", comment: "ローソク足パターン「下放れ三手放れ寄せ線」の説明文")
        case "下放れ並び赤": return String(localized: "pattern.description.下放れ並び赤", defaultValue: "ギャップダウン後に陽線2本が並ぶが窓を埋めきれない。下落継続の意外な継続サイン。", comment: "ローソク足パターン「下放れ並び赤」の説明文")
        case "下放れ二本の陰線": return String(localized: "pattern.description.下放れ二本の陰線", defaultValue: "ギャップダウン後に陰線2本が続く。強い売り勢いの継続を示すサイン。", comment: "ローソク足パターン「下放れ二本の陰線」の説明文")
        case "下放れ十字線": return String(localized: "pattern.description.下放れ十字線", defaultValue: "下降中のギャップダウン後に十字線出現。売り勢力の迷いを示す底値転換警戒サイン。", comment: "ローソク足パターン「下放れ十字線」の説明文")
        case "切り込み線": return String(localized: "pattern.description.切り込み線", defaultValue: "陰線の後、低く始まって陰線の半値以上まで戻す陽線。底からの反発サイン。", comment: "ローソク足パターン「切り込み線」の説明文")
        case "包み足陰線": return String(localized: "pattern.description.包み足陰線", defaultValue: "前日陽線を大陰線が完全に包む。強い売り圧力の下落転換サイン。", comment: "ローソク足パターン「包み足陰線」の説明文")
        case "包み足陽線": return String(localized: "pattern.description.包み足陽線", defaultValue: "前日陰線を大陽線が完全に包む。強い買い圧力の上昇転換サイン。", comment: "ローソク足パターン「包み足陽線」の説明文")
        case "塔婆": return String(localized: "pattern.description.塔婆", defaultValue: "上昇トレンド後の上ヒゲのみの十字線。高値での買い失速と売り圧力を示す天井サイン。", comment: "ローソク足パターン「塔婆」の説明文")
        case "宵の明星": return String(localized: "pattern.description.宵の明星", defaultValue: "大陽線・小実体・大陰線の3本。天井からの下落転換サイン。", comment: "ローソク足パターン「宵の明星」の説明文")
        case "明けの明星": return String(localized: "pattern.description.明けの明星", defaultValue: "大陰線・小実体・大陽線の3本。底打ちからの上昇転換サイン。", comment: "ローソク足パターン「明けの明星」の説明文")
        case "最後の抱き線陰": return String(localized: "pattern.description.最後の抱き線陰", defaultValue: "下降トレンド末期に、小陽線を大陰線が包む形。翌日の上寄りで底入れを確認する買い転換サイン。", comment: "ローソク足パターン「最後の抱き線陰」の説明文")
        case "最後の抱き線陽": return String(localized: "pattern.description.最後の抱き線陽", defaultValue: "上昇トレンド末期に、小陰線を大陽線が包む形。翌日の下寄りで天井を確認する売り転換サイン。", comment: "ローソク足パターン「最後の抱き線陽」の説明文")
        case "毛抜き天井": return String(localized: "pattern.description.毛抜き天井", defaultValue: "2本の高値がほぼ同じ水準で並ぶ。強いレジスタンスを示す天井打ちサイン。", comment: "ローソク足パターン「毛抜き天井」の説明文")
        case "毛抜き底": return String(localized: "pattern.description.毛抜き底", defaultValue: "2本の安値がほぼ同じ水準で並ぶ。強いサポートの存在を示す底打ちサイン。", comment: "ローソク足パターン「毛抜き底」の説明文")
        case "行き詰まり線": return String(localized: "pattern.description.行き詰まり線", defaultValue: "上昇中の3本陽線で3本目の実体が極小。買い勢力の失速を示す天井転換サイン。", comment: "ローソク足パターン「行き詰まり線」の説明文")
        case "赤三兵": return String(localized: "pattern.description.赤三兵", defaultValue: "3本連続陽線で終値が順に上昇。上昇継続のサイン。", comment: "ローソク足パターン「赤三兵」の説明文")
        case "陰のたすき": return String(localized: "pattern.description.陰のたすき", defaultValue: "ギャップダウン後2本陰線、その後の陽線がギャップを埋めきれない。下落継続サイン。", comment: "ローソク足パターン「陰のたすき」の説明文")
        case "陽のたすき": return String(localized: "pattern.description.陽のたすき", defaultValue: "ギャップアップ後2本陽線、その後の陰線がギャップを埋めきれない。上昇継続サイン。", comment: "ローソク足パターン「陽のたすき」の説明文")
        case "首吊り線": return String(localized: "pattern.description.首吊り線", defaultValue: "上昇トレンド後の下ヒゲが長い足。高値圏での不安定さを示す天井転換サイン。", comment: "ローソク足パターン「首吊り線」の説明文")
        default: return nil
        }
    }
}
