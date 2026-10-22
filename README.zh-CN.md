# Tatakikun

[English](README.md) | **简体中文** | [日本語](README.ja.md)

一个 macOS 输入法:你用英文字母键入的内容,会同时被当作英文单词、汉语拼音和日文罗马字来理解,
英文、中文、平假名、片假名和日文汉字候选并排显示在一条横向候选条里。键入的原始字母串始终是候选之一。

![键入 "ai" 时的候选条](docs/images/bar.png)

![展开后显示更多行,可以滚动](docs/images/expanded.png)

## 构建和安装

**安装器。** `scripts/make-installer.sh` 生成 `build/Tatakikun-<版本>.pkg`(Apple 芯片和 Intel 的 Mac 都能用)。打开它,在 **自定** 页勾选要装的语言包:中文、日文、英文(默认全选)。只装给当前用户,不需要管理员密码。以后想改语言,再运行一次安装器;没勾选的语言包会被删除。

这个安装包没有 Apple 开发者签名。在自己的 Mac 上生成的可以直接打开;从网上下载的第一次会被拦下:打开 系统设置 → 隐私与安全性,点 **仍要打开**。

**从源码文件夹安装**(不用安装器):

```sh
scripts/build.sh            # 构建 app 和语言包(第一次会下载开源数据,约 80 MB)
scripts/install.sh          # 安装全部三个语言包;也可以只装一部分,如 scripts/install.sh zh,en
```

然后添加一次:系统设置 → 键盘 → 文字输入 → 输入法 → 编辑… → + → 简体中文 → Tatakikun。不在列表里就注销再登录。

两种方式都会添加一个登录项,登录时启动 Tatakikun:macOS 只在文本框请求输入法时才启动它,而登录后的那次请求会丢失,导致切换一次窗口之前无法输入。可在 系统设置 → 通用 → 登录项与扩展 → 允许在后台 里关掉。

不安装也能先试:`TATAKIKUN_PACKS=build/packs .build/release/Tatakikun --demo`。

## 按键

| 按键 | 输入时 |
| --- | --- |
| 字母 | 加入输入 |
| 空格 | 上屏高亮的候选(没移动过就是第一个);英文单词后面自动加一个半角空格(紧接着打 `,` `.` 等标点时,这个空格会被标点替换) |
| 回车 | 原样上屏键入的字母 |
| 1–9 | 上屏高亮那一行的对应候选 |
| ← → | 移动高亮 |
| ↓ 或 Tab | 候选条向下展开成多行(展开后向下移一行);多行可以滚动 |
| ↑ | 向上移一行;在第一行时收起 |
| 退格 | 删除最后一个字母 |
| Esc | 展开时收起,否则取消输入 |
| 点击 | 上屏被点击的候选 |
| 标点 | 先上屏高亮的候选,再输入标点:中文、日文候选后是全角标点(`，` `。` / `、` `。` `「」`),英文候选后是半角标点 |
| 罗马字后的 - | 日文长音符号 ー,和其他日文输入法一样(`sute-tasu` → ステータス,`ko-hi-` → コーヒー) |

没在输入时,标点和空格看光标前的文字:中文、日文后面是全角(`，` `、` 和全角空格),英文后面是半角。

## 候选顺序

候选条按代价(每个词有多常用)排序,并保证两点:每种匹配到的语言(EN 英文、中 中文、日 日文汉字、
あ 平假名、ア 片假名)的最佳候选都在候选条里;键入的原始字母也在里面——它本身是英文单词时和其他
英文单词一样排序,否则排在最后一位。

展开后的行里还有不完全匹配的候选(灰色显示):补全你键入内容的词(`zhongg` → 中国、
`compu` → computer、`arigat` → ありがとう)、英文拼写建议,以及只覆盖开头几个字母的词
(`nihaoma` → 你好)。选择后者会上屏这个词,剩下的字母(`ma`)留着继续输入。如果还没有任何候选
完整匹配全部字母,候选条本身就显示最好的不完全匹配。

Tatakikun 会学习:你选过的候选,下次键入同样的字母时排得更靠前。分几次选出来的、或者不是选第一个候选得到的
2 到 4 个字的中文或日文结果,会成为一个新词:再键入同样的字母时,它作为一个候选排在第一位。学到的内容只保存在这台 Mac 的
`~/Library/Application Support/Tatakikun/` 里的 `history.tsv` 和 `custom-words.tsv`;删除这两个文件即可清除。

## 词库

每种语言是一个 **语言包**,装在 `~/Library/Application Support/Tatakikun/Packs/<zh|ja|en>`;没装的语言不出候选(键入的原始字母串始终会出现)。

| 语言包 | 数据来源 | 许可证 |
| --- | --- | --- |
| 中文 | [pinyin-data](https://github.com/mozillazg/pinyin-data)(每个字的全部读音)、[phrase-pinyin-data](https://github.com/mozillazg/phrase-pinyin-data)(约 40 万词的读音)、ICU 和 [jieba](https://github.com/fxsjy/jieba) 的词频 | MIT;Unicode License V3 |
| 日文 | [Mozc 开源词典](https://github.com/google/mozc/tree/master/src/data/dictionary_oss)(约 100 万词及读音)、ICU 的词表和词频 | IPAdic 等(见其 README);Unicode License V3 |
| 英文 | [SCOWL](http://wordlist.aspell.net/),用它的分级作为词频 | SCOWL 的宽松许可 |

`scripts/fetch-sources.sh` 下载这些数据,固定到具体版本并校验 SHA-256;`scripts/build-packs.sh` 在 `build/packs` 生成语言包,每个都附带其数据的 LICENSE.txt。ICU 部分来自本机(`/usr/share/icu`):`tatakikun-dictgen` 把它的中日词表读进 `build/dict`。词库是内存映射的 `.ttkd` 文件,再大也能瞬间启动。数据和语言包都不在这个仓库里。

## iPhone 和 iPad(预览)

`iOS/` 里是带 Tatakikun 键盘的 iOS 应用(iOS 16 以上):同样的引擎和语言包,QWERTY 键盘上方是候选条。
点候选上屏,或按空格上屏第一个;return 上屏原始字母;⌄ 显示更多候选;`，` `。` 和 Mac 上一样随语言变化。

```sh
scripts/build-ios.sh        # 为模拟器构建(需要 build/packs;重新生成工程需要 XcodeGen)
scripts/build-ios.sh test   # 并运行界面测试
```

在 Xcode 中打开 `iOS/Tatakikun.xcodeproj` 可以装到自己的 iPhone 上(用你的 Apple ID 签名),然后启用:
设置 → 通用 → 键盘 → 键盘 → 添加新键盘… → Tatakikun。应用里也有一个不用启用就能试用键盘的页面。目前没有上架 App Store。

## 开发

- `swift test` — 引擎、按键和语言包的测试(需要 `build/dict` 和 `build/packs`:先运行 `scripts/build.sh`)。
- `swift run -c release tatakikun-cli --packs build/packs nihao ai toukyou` — 打印候选。
- `.build/release/Tatakikun --snapshot <字母> out.png [dark]` — 把候选条画成图片。

## 许可证

MIT,见 [LICENSE](LICENSE)。语言包不在这个仓库里;每个语言包都附带其数据的许可证(见上面的“词库”)。
