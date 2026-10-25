#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Symbols offered for their names, as Japanese input methods do (まる → ○ ◎ ●, ばつ → × ✕):
/// in each input language, a name typed as a whole word gives its symbols among the candidates.
/// Japanese names are kana readings, so every romaji spelling of them works (batu, batsu);
/// the word languages match without accents (circulo, círculo).
public enum Symbols {
    static let circles = ["○", "◯", "●", "◎", "⚪", "⚫", "⭕"]
    static let crosses = ["×", "✕", "✖", "☓", "✗", "✘", "❌"]
    static let checks = ["✓", "✔", "☑", "✅"]
    static let triangles = ["△", "▲", "▽", "▼", "▷", "◁", "⊿"]
    static let squares = ["□", "■", "◇", "◆", "▢", "▣"]
    static let diamonds = ["◇", "◆", "♢", "♦"]
    static let stars = ["☆", "★", "✩", "✪", "✫", "✬", "✭", "✮", "✯", "✰"]
    static let hearts = ["♡", "♥", "❤", "💕"]
    static let arrows = ["→", "←", "↑", "↓", "⇒", "⇐", "⇔", "↔", "↗", "↘", "↙", "↖"]
    static let notes = ["♪", "♫", "♬", "♩"]
    static let degrees = ["°", "℃", "℉"]
    static let percents = ["%", "％", "‰"]
    static let brackets = ["（）", "「」", "『』", "【】", "〔〕", "［］", "｛｝", "〈〉", "《》"]
    static let lines = ["─", "│", "┌", "┐", "└", "┘", "├", "┤", "┬", "┴", "┼", "━", "┃"]
    static let equals = ["=", "＝", "≒", "≈", "≠", "≡"]
    static let greater = [">", "＞", "≧", "≥", "≫"]
    static let less = ["<", "＜", "≦", "≤", "≪"]

    /// Japanese, by kana reading.
    static let japanese: [String: [String]] = [
        "まる": circles, "しろまる": ["○", "◯"], "くろまる": ["●"], "にじゅうまる": ["◎"], "ばつ": crosses,
        "ぺけ": ["×", "✕"], "ちぇっく": checks, "さんかく": triangles, "しかく": squares, "ひし": diamonds,
        "ほし": stars, "くろぼし": ["★"], "しろぼし": ["☆"], "はーと": hearts, "やじるし": arrows,
        "みぎ": ["→", "⇒", "➡"], "ひだり": ["←", "⇐", "⬅"], "うえ": ["↑", "⇑", "⬆"], "した": ["↓", "⇓", "⬇"],
        "こめ": ["※"], "ゆうびん": ["〒", "〶"], "おんぷ": notes, "でんわ": ["☎", "℡", "📞"],
        "から": ["〜", "～"], "てん": ["、", "・", "…", "‥", "．"], "かっこ": brackets, "けいせん": lines,
        "おなじ": ["々", "〃", "仝", "ゝ", "ゞ", "ヽ", "ヾ"], "どう": ["〃", "々"], "ど": degrees,
        "えん": ["¥", "￥", "円"], "どる": ["$", "＄"], "ゆーろ": ["€"], "ぽんど": ["£"], "せんと": ["¢"],
        "ぱーせんと": percents, "たす": ["+", "＋"], "ぷらす": ["+", "＋"], "ひく": ["−", "－"],
        "まいなす": ["−", "－"], "かける": ["×"], "わる": ["÷"], "いこーる": equals, "ぷらすまいなす": ["±", "∓"],
        "だいなり": greater, "しょうなり": less, "むげんだい": ["∞"], "るーと": ["√"], "ぱい": ["π", "Π"],
        "しぐま": ["Σ", "σ"], "あるふぁ": ["α", "Α"], "べーた": ["β", "Β"], "でるた": ["Δ", "δ"],
        "おめが": ["Ω", "ω"], "はれ": ["☀", "☼"], "くもり": ["☁"], "あめ": ["☂", "☔"], "ゆき": ["❄", "☃"],
        "おす": ["♂"], "めす": ["♀"], "かぶしきがいしゃ": ["㈱", "㍿"], "ゆうげんがいしゃ": ["㈲"],
        "こぴーらいと": ["©"], "せくしょん": ["§"],
    ]

