**Outcome.** 在 Android 上安装 Tatakikun,在任何应用里键入字母就得到和 macOS 版一样的英中日混合候选。

**Done means.**
- 在 Android 上安装后能切换到 Tatakikun 并在常用应用里输入。
- 拼音、罗马字、英文、首字母、不完全匹配的候选与 macOS 版一致。
- 候选选择、上屏、学习功能可用。

**Notes.**
- 平台接入方式:Android 输入法(InputMethodService)。
- 待人决定(暂不执行,用户 2026-10-20 要求只添加任务):是否要做、优先级和时间;转换引擎/词库怎样跨平台共用(会改动现有架构);发布渠道及可能的费用(如开发者账号、应用商店)。

**Evidence.**
- 构成:`Sources/TatakikunBridge`(Composer 的 C 接口 ttk_*,返回 JSON)编进 libTatakikunEngine.so(Swift SDK for Android 6.3.3);`android/` 是 Kotlin 的 InputMethodService + 键盘视图,C 写的 JNI 胶水;三个语言包放在 APK 里,首次启动复制到应用目录后由引擎内存映射;学习数据(history.tsv、custom-words.tsv)在应用目录。
- APK(debug,arm64-v8a):89.9 MB,其中语言包 70 MB(不压缩存放,复制更快),引擎和 Swift 运行库约 17 MB。最低 Android 9(API 28)。
- 在模拟器 Pixel 7(Android 14,arm64)上验证:`scripts/test-android.sh` 9 项全部通过——woaini→我爱你、nihao→你好、watashi→私、hello→hello 加空格、sute-tasu→ステータス、niyongguolema→你用过了吗、nihao 后 , → 你好，、woaini 回车→woaini(原始字母)、ai → 选第 2 个 愛,再打 ai 时 愛 排第一(学习)。这些是按键事件(和实体键盘同一路径)。
- 屏幕键盘:点 n i h a o 出现 你好 你号 妳好 にはお…(和 Mac 一致),点第一个候选上屏 你好;键入时字母以带下划线的组字文字显示。
- 和 Mac 的结果一致:同一 Composer、同一语言包;例如 nh、arigatou 的候选与 macOS 的 tatakikun-cli 相同(nh → 女孩 排第一是语言包的问题,另开 A02-easel451)。
- 修过的问题:Swift 生成的 .so 没有 SONAME,链接时记下了 Mac 上的路径(CMake 设 IMPORTED_NO_SONAME);首次在主线程复制语言包会卡顿(改为后台线程加载,加载完之前按键像普通键盘)。
- 没做/没验证:真机安装和使用(需要你的手机);发布渠道(你之后自己分发);x86_64 模拟器;release 签名。
