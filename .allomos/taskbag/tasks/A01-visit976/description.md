**Outcome.** Tatakikun 安卓键盘改成 Gboard 风格:顶部空闲时是工具栏(设置、粘贴、光标左右),打字时换成候选栏(字大、均分、细分隔线);常驻数字行;字母键角上有长按符号;功能键浅蓝圆角;底行 ?123 ，(长按 、) 空格(Tatakikun) 。(长按 ?) 回车;打字中的字母显示在键盘上方的小框里;不自带地球键,给系统导航栏留出空间。

**Done means.** 截图和设计稿一致;return 不被系统栏遮挡;test-android.sh 全部通过;深色模式看得清。

**Notes.** 设计稿第二版 2026-10-23 由 approver 在对话中确认(「设计可以，按这个改安卓键盘」)。

## Evidence

- 合并到 master(Android keyboard laid out like Gboard)。
- 模拟器 Pixel_7_API_34:debug 版和正式签名的测试 APK(build/Tatakikun-android-keyboard-test.apk,SHA-256 1add729b…a917e)各跑一次 test-android.sh,9 项全过。
- 截图看过:浅色空闲(工具栏)、打字 nihao(小框 nihao,候选 你好|你号|妳好|にはお|昵好)、深色打字 ai、深色 ?123 符号层。
- 没验证:Android 15 及以上的导航栏留空(本机只有 API 33/34 模拟器;API 34 上键盘本来就在导航栏上方)。要在真机(Pixel)上看。
- 2026-10-23, claude-release: GitHub release v0.6.4 (2026-10-23, approved by the approver's `alm guide github release` in the conversation): tag v0.6.4 pushed; assets Tatakikun-0.6.4.pkg (+.sha256 7e49e208…bf29b5) and Tatakikun-0.6.4-android.apk (versionCode 604, release cert 05d10759…bdb41, +.sha256 e6d782f5…1abb5276). test-android.sh with the release APK 9/9 on Pixel_7_API_34; upgrade from the v0.6.3 APK with adb install -r: Success. Mac .pkg downloaded, shasum OK, installed: 0.6.4. swift test 81, 1 failure (known compu spell-checker pitfall; no Mac code changed since v0.6.3).
