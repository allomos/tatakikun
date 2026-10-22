**Outcome.** 运行 `scripts/install.sh` 装完后,终端里提示:如果 VS Code、Slack 等 Electron 应用开着,要用 ⌘Q 完全退出再打开,Tatakikun 才能在里面输入。

**Done means.**
- `scripts/install.sh` 结束时打印这条提醒(中英文),说明原因:重装会结束旧的 Tatakikun 进程,原生应用会自动重连,Electron 应用不会。
- 原有的输出和安装行为不变。

**Notes.**
- 起因:2026-10-22 多次重装后,VS Code 和 Slack 里菜单栏显示 Tatakikun 但按键无反应;⌘Q 重开后恢复(项目笔记 Pitfalls 已记)。
- .pkg 安装器(`App/Installer/scripts/postinstall`)同样会结束旧进程,但它的脚本输出用户看不到;要提醒得在安装器里加结束页,是用户看得到的改动,留给人决定。
