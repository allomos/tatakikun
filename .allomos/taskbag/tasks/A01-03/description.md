对照规格 8 试用 v0.2,写下试用步骤。

**Evidence**(2026-10-20):
- `swift test`:19 个测试,0 失败;新增 ExpandTests 覆盖 ↓/Tab 展开、按行移动、数字选高亮行、↑/Esc 收起、zhongg→中国、compu→computer、nihaoma→你好 后保留 ma、原始串仍在第一行。
- `tatakikun-cli`:zhongg 第一行有“中国”(不完全匹配);compu 第一行有 computer;ai 展开后有 200 个候选。
- 截图(`Tatakikun --snapshot`,已存入 docs/images/):bar.png(横向条)、expanded.png(展开 6 行,滚动到选中行,滚动条可见)、bar-dark.png(深色模式)。
- 每次按键约 9 ms(20 次输入 0.17 秒,不含 0.6 秒的启动加载)。
- **未验证**:在系统输入法里亲手展开、滚动、点击,需要这个人试。
