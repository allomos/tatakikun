**Outcome.** 口语整句能整句打出:键入 `niyongguolema` 时“你用过了吗”出现在第一行(最好排第一),而不是由少数长词硬拼的句子。

**Done means.**
- 整句候选不再只看单个词的频率加每词 30 分(`Cost.perWord`):考虑常见的前后搭配(如 过了、用过、了吗),或改用其他办法让常见的单字虚词组合不吃亏。
- `tatakikun-cli --packs build/packs niyongguolema` 第一行有“你用过了吗”;前后结果写在 **Evidence** 下。
- 单元测试覆盖 `niyongguolema` → 你用过了吗,以及几句别的口语句(如 nichifanlema → 你吃饭了吗)。
- 已有的整句和单词结果不退步(woaini、chongqizhiqian、yinhang、nihao、zhongguo 等),全部测试通过。

**Notes.**
- 起因(2026-10-22):词库里没有 过了、用过、你用、了吗 这些词,“你用过了吗”只能切成五个单字:你53+用53+过67+了46+吗66+4×30 = 405,比 拟用125+活了108+吗66+2×30 = 359 贵。代码在 `Sources/TatakikunCore/Converters.swift` 的 `segmentations`。
- 可能做法:二元(bigram)语言模型;从 jieba 词频补进常见搭配;降低单字虚词的切词扣分。做法由做任务的人决定并用 `alm ai-decided` 记录。
- 若要加新的数据来源,只用宽松许可的数据(MIT 等),不用 GPL(见 project notes)。语言包体积若明显变大,写进交接。
- 最好先做 A03-bluff274(生僻读音:活 guo、遇 yong),再比较结果。
