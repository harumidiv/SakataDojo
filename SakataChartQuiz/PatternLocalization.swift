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
        case "赤三兵": return String(localized: "pattern.name.赤三兵", defaultValue: "赤三兵", comment: "酒田五法のローソク足パターン名")
        case "三羽烏": return String(localized: "pattern.name.三羽烏", defaultValue: "三羽烏", comment: "酒田五法のローソク足パターン名")
        case "赤三兵思案星": return String(localized: "pattern.name.赤三兵思案星", defaultValue: "赤三兵思案星", comment: "酒田五法のローソク足パターン名")
        case "明けの明星": return String(localized: "pattern.name.明けの明星", defaultValue: "明けの明星", comment: "酒田五法のローソク足パターン名")
        case "宵の明星": return String(localized: "pattern.name.宵の明星", defaultValue: "宵の明星", comment: "酒田五法のローソク足パターン名")
        case "逆三尊": return String(localized: "pattern.name.逆三尊", defaultValue: "逆三尊", comment: "酒田五法のローソク足パターン名")
        case "三尊": return String(localized: "pattern.name.三尊", defaultValue: "三尊", comment: "酒田五法のローソク足パターン名")
        case "三空叩き込み": return String(localized: "pattern.name.三空叩き込み", defaultValue: "三空叩き込み", comment: "酒田五法のローソク足パターン名")
        case "下放れ三手放れ寄せ線": return String(localized: "pattern.name.下放れ三手放れ寄せ線", defaultValue: "下放れ三手放れ寄せ線", comment: "酒田五法のローソク足パターン名")
        case "三空踏み上げ": return String(localized: "pattern.name.三空踏み上げ", defaultValue: "三空踏み上げ", comment: "酒田五法のローソク足パターン名")
        case "上放れ三手放れ寄せ線": return String(localized: "pattern.name.上放れ三手放れ寄せ線", defaultValue: "上放れ三手放れ寄せ線", comment: "酒田五法のローソク足パターン名")
        case "上げ三法": return String(localized: "pattern.name.上げ三法", defaultValue: "上げ三法", comment: "酒田五法のローソク足パターン名")
        case "下げ三法": return String(localized: "pattern.name.下げ三法", defaultValue: "下げ三法", comment: "酒田五法のローソク足パターン名")
        case "上放れタスキ": return String(localized: "pattern.name.上放れタスキ", defaultValue: "上放れタスキ", comment: "酒田五法のローソク足パターン名")
        case "上放れ並び赤": return String(localized: "pattern.name.上放れ並び赤", defaultValue: "上放れ並び赤", comment: "酒田五法のローソク足パターン名")
        case "上放れ並び黒": return String(localized: "pattern.name.上放れ並び黒", defaultValue: "上放れ並び黒", comment: "酒田五法のローソク足パターン名")
        case "下放れの星": return String(localized: "pattern.name.下放れの星", defaultValue: "下放れの星", comment: "酒田五法のローソク足パターン名")
        case "下放れタスキ": return String(localized: "pattern.name.下放れタスキ", defaultValue: "下放れタスキ", comment: "酒田五法のローソク足パターン名")
        case "下放れ並び赤": return String(localized: "pattern.name.下放れ並び赤", defaultValue: "下放れ並び赤", comment: "酒田五法のローソク足パターン名")
        case "下放れ二本黒": return String(localized: "pattern.name.下放れ二本黒", defaultValue: "下放れ二本黒", comment: "酒田五法のローソク足パターン名")
        case "上放れの星": return String(localized: "pattern.name.上放れの星", defaultValue: "上放れの星", comment: "酒田五法のローソク足パターン名")
        case "陽の包み線": return String(localized: "pattern.name.陽の包み線", defaultValue: "陽の包み線", comment: "酒田五法のローソク足パターン名")
        case "陽のはらみ線": return String(localized: "pattern.name.陽のはらみ線", defaultValue: "陽のはらみ線", comment: "酒田五法のローソク足パターン名")
        case "切り込み線": return String(localized: "pattern.name.切り込み線", defaultValue: "切り込み線", comment: "酒田五法のローソク足パターン名")
        case "毛抜き底": return String(localized: "pattern.name.毛抜き底", defaultValue: "毛抜き底", comment: "酒田五法のローソク足パターン名")
        case "最後の抱き陰線": return String(localized: "pattern.name.最後の抱き陰線", defaultValue: "最後の抱き陰線", comment: "酒田五法のローソク足パターン名")
        case "陽のたすき線": return String(localized: "pattern.name.陽のたすき線", defaultValue: "陽のたすき線", comment: "酒田五法のローソク足パターン名")
        case "陰の包み線": return String(localized: "pattern.name.陰の包み線", defaultValue: "陰の包み線", comment: "酒田五法のローソク足パターン名")
        case "陰のはらみ線": return String(localized: "pattern.name.陰のはらみ線", defaultValue: "陰のはらみ線", comment: "酒田五法のローソク足パターン名")
        case "かぶせ線": return String(localized: "pattern.name.かぶせ線", defaultValue: "かぶせ線", comment: "酒田五法のローソク足パターン名")
        case "毛抜き天井": return String(localized: "pattern.name.毛抜き天井", defaultValue: "毛抜き天井", comment: "酒田五法のローソク足パターン名")
        case "最後の抱き陽線": return String(localized: "pattern.name.最後の抱き陽線", defaultValue: "最後の抱き陽線", comment: "酒田五法のローソク足パターン名")
        case "陰のたすき線": return String(localized: "pattern.name.陰のたすき線", defaultValue: "陰のたすき線", comment: "酒田五法のローソク足パターン名")
        case "あて首線": return String(localized: "pattern.name.あて首線", defaultValue: "あて首線", comment: "酒田五法のローソク足パターン名")
        case "入り首線": return String(localized: "pattern.name.入り首線", defaultValue: "入り首線", comment: "酒田五法のローソク足パターン名")
        case "差し込み線": return String(localized: "pattern.name.差し込み線", defaultValue: "差し込み線", comment: "酒田五法のローソク足パターン名")
        case "カラカサ": return String(localized: "pattern.name.カラカサ", defaultValue: "カラカサ", comment: "酒田五法のローソク足パターン名")
        case "トンボ": return String(localized: "pattern.name.トンボ", defaultValue: "トンボ", comment: "酒田五法のローソク足パターン名")
        case "トンカチ": return String(localized: "pattern.name.トンカチ", defaultValue: "トンカチ", comment: "酒田五法のローソク足パターン名")
        case "首吊り線": return String(localized: "pattern.name.首吊り線", defaultValue: "首吊り線", comment: "酒田五法のローソク足パターン名")
        case "流れ星": return String(localized: "pattern.name.流れ星", defaultValue: "流れ星", comment: "酒田五法のローソク足パターン名")
        case "塔婆": return String(localized: "pattern.name.塔婆", defaultValue: "塔婆", comment: "酒田五法のローソク足パターン名")
        default: return pattern
        }
    }

    static func description(for pattern: String) -> String? {
        switch pattern {
        case "赤三兵": return String(localized: "pattern.description.赤三兵", defaultValue: "3本連続陽線で終値が順に上昇。上昇継続のサイン。", comment: "ローソク足パターン「赤三兵」の説明文")
        case "三羽烏": return String(localized: "pattern.description.三羽烏", defaultValue: "高値圏で3本の陰線が続き、終値が順に下降。上昇から下降への転換サイン。", comment: "ローソク足パターン「三羽烏」の説明文")
        case "赤三兵思案星": return String(localized: "pattern.description.赤三兵思案星", defaultValue: "上昇中に陽線が3本続き、3本目の実体が極小（星）になる形。買い勢力の迷いを示す天井転換サイン。", comment: "ローソク足パターン「赤三兵思案星」の説明文")
        case "明けの明星": return String(localized: "pattern.description.明けの明星", defaultValue: "大陰線・小実体・大陽線の3本。底打ちからの上昇転換サイン。", comment: "ローソク足パターン「明けの明星」の説明文")
        case "宵の明星": return String(localized: "pattern.description.宵の明星", defaultValue: "大陽線・小実体・大陰線の3本。天井からの下落転換サイン。", comment: "ローソク足パターン「宵の明星」の説明文")
        case "逆三尊": return String(localized: "pattern.description.逆三尊", defaultValue: "3つの谷のうち中央が最も深い形。ネックラインを上抜けると底入れ確定とされる代表的な買いサイン。", comment: "ローソク足パターン「逆三尊」の説明文")
        case "三尊": return String(localized: "pattern.description.三尊", defaultValue: "3つの山のうち中央が最も高い形。ネックラインを割り込むと天井確定とされる代表的な売りサイン。", comment: "ローソク足パターン「三尊」の説明文")
        case "三空叩き込み": return String(localized: "pattern.description.三空叩き込み", defaultValue: "窓を開けた陰線が3回続く形。売られ過ぎを示し、投げ売りが出尽くした底値サイン。", comment: "ローソク足パターン「三空叩き込み」の説明文")
        case "下放れ三手放れ寄せ線": return String(localized: "pattern.description.下放れ三手放れ寄せ線", defaultValue: "下方へ窓を空けた後、3本の陰線が安値を更新し、十字線が出現。売り勢力の行き詰まりを示す底値サイン。", comment: "ローソク足パターン「下放れ三手放れ寄せ線」の説明文")
        case "三空踏み上げ": return String(localized: "pattern.description.三空踏み上げ", defaultValue: "窓を開けた陽線が3回続く形。買われ過ぎを示し、売り方の買い戻しが一巡した天井サイン。", comment: "ローソク足パターン「三空踏み上げ」の説明文")
        case "上放れ三手放れ寄せ線": return String(localized: "pattern.description.上放れ三手放れ寄せ線", defaultValue: "上方へ窓を空けた後、3本の陽線が高値を更新し、十字線が出現。買い勢力の行き詰まりを示す天井サイン。", comment: "ローソク足パターン「上放れ三手放れ寄せ線」の説明文")
        case "上げ三法": return String(localized: "pattern.description.上げ三法", defaultValue: "大陽線の後、その値幅内に小さな足が3本ほど続き、再び陽線が高値を更新する形。一服後の上昇継続サイン。", comment: "ローソク足パターン「上げ三法」の説明文")
        case "下げ三法": return String(localized: "pattern.description.下げ三法", defaultValue: "大陰線の後、その値幅内に小さな足が3本ほど続き、再び陰線が安値を更新する形。一服後の下落継続サイン。", comment: "ローソク足パターン「下げ三法」の説明文")
        case "上放れタスキ": return String(localized: "pattern.description.上放れタスキ", defaultValue: "ギャップアップ後2本陽線、その後の陰線がギャップを埋めきれない。上昇継続サイン。", comment: "ローソク足パターン「上放れタスキ」の説明文")
        case "上放れ並び赤": return String(localized: "pattern.description.上放れ並び赤", defaultValue: "ギャップアップ後に同じ大きさの陽線が2本並ぶ。強い買い勢いの継続サイン。", comment: "ローソク足パターン「上放れ並び赤」の説明文")
        case "上放れ並び黒": return String(localized: "pattern.description.上放れ並び黒", defaultValue: "上昇途中のギャップアップ後に同程度の陰線が2本並ぶ。押し目からの上昇継続候補だが、確認を要する弱いサイン。", comment: "ローソク足パターン「上放れ並び黒」の説明文")
        case "下放れの星": return String(localized: "pattern.description.下放れの星", defaultValue: "下降中に窓を開けて下放れた後、十字線（星）が出る形。下落の終局を示す底値転換警戒サイン。", comment: "ローソク足パターン「下放れの星」の説明文")
        case "下放れタスキ": return String(localized: "pattern.description.下放れタスキ", defaultValue: "ギャップダウン後2本陰線、その後の陽線がギャップを埋めきれない。下落継続サイン。", comment: "ローソク足パターン「下放れタスキ」の説明文")
        case "下放れ並び赤": return String(localized: "pattern.description.下放れ並び赤", defaultValue: "ギャップダウン後に陽線2本が並ぶが窓を埋めきれない。下落継続の意外な継続サイン。", comment: "ローソク足パターン「下放れ並び赤」の説明文")
        case "下放れ二本黒": return String(localized: "pattern.description.下放れ二本黒", defaultValue: "ギャップダウン後に陰線2本が続く。強い売り勢いの継続を示すサイン。", comment: "ローソク足パターン「下放れ二本黒」の説明文")
        case "上放れの星": return String(localized: "pattern.description.上放れの星", defaultValue: "上昇中に窓を開けて上放れた後、十字線（星）が出る形。上昇の終局を示す天井転換警戒サイン。", comment: "ローソク足パターン「上放れの星」の説明文")
        case "陽の包み線": return String(localized: "pattern.description.陽の包み線", defaultValue: "前日陰線を大陽線が完全に包む。強い買い圧力の上昇転換サイン。", comment: "ローソク足パターン「陽の包み線」の説明文")
        case "陽のはらみ線": return String(localized: "pattern.description.陽のはらみ線", defaultValue: "大陰線の実体内に小陽線が収まる。売り勢力の弱まりを示す反転サイン。", comment: "ローソク足パターン「陽のはらみ線」の説明文")
        case "切り込み線": return String(localized: "pattern.description.切り込み線", defaultValue: "陰線の後、低く始まって陰線の半値以上まで戻す陽線。底からの反発サイン。", comment: "ローソク足パターン「切り込み線」の説明文")
        case "毛抜き底": return String(localized: "pattern.description.毛抜き底", defaultValue: "2本の安値がほぼ同じ水準で並ぶ。強いサポートの存在を示す底打ちサイン。", comment: "ローソク足パターン「毛抜き底」の説明文")
        case "最後の抱き陰線": return String(localized: "pattern.description.最後の抱き陰線", defaultValue: "下降トレンド末期に、小陽線を大陰線が包む形。翌日の上寄りで底入れを確認する買い転換サイン。", comment: "ローソク足パターン「最後の抱き陰線」の説明文")
        case "陽のたすき線": return String(localized: "pattern.description.陽のたすき線", defaultValue: "陰線の翌日、前日の実体内から始まり前日の高値を超えて引ける陽線。安値圏で下落の勢いを打ち消す上昇転換サイン。", comment: "ローソク足パターン「陽のたすき線」の説明文")
        case "陰の包み線": return String(localized: "pattern.description.陰の包み線", defaultValue: "前日陽線を大陰線が完全に包む。強い売り圧力の下落転換サイン。", comment: "ローソク足パターン「陰の包み線」の説明文")
        case "陰のはらみ線": return String(localized: "pattern.description.陰のはらみ線", defaultValue: "大陽線の実体内に小陰線が収まる。買い勢力の弱まりを示す反転サイン。", comment: "ローソク足パターン「陰のはらみ線」の説明文")
        case "かぶせ線": return String(localized: "pattern.description.かぶせ線", defaultValue: "陽線の後、高く始まって陽線の半値以下まで食い込む陰線。天井からの反落サイン。", comment: "ローソク足パターン「かぶせ線」の説明文")
        case "毛抜き天井": return String(localized: "pattern.description.毛抜き天井", defaultValue: "2本の高値がほぼ同じ水準で並ぶ。強いレジスタンスを示す天井打ちサイン。", comment: "ローソク足パターン「毛抜き天井」の説明文")
        case "最後の抱き陽線": return String(localized: "pattern.description.最後の抱き陽線", defaultValue: "上昇トレンド末期に、小陰線を大陽線が包む形。翌日の下寄りで天井を確認する売り転換サイン。", comment: "ローソク足パターン「最後の抱き陽線」の説明文")
        case "陰のたすき線": return String(localized: "pattern.description.陰のたすき線", defaultValue: "陽線の翌日、前日の実体内から始まり前日の安値を下回って引ける陰線。高値圏で上昇の勢いを打ち消す下落転換サイン。", comment: "ローソク足パターン「陰のたすき線」の説明文")
        case "あて首線": return String(localized: "pattern.description.あて首線", defaultValue: "下降中の大陰線の翌日、安く始まった陽線が前日の安値付近までしか戻らない形。戻りの弱さを示す下落継続サイン。", comment: "ローソク足パターン「あて首線」の説明文")
        case "入り首線": return String(localized: "pattern.description.入り首線", defaultValue: "下降中の大陰線の翌日、安く始まった陽線が前日の終値をわずかに上回るだけで終わる形。戻りの弱さを示す下落継続サイン。", comment: "ローソク足パターン「入り首線」の説明文")
        case "差し込み線": return String(localized: "pattern.description.差し込み線", defaultValue: "下降中の大陰線の翌日、安く始まった陽線が前日の実体に食い込むが半値まで届かない形。戻り売りを示す下落継続サイン。", comment: "ローソク足パターン「差し込み線」の説明文")
        case "カラカサ": return String(localized: "pattern.description.カラカサ", defaultValue: "下降トレンド後の下ヒゲが長い足。底値圏での強い買い意欲を示す反転サイン。", comment: "ローソク足パターン「カラカサ」の説明文")
        case "トンボ": return String(localized: "pattern.description.トンボ", defaultValue: "下降トレンド後の下ヒゲのみの十字線。売り方の失速と買い方の出現を示す反転サイン。", comment: "ローソク足パターン「トンボ」の説明文")
        case "トンカチ": return String(localized: "pattern.description.トンカチ", defaultValue: "下降トレンド後に出る、上ヒゲが長く実体が小さい足。安値圏で買いが入り始めたことを示す底打ちサイン。", comment: "ローソク足パターン「トンカチ」の説明文")
        case "首吊り線": return String(localized: "pattern.description.首吊り線", defaultValue: "上昇トレンド後の下ヒゲが長い足。高値圏での不安定さを示す天井転換サイン。", comment: "ローソク足パターン「首吊り線」の説明文")
        case "流れ星": return String(localized: "pattern.description.流れ星", defaultValue: "上昇トレンド後の上ヒゲが長い足。高値で売りに押された天井転換サイン。", comment: "ローソク足パターン「流れ星」の説明文")
        case "塔婆": return String(localized: "pattern.description.塔婆", defaultValue: "上昇トレンド後の上ヒゲのみの十字線。高値での買い失速と売り圧力を示す天井サイン。", comment: "ローソク足パターン「塔婆」の説明文")
        default: return nil
        }
    }

    static func category(_ category: PatternCategory) -> String {
        switch category {
        case .sanzan: return String(localized: "pattern.category.sanzan", defaultValue: "三山", comment: "パターン図鑑の分類見出し")
        case .sansen: return String(localized: "pattern.category.sansen", defaultValue: "三川", comment: "パターン図鑑の分類見出し")
        case .sanku: return String(localized: "pattern.category.sanku", defaultValue: "三空", comment: "パターン図鑑の分類見出し")
        case .sanpei: return String(localized: "pattern.category.sanpei", defaultValue: "三兵", comment: "パターン図鑑の分類見出し")
        case .sanpo: return String(localized: "pattern.category.sanpo", defaultValue: "三法", comment: "パターン図鑑の分類見出し")
        case .gap: return String(localized: "pattern.category.gap", defaultValue: "窓・放れ", comment: "パターン図鑑の分類見出し")
        case .twoCandle: return String(localized: "pattern.category.twoCandle", defaultValue: "2本の組み合わせ", comment: "パターン図鑑の分類見出し")
        case .oneCandle: return String(localized: "pattern.category.oneCandle", defaultValue: "1本の足", comment: "パターン図鑑の分類見出し")
        }
    }
}
