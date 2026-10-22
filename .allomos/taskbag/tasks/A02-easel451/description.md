**Outcome.** 用语言包时,只键入声母 `nh` 第一个候选是“你好”,和用基础词库时一样(A02-06)。

**Done means.**
- `tatakikun-cli --packs build/packs nh` 第一个候选是 你好;前后结果写在 **Evidence** 下。
- 单元测试用语言包覆盖 nh→你好、wtx→わたし/私 这类首字母输入(AbbreviationTests 现在只用 build/dict,所以没发现)。
- 其他首字母输入不退步。

**Notes.**
- 发现于 2026-10-22(A01-10 在 Android 模拟器上测试时):`nh` → 1.女孩 2.您好 3.男孩 4.你会 5.你好;macOS 的 tatakikun-cli 用同一语言包结果相同,不是 Android 的问题。
- 需要查明是哪次改动引起的(A02-09 的 jieba 词频、A02-wire178 的单字代价,或更早),以及首字母索引的代价怎么算(`writePack` 的 abbreviationCostLimit、`abbreviated()`)。
