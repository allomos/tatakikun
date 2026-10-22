---
writer: claude-android-release
tasks: A01-mitten679, A01-visit976
written: 2026-10-22T14:38Z
updated: 2026-10-22T15:13Z
---

---
writer: claude-android-release
tasks: A01-mitten679
written: 2026-10-22T14:38Z
updated: 2026-10-22T14:38Z
---

# Handoff

## For anyone, in plain words

- **What was being done:** 安卓版 APK 发布(A01-mitten679);安卓键盘改成 Gboard 风格(A01-visit976)。
- **Where it stopped:** 两个都 done,待真机检查(alm human → To check)。新键盘已合并到 master,还没发布;测试 APK 在 build/Tatakikun-android-keyboard-test.apk(不在 git 里)。
- **Verified, and not verified yet:** 模拟器 API 34 上测试全过、截图看过;Android 15+ 导航栏留空没验证。
- **Waiting on whom:** approver:真机检查;备份签名密钥。
- **The next step (one):** 把测试 APK 装到 approver 的 Pixel 上检查(USB adb,或经 approver 同意发 GitHub 预发布版)。

## Restart details

- **Checkout:** master 已推送;worktree 和 task 分支都已删除。
- **Uncommitted changes:** none
- **Running:** none(模拟器已关)。
- **Approvals in force:** 2026-10-22 approver 在对话中选「GitHub Release 放 APK」并说「直接发这个」:只覆盖这次 v0.6.3 的 APK。Google Play 未批准。
- **Already done, do not repeat:** gh release upload v0.6.3(APK 和 .sha256)和 gh release edit v0.6.3 的说明;签名密钥已在 ~/.config/tatakikun/ 生成,不要重新生成(会换证书,手机无法覆盖升级)。