    /// Chinese, by pinyin.
    static let chinese: [String: [String]] = [
        "yuan": circles, "yuanquan": circles, "cha": crosses, "cuo": crosses, "chahao": crosses,
        "dui": checks, "duihao": checks, "gou": checks, "dagou": checks, "sanjiao": triangles,
        "sanjiaoxing": triangles, "fangkuai": squares, "fangxing": squares, "zhengfangxing": squares,
        "lingxing": diamonds, "xingxing": stars, "wujiaoxing": stars, "xinxing": hearts, "aixin": hearts,
        "jiantou": arrows, "yinfu": notes, "du": degrees, "sheshidu": ["℃"], "baifenhao": percents,
        "renminbi": ["¥", "￥"], "meiyuan": ["$", "＄"], "ouyuan": ["€"], "yingbang": ["£"], "riyuan": ["¥", "円"],
        "jiahao": ["+", "＋"], "jianhao": ["−", "－"], "chenghao": ["×"], "chuhao": ["÷"], "dengyu": equals,
        "budengyu": ["≠"], "yuedengyu": ["≈", "≒"], "dayu": greater, "xiaoyu": less, "dayudengyu": ["≥", "≧"],
        "xiaoyudengyu": ["≤", "≦"], "zhengfu": ["±", "∓"], "wuqiong": ["∞"], "genhao": ["√"],
        "taiyang": ["☀", "☼"], "duoyun": ["☁"], "yusan": ["☂", "☔"], "xuehua": ["❄", "☃"],
        "dianhua": ["☎", "℡", "📞"], "xiongxing": ["♂"], "cixing": ["♀"], "xinghao": ["*", "＊", "※", "✱"],
        "banquan": ["©"], "zhuce": ["®"], "shangbiao": ["™"], "kuohao": brackets, "shuminghao": ["《》", "〈〉"],
        "yinhao": ["“”", "‘’", "「」", "『』"], "shenglvehao": ["……", "…"], "pozhehao": ["——"],
        "jiangehao": ["·", "・"], "zhabiao": lines,
    ]

    /// English.
    static let english: [String: [String]] = [
        "circle": circles, "cross": crosses + ["†", "✝"], "times": ["×"], "multiply": ["×"], "divide": ["÷"],
        "check": checks, "tick": checks, "checkmark": checks, "triangle": triangles, "square": squares,
        "diamond": diamonds, "star": stars, "heart": hearts, "arrow": arrows, "right": ["→", "⇒"],
        "left": ["←", "⇐"], "up": ["↑", "⇑"], "down": ["↓", "⇓"], "music": notes, "note": notes,
        "degree": degrees, "degrees": degrees, "celsius": ["℃"], "fahrenheit": ["℉"], "percent": percents,
        "permille": ["‰"], "plusminus": ["±", "∓"], "minus": ["−"], "equal": equals, "equals": equals,
        "notequal": ["≠"], "approx": ["≈", "≒"], "infinity": ["∞"], "sqrt": ["√"], "root": ["√"], "pi": ["π", "Π"],
        "sigma": ["Σ", "σ"], "alpha": ["α", "Α"], "beta": ["β", "Β"], "delta": ["Δ", "δ"], "omega": ["Ω", "ω"],
        "mu": ["µ", "μ"], "yen": ["¥", "￥"], "euro": ["€"], "pound": ["£"], "dollar": ["$"], "cent": ["¢"],
        "won": ["₩"], "rupee": ["₹"], "copyright": ["©"], "registered": ["®"], "trademark": ["™"],
        "section": ["§"], "paragraph": ["¶"], "dagger": ["†", "‡"], "bullet": ["•", "◦", "‣"], "ellipsis": ["…"],
        "dash": ["—", "–"], "sun": ["☀", "☼"], "cloud": ["☁"], "umbrella": ["☂", "☔"], "snow": ["❄", "☃"],
        "phone": ["☎", "✆", "📞"], "male": ["♂"], "female": ["♀"], "smile": ["☺", "☻", "🙂"],
        "spade": ["♠", "♤"], "club": ["♣", "♧"], "postal": ["〒"], "reference": ["※"],
    ]

