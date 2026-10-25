# Tatakikun

[English](README.md) | [简体中文](README.zh-CN.md) | **日本語**

英字で入力した文字列を、英単語・中国語のピンイン・日本語のローマ字として同時に解釈する macOS 用
入力メソッドです。英語・中国語・ひらがな・カタカナ・日本語の漢字の候補を、1 本の横長の候補バーに
並べて表示します。入力したままの英字列も、常に候補のひとつとして表示されます。

![「ai」と入力したときの候補バー](docs/images/bar.png)

![展開すると候補が複数行になり、スクロールできます](docs/images/expanded.png)

## ビルドとインストール

**インストーラ。** `scripts/make-installer.sh` で `build/Tatakikun-<バージョン>.pkg` を作ります(Apple シリコンと Intel の Mac に対応)。開いて **カスタマイズ** 画面で使う言語パック(中国語・日本語・英語・スペイン語・フランス語・ヒンディー語・ベンガル語、既定ではすべて)にチェックを入れます。現在のユーザだけにインストールされ、管理者パスワードは不要です。あとで言語を変えるときはインストーラをもう一度実行します。チェックを外した言語パックは削除されます。

このパッケージには Apple の Developer ID 署名がありません。自分の Mac で作ったものはそのまま開けます。ダウンロードしたものは初回にブロックされるので、システム設定 → プライバシーとセキュリティ で **このまま開く** をクリックしてください。

**ソースフォルダから**(インストーラなし):

```sh
scripts/build.sh            # アプリと言語パックを作る(初回はオープンデータを約 80 MB ダウンロード)
scripts/install.sh          # すべての言語パック。一部だけなら例えば scripts/install.sh zh,en
```

そのあと一度だけ追加します:システム設定 → キーボード → テキスト入力 → 入力ソース → 編集… → + → 中国語(簡体字)→ Tatakikun。一覧にないときはログアウトしてログインし直してください。

どちらの方法でも、ログイン時に Tatakikun を起動するログイン項目が追加されます(macOS は入力方式をテキスト欄から求められて初めて起動しますが、ログイン直後はその要求が失われ、ウインドウを切り替えるまで入力できなかったためです)。システム設定 → 一般 → ログイン項目と機能拡張 → バックグラウンドでの実行を許可 で切れます。

インストールせずに試す:`TATAKIKUN_PACKS=build/packs .build/release/Tatakikun --demo`。

## キー操作

| キー | 入力中 |
| --- | --- |
| 英字 | 入力に追加 |
| スペース | 選択中の候補を確定(動かしていなければ先頭の候補)。英単語のあとには半角スペースも入ります(続けて `,` `.` などを打つとそのスペースと置き換わります) |
| return | 入力した英字をそのまま確定 |
| 1–9 | 選択中の行のその番号の候補を確定 |
| ← → | 選択を移動 |
| ↓ または Tab | 候補バーを下に展開して複数行に(展開後は 1 行下へ移動)。行はスクロールできます |
| ↑ | 1 行上へ移動。先頭の行では折りたたむ |
| delete | 最後の 1 文字を削除 |
| esc | 展開中なら折りたたみ、そうでなければ入力を取り消し |
| クリック | クリックした候補を確定 |
| 句読点・記号 | 選択中の候補を確定してから、その記号を入力。中国語・日本語の候補のあとは全角(`，` `。` / `、` `。` `「」`)、英語の候補のあとは半角 |
| 母音の前の n | 両方の読みで引く。`unei` で 運営(うんえい)も うねい も出る。`renai` → 恋愛。`unnei` でもよい |
| ローマ字の後の - | 長音記号 ー(ほかの日本語入力と同じ。`sute-tasu` → ステータス、`ko-hi-` → コーヒー) |

入力中でないときの句読点とスペースは、カーソルの前の文字に合わせます。中国語・日本語のあとは全角(`，` `、` と全角スペース)、英語のあとは半角です。

## 候補の並び順

候補バーはコスト(その語がどれだけよく使われるか)の順に並びます。そのうえで次の 2 点を保証します。
一致した言語(EN 英語、中 中国語、日 日本語の漢字、あ ひらがな、ア カタカナ)それぞれの最良の候補は
必ず候補バーに入ります。入力したままの英字も必ず入ります。それ自体が英単語なら他の英単語と同じように
並び、そうでなければ最後に置かれます。

展開した行には部分一致の候補も入ります(グレーで表示)。入力の続きを補う語(`zhongg` → 中国、
`compu` → computer、`arigat` → ありがとう)、英語のスペル候補、そして入力の先頭部分だけに当たる語
(`nihaoma` → 你好)です。後者を選ぶとその語が確定され、残りの英字(`ma`)はそのまま入力を続けられます。
入力全体に一致する候補がまだないときは、候補バー自体に最良の部分一致が表示されます。

Tatakikun は学習します。選んだ候補は、次に同じ英字を入力したときに上位に表示されます。何回かに分けて
選んだ、または先頭以外の候補を選んだ 2〜4 文字の中国語・日本語の結果は、新しい単語になります。次に同じ英字を
入力すると、ひとつの候補として先頭に表示されます。学習内容はこの Mac の `~/Library/Application Support/Tatakikun/`
の `history.tsv` と `custom-words.tsv` にだけ保存され、これらのファイルを削除すると消去できます。

