# Tatakikun

[English](README.md) | **简体中文** | [日本語](README.ja.md)

一个 macOS 输入法:你用英文字母键入的内容,会同时被当作英文单词、汉语拼音和日文罗马字来理解,
英文、中文、平假名、片假名和日文汉字候选并排显示在一条横向候选条里。键入的原始字母串始终是候选之一。

![键入 "ai" 时的候选条](docs/images/bar.png)

![展开后显示更多行,可以滚动](docs/images/expanded.png)

## 构建和安装

```sh
scripts/build.sh     # 构建 build/Tatakikun.app(第一次还会生成词库,约 1 分钟)
scripts/install.sh   # 复制到 ~/Library/Input Methods
```

然后添加一次:系统设置 → 键盘 → 文字输入 → 输入法 → 编辑… → + → 简体中文 → Tatakikun。
如果列表里还没有,注销后重新登录。

不安装也能试用:`TATAKIKUN_DICT=build/dict .build/release/Tatakikun --demo`。

## 按键

| 按键 | 输入时 |
| --- | --- |
| 字母 | 加入输入 |
| 空格 | 上屏高亮的候选(没移动过就是第一个) |
| 回车 | 原样上屏键入的字母 |
| 1–9 | 上屏高亮那一行的对应候选 |
| ← → | 移动高亮 |
| ↓ 或 Tab | 候选条向下展开成多行(展开后向下移一行);多行可以滚动 |
| ↑ | 向上移一行;在第一行时收起 |
| 退格 | 删除最后一个字母 |
| Esc | 展开时收起,否则取消输入 |
| 点击 | 上屏被点击的候选 |
| 标点 | 先上屏高亮的候选,再输入标点:中文、日文候选后是全角标点(`，` `。` / `、` `。` `「」`),英文候选后是半角标点 |

没在输入时,标点和空格看光标前的文字:中文、日文后面是全角(`，` `、` 和全角空格),英文后面是半角。

## 候选顺序

候选条按代价(每个词有多常用)排序,并保证两点:每种匹配到的语言(EN 英文、中 中文、日 日文汉字、
あ 平假名、ア 片假名)的最佳候选都在候选条里;键入的原始字母也在里面——它本身是英文单词时和其他
英文单词一样排序,否则排在最后一位。

展开后的行里还有不完全匹配的候选(灰色显示):补全你键入内容的词(`zhongg` → 中国、
`compu` → computer、`arigat` → ありがとう)、英文拼写建议,以及只覆盖开头几个字母的词
(`nihaoma` → 你好)。选择后者会上屏这个词,剩下的字母(`ma`)留着继续输入。如果还没有任何候选
完整匹配全部字母,候选条本身就显示最好的不完全匹配。

Tatakikun 会学习:你选过的候选,下次键入同样的字母时排得更靠前。学到的内容只保存在这台 Mac 的
`~/Library/Application Support/Tatakikun/history.tsv` 里;删除这个文件即可清除。

## 词库

在这台 Mac 上用 macOS 自带的数据生成:ICU 数据文件(`/usr/share/icu`)中带词频的中日韩词表、
系统的拼音和日文读音转换,以及系统的英文拼写检查。不下载任何东西。系统转换每个字只给一个读音,
所以常见多音字(行 xing/hang、长 chang/zhang……)列在 `Sources/tatakikun-dictgen/Polyphones.swift`
里,每个词按所有读音建立索引。`tatakikun-dictgen` 生成 `build/dict/zh.tsv` 和 `build/dict/ja.tsv`
(`读音<TAB>词<TAB>代价`)。

## 开发

- `swift test` — 引擎和按键处理的测试(需要 `build/dict`)。
- `swift run -c release tatakikun-cli nihao ai toukyou` — 打印候选。
- `.build/release/Tatakikun --snapshot <字母> out.png [dark]` — 把候选条画成图片。

## 许可证

MIT — 见 [LICENSE](LICENSE)。词库不包含在这个仓库里:它们在你的 Mac 上由 macOS 自带的数据
(ICU,采用 Unicode 许可证)生成。