    static let spanish: [String: [String]] = [
        "circulo": circles, "cruz": crosses + ["✝"], "equis": ["×", "✕"], "triangulo": triangles,
        "cuadrado": squares, "rombo": diamonds, "estrella": stars, "corazon": hearts, "flecha": arrows,
        "derecha": ["→", "⇒"], "izquierda": ["←", "⇐"], "arriba": ["↑"], "abajo": ["↓"], "nota": notes,
        "grado": degrees, "grados": degrees, "porciento": percents, "euro": ["€"], "dolar": ["$"],
        "infinito": ["∞"], "raiz": ["√"], "visto": checks, "marca": checks, "sol": ["☀", "☼"], "nube": ["☁"],
        "paraguas": ["☂", "☔"], "nieve": ["❄", "☃"], "telefono": ["☎", "📞"],
    ]

    static let french: [String: [String]] = [
        "cercle": circles, "rond": circles, "croix": crosses + ["✝"], "triangle": triangles, "carre": squares,
        "losange": diamonds, "etoile": stars, "coeur": hearts, "fleche": arrows, "droite": ["→", "⇒"],
        "gauche": ["←", "⇐"], "haut": ["↑"], "bas": ["↓"], "note": notes, "degre": degrees, "degres": degrees,
        "pourcent": percents, "euro": ["€"], "dollar": ["$"], "infini": ["∞"], "racine": ["√"], "coche": checks,
        "soleil": ["☀", "☼"], "nuage": ["☁"], "parapluie": ["☂", "☔"], "neige": ["❄", "☃"],
        "telephone": ["☎", "📞"],
    ]

    /// Hindi and Bengali by sound, Arabic in Arabizi: the way their packs are typed.
    static let hindi: [String: [String]] = [
        "gola": circles, "sahi": checks, "galat": crosses, "sitara": stars, "tara": stars, "dil": hearts,
        "teer": arrows, "rupaya": ["₹"], "rupaye": ["₹"], "rupay": ["₹"], "pratishat": percents,
    ]
    static let bengali: [String: [String]] = [
        "britto": circles, "gol": circles, "thik": checks, "bhul": crosses, "tara": stars, "hridoy": hearts,
        "tir": arrows, "taka": ["৳"], "shotangsho": percents,
    ]
    static let arabic: [String: [String]] = [
        "da2ira": circles, "sa7": checks, "sa7i7": checks, "ghalat": crosses, "najma": stars, "2alb": hearts,
        "sahm": arrows, "riyal": ["﷼"], "fasila": ["،"], "nisba": ["٪", "%"],
    ]

    static let table: [LanguagePacks.Language: [String: [String]]] = [
        .ja: japanese, .zh: chinese, .en: english, .es: spanish, .fr: french, .hi: hindi, .bn: bengali, .ar: arabic,
    ]

    /// The symbols `input` names in `language`; empty when it names none.
    public static func symbols(for input: String, in language: LanguagePacks.Language) -> [String] {
        guard let names = table[language] else { return [] }
        switch language {
        case .ja:
            return Romaji.toHiragana(input).flatMap { names[$0] } ?? []
        case .zh, .en, .ar:
            return names[input.lowercased()] ?? []
        default:
            return names[withoutAccents(input.lowercased())] ?? []
        }
    }

    static func withoutAccents(_ s: String) -> String {
        let plain: [Character: Character] = [
            "á": "a", "à": "a", "â": "a", "ä": "a", "é": "e", "è": "e", "ê": "e", "ë": "e", "í": "i", "î": "i",
            "ï": "i", "ó": "o", "ô": "o", "ö": "o", "ú": "u", "ù": "u", "û": "u", "ü": "u", "ç": "c", "ñ": "n",
        ]
        return String(s.map { plain[$0] ?? $0 })
    }
}
