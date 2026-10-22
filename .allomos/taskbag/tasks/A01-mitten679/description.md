**Outcome.** v0.6.3 的 GitHub Release 附上签名的安卓 APK(arm64)和 SHA-256 文件,说明里写怎么装。

**Done means.** `gh release view v0.6.3` 列出 APK 和 .sha256;APK 用正式签名(不是 debug 签名),`apksigner verify` 通过;在模拟器上安装后能打字。

**Notes.** 渠道由 approver 选定:GitHub Release 放 APK(2026-10-22,对话中「直接发这个」)。不上 Google Play。签名密钥放在项目外,丢了以后就不能覆盖升级。