## 辞書

言語ごとに **言語パック** があり、`~/Library/Application Support/Tatakikun/Packs/<zh|ja|en>` にインストールされます。パックのない言語は候補を出しません(入力した英字そのものは常に候補に出ます)。

| パック | データ | ライセンス |
| --- | --- | --- |
| 中国語 | [pinyin-data](https://github.com/mozillazg/pinyin-data)(全漢字のすべての読み)、[phrase-pinyin-data](https://github.com/mozillazg/phrase-pinyin-data)(約 40 万語の読み)、ICU と [jieba](https://github.com/fxsjy/jieba) の頻度 | MIT、Unicode License V3 |
| 日本語 | [Mozc オープンソース辞書](https://github.com/google/mozc/tree/master/src/data/dictionary_oss)(約 100 万語と読み)、ICU の語彙と頻度 | IPAdic ほか(README 参照)、Unicode License V3 |
| 英語 | [SCOWL](http://wordlist.aspell.net/)、そのサイズレベルを頻度として使用 | SCOWL の寛容なライセンス |
| スペイン語 | [Mozilla Common Voice](https://github.com/common-voice/common-voice) の文の単語と出現回数、アクセントなしで入力(cancion → canción) | CC0 1.0 |
| フランス語 | 同じく Common Voice のフランス語の文から(ecole → école、coeur → cœur、cest → c'est) | CC0 1.0 |
| ヒンディー語 | Common Voice のヒンディー語の文の単語と頻度、音のとおりに入力:文字の表から作った綴りと [AI4Bharat Aksharantar](https://huggingface.co/datasets/ai4bharat/Aksharantar) の実際の綴り(namaste → नमस्ते、kya → क्या) | CC0 1.0、CC BY 4.0 |
| ベンガル語 | 同じく Common Voice のベンガル語の文と Aksharantar から(ami → আমি、kemon → কেমন) | CC0 1.0、CC BY 4.0 |

`scripts/fetch-sources.sh` がデータをバージョン固定でダウンロードし SHA-256 を検証します。`scripts/build-packs.sh` が `build/packs` に言語パックを作り、それぞれにデータの LICENSE.txt を付けます。ICU の部分はこの Mac(`/usr/share/icu`)から:`tatakikun-dictgen` がその中日語彙を `build/dict` に読み込みます。辞書はメモリマップされる `.ttkd` ファイルなので、大きくてもすぐに起動します。データも言語パックもこのリポジトリには含まれません。

## iPhone と iPad(プレビュー)

`iOS/` には Tatakikun キーボード付きの iOS アプリがあります(iOS 16 以降)。同じエンジンと言語パックで、
QWERTY キーボードの上に候補バーがあります。候補をタップ、またはスペースで先頭の候補を確定。return は
入力した文字のまま確定、⌄ で候補を広げます。`，` `。` は Mac と同じく言語に合わせて変わります。

```sh
scripts/build-ios.sh        # シミュレータ用にビルド(build/packs が必要。プロジェクトの再生成には XcodeGen)
scripts/build-ios.sh test   # UI テストも実行
```

Xcode で `iOS/Tatakikun.xcodeproj` を開くと自分の iPhone で動かせます(Apple ID で署名)。そのあと
設定 → 一般 → キーボード → キーボード → 新しいキーボードを追加… → Tatakikun で有効にします。アプリには
有効にしなくてもキーボードを試せる画面もあります。App Store にはまだありません。

## Android(プレビュー)

`android/` には Tatakikun キーボード付きの Android アプリがあります(Android 9 以降、arm64 の端末)。
エンジンは Mac と同じで、Swift SDK for Android でビルドし JNI から呼び出します。QWERTY キーボードの上に
候補バーがあり、言語パックはアプリに含まれます。ハードウェアキーボードにも対応します。

```sh
scripts/build-android-app.sh            # android/app/build/outputs/apk/debug/app-debug.apk を作る
scripts/build-android-app.sh install    # 接続した端末か起動中のエミュレータにインストールする
scripts/test-android.sh                 # エミュレータでいくつか入力して結果を確かめる
```

ビルドには Android SDK と NDK(Android Studio)、互いに対応する Swift ツールチェーンと Swift SDK for
Android が必要です(`scripts/build-android.sh` を参照)。端末では Tatakikun を開き → Open settings →
Tatakikun をオンにし、Choose keyboard → Tatakikun を選びます。

## 開発

- `swift test` — エンジン・キー操作・言語パックのテスト(`build/dict` と `build/packs` が必要:先に `scripts/build.sh` を実行)。
- `swift run -c release tatakikun-cli --packs build/packs nihao ai toukyou` — 候補を表示。
- `.build/release/Tatakikun --snapshot <英字> out.png [dark]` — 候補バーを画像に描画。

## ライセンス

MIT。[LICENSE](LICENSE) を参照してください。言語パックはこのリポジトリに含まれず、それぞれ元データのライセンスを同梱しています(上の「辞書」を参照)。
