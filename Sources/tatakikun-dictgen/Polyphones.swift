/// Common Chinese characters with more than one toneless pinyin reading. The system transform gives
/// one reading per character (银行 → yin xing), so each word is also indexed under these readings
/// (yin hang) and the dictionary's word costs pick the right word.
let polyphones: [Character: [String]] = [
    "行": ["xing", "hang"], "长": ["chang", "zhang"], "重": ["zhong", "chong"], "乐": ["le", "yue"],
    "还": ["hai", "huan"], "了": ["le", "liao"], "得": ["de", "dei"], "地": ["di", "de"], "的": ["de", "di"],
    "都": ["dou", "du"], "着": ["zhe", "zhao", "zhuo"], "觉": ["jue", "jiao"], "和": ["he", "huo", "hu"],
    "便": ["bian", "pian"], "角": ["jiao", "jue"], "调": ["diao", "tiao"], "传": ["chuan", "zhuan"],
    "数": ["shu", "shuo"], "藏": ["cang", "zang"], "差": ["cha", "chai", "ci"], "大": ["da", "dai"],
    "单": ["dan", "shan", "chan"], "薄": ["bao", "bo"], "系": ["xi", "ji"], "似": ["si", "shi"],
    "奇": ["qi", "ji"], "曾": ["ceng", "zeng"], "朝": ["chao", "zhao"], "降": ["jiang", "xiang"],
    "解": ["jie", "xie"], "卡": ["ka", "qia"], "率": ["lv", "shuai"], "区": ["qu", "ou"],
    "参": ["can", "shen", "cen"], "省": ["sheng", "xing"], "识": ["shi", "zhi"], "属": ["shu", "zhu"],
    "说": ["shuo", "shui"], "宿": ["su", "xiu"], "血": ["xue", "xie"], "弹": ["dan", "tan"],
    "度": ["du", "duo"], "给": ["gei", "ji"], "合": ["he", "ge"], "劲": ["jin", "jing"],
    "落": ["luo", "la", "lao"], "没": ["mei", "mo"], "强": ["qiang", "jiang"], "色": ["se", "shai"],
    "什": ["shen", "shi"], "盛": ["sheng", "cheng"], "提": ["ti", "di"], "吓": ["xia", "he"],
    "校": ["xiao", "jiao"], "称": ["cheng", "chen"], "乘": ["cheng", "sheng"], "恶": ["e", "wu"],
    "佛": ["fo", "fu"], "期": ["qi", "ji"], "仇": ["chou", "qiu"], "圈": ["quan", "juan"],
    "塞": ["sai", "se"], "厦": ["sha", "xia"], "削": ["xiao", "xue"], "叶": ["ye", "xie"],
    "扎": ["zha", "za"], "车": ["che", "ju"], "冒": ["mao", "mo"], "秘": ["mi", "bi"],
    "粘": ["nian", "zhan"], "泊": ["bo", "po"], "尾": ["wei", "yi"], "否": ["fou", "pi"],
    "哪": ["na", "nei"], "那": ["na", "nei"], "这": ["zhe", "zhei"], "露": ["lu", "lou"],
    "绿": ["lv", "lu"], "剥": ["bo", "bao"], "模": ["mo", "mu"], "么": ["me", "mo"], "呢": ["ne", "ni"],
    "伯": ["bo", "bai"], "柏": ["bai", "bo"], "蔓": ["man", "wan"], "臭": ["chou", "xiu"],
    "刨": ["bao", "pao"], "埋": ["mai", "man"], "炮": ["pao", "bao"], "石": ["shi", "dan"],
    "召": ["zhao", "shao"], "仔": ["zi", "zai"], "番": ["fan", "pan"], "曝": ["pu", "bao"],
    "咽": ["yan", "ye"], "殷": ["yin", "yan"], "藉": ["ji", "jie"], "倒": ["dao"], "斗": ["dou"],
    "会": ["hui", "kuai"], "供": ["gong"], "背": ["bei"], "分": ["fen"], "干": ["gan"], "将": ["jiang"],
    "教": ["jiao"], "结": ["jie"], "看": ["kan"], "难": ["nan"], "空": ["kong"], "量": ["liang"],
    "发": ["fa"], "处": ["chu"], "冲": ["chong"], "兴": ["xing"], "应": ["ying"], "只": ["zhi"],
    "中": ["zhong"], "转": ["zhuan"], "当": ["dang"], "种": ["zhong"], "少": ["shao"], "相": ["xiang"],
    "要": ["yao"], "正": ["zheng"], "载": ["zai"], "更": ["geng"], "几": ["ji"], "假": ["jia"],
    "间": ["jian"], "尽": ["jin"], "宁": ["ning"], "片": ["pian"], "漂": ["piao"], "切": ["qie"],
    "曲": ["qu"], "散": ["san"], "上": ["shang"], "舍": ["she"], "鲜": ["xian"], "华": ["hua"],
    "划": ["hua"], "济": ["ji"], "喝": ["he"], "骑": ["qi"], "晕": ["yun"], "缝": ["feng"],
    "场": ["chang"], "挣": ["zheng"], "炸": ["zha"], "涨": ["zhang"], "沈": ["shen"], "覃": ["qin", "tan"],
    "蕃": ["fan", "bo"], "厂": ["chang"], "广": ["guang"], "银": ["yin"],
]

/// Every reading of a word: the transform's syllables, plus each combination with the other readings
/// of its polyphonic characters (at most `limit`). The transform's own reading comes first.
func pinyinReadings(_ word: String, default sylls: [String], limit: Int = 16) -> [[String]] {
    var readings: [[String]] = [[]]
    for (char, syll) in zip(word, sylls) {
        var options = [syll]
        for alt in polyphones[char] ?? [] where alt != syll { options.append(alt) }
        readings = readings.flatMap { r in options.map { r + [$0] } }
        if readings.count > limit { readings = Array(readings.prefix(limit)) }
    }
    return readings
}
