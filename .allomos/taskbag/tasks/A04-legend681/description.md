**Outcome.** 重装 Tatakikun 后,用 `scripts/install.sh` 和用 .pkg 安装器都会提示:VS Code、Slack 等 Electron 应用要用 ⌘Q 完全退出再打开,Tatakikun 才能在里面输入。

**Done means.**
- `scripts/install.sh` 结束时打印这条提醒(中英文),并列出此刻在运行的 Electron 应用。
- .pkg 安装器多了结束页(中、英、日),内容是这条提醒和第一次添加输入法的步骤。
- 原有的安装行为不变。

**Notes.**
- 起因:2026-10-22 多次重装后,VS Code 和 Slack 里菜单栏显示 Tatakikun 但按键无反应;⌘Q 重开后恢复(项目笔记 Pitfalls 已记)。
- 人在 2026-10-22 要求也给 .pkg 加结束页。

**Evidence.**
- install.sh 的提醒部分单独在 `sh -e` 下运行:找到 Claude、Slack、Visual Studio Code 并列出;没有 Electron 应用时只打印两行提醒;退出码都是 0。
- `scripts/make-installer.sh` 构建出 Tatakikun-0.6.2.pkg;`pkgutil --expand` 看到 Distribution 里有 conclusion,三种语言的 conclusion.html 都在包里。
- 没有实际运行安装(会再次断开正在用的 VS Code/Slack)。
