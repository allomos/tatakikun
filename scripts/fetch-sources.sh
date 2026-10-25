#!/bin/sh
# Downloads the open dictionary data the language packs are built from, into build/sources.
# Every file is pinned to a version and checked against its SHA-256; nothing else is fetched.
#   zh: pinyin-data, phrase-pinyin-data (MIT, mozillazg); jieba word frequencies (MIT, Sun Junyi)
#   ja: Mozc OSS dictionary (IPAdic license and others; see its README), Mozc's single kanji readings (BSD)
#   en: SCOWL 2020.12.07 (permissive, Kevin Atkinson)
#   es: Mozilla Common Voice sentence text (CC0), for words and how often each is used
#   all: the ICU license (the packs also use word frequencies from this Mac's ICU data)
set -e
cd "$(dirname "$0")/.."
OUT=build/sources

PINYIN=https://raw.githubusercontent.com/mozillazg/pinyin-data/9e5e9bdfe8add694300e0cc93a27b803b68377f9
PHRASE=https://raw.githubusercontent.com/mozillazg/phrase-pinyin-data/cee0ed6e6e4898580cafd2bd5e3723e20b214aa0
JIEBA=https://raw.githubusercontent.com/fxsjy/jieba/1e20c89b66f56c9301b0feed211733ffaa1bd72a
MOZC_SUMS="9e07ce292932c4fff327ed8cb06274c09acca556bd8bdf7c7ef1f6173eae3b61 836fd5fd8399510de0d8ef7b33be913cca6bbaee7b712cc8045fba03f4c75a89 93943858d0cfd092b849a78def6901eaf228177e1ac5663544e865a3a1e45a9e cb9f1b0b4a7550d682d86244a021cd17e0b15366328819e69135b5f183a1a24b 9fdc4e3948d03463de13ab5782adffbc11dd06e934cb80138c5920029cd3d2f6 199e3b0f050b691823ae7ba943090d437f51af6436b27c5f3dc69cafa12000e4 b95b14f7770ae2a824bc8e9fad8b03c1bc45c504f93a36554b8b56daa0368d2a 7f53649b529d4c8c495d3a8dd9c4d489dfe7696080f7423107ff01331174be48 50a31bb5fc1646721b00be371a5695dffab1292bda143e1e59cc70cbbdd8643f 4e5fcd4cbfbf11395166a37b506f547fc54d20edc0884f5184ecd3fc705f0d9a"
MOZC=https://raw.githubusercontent.com/google/mozc/0136c35782536cb43d710575c311cd4185982738/src/data/dictionary_oss
MOZC_SRC=https://raw.githubusercontent.com/google/mozc/0136c35782536cb43d710575c311cd4185982738/src
ICU_LICENSE=https://raw.githubusercontent.com/unicode-org/icu/ad484f3d6c036ba06193ac7c3bc2233a53ab68b8/LICENSE
SCOWL=https://downloads.sourceforge.net/project/wordlist/SCOWL/2020.12.07/scowl-2020.12.07.tar.gz
VOICE=https://raw.githubusercontent.com/common-voice/common-voice/f96d1c370a2b96ddf52c2eb108959b626757ba20/server/data
VOICE_LICENSE=bf474cdfd02e162603358e4e3615182018cad27593d2bf5e75ca13e4a5a6af0c

# fetch <url> <file> <sha256>
fetch() {
    mkdir -p "$(dirname "$2")"
    if [ -f "$2" ] && [ "$(shasum -a 256 "$2" | cut -d' ' -f1)" = "$3" ]; then return; fi
    echo "Downloading $1"
    curl -sSfL -o "$2.part" "$1"
    sum=$(shasum -a 256 "$2.part" | cut -d' ' -f1)
    if [ "$sum" != "$3" ]; then
        echo "Checksum mismatch for $1: got $sum, expected $3" >&2
        rm -f "$2.part"
        exit 1
    fi
    mv "$2.part" "$2"
}

LANGS=${1:-zh,ja,en,es}
fetch $ICU_LICENSE $OUT/icu-LICENSE e09827667e0bb3c808b2a463548ba814a5e6249b67353234d70c8dfc2bcc417d
case ",$LANGS," in *,zh,*)
    fetch $PINYIN/pinyin.txt $OUT/zh/pinyin.txt 7365b877d2a60f64d13de522ad882ce928c7b60c4c5d26fe3c89783e72ab1115
    fetch $PINYIN/LICENSE $OUT/zh/pinyin-data-LICENSE 9c048697be2502a16e8bcb282d5d465a07295b2def0ffb05a269c5d39dbe1586
    fetch $PHRASE/large_pinyin.txt $OUT/zh/large_pinyin.txt 4cf565635a092f3911a7f560fc604aa1a05c95a121488fb28562f3dd2d1441f7
    fetch $PHRASE/LICENSE $OUT/zh/phrase-pinyin-data-LICENSE 89ac55df747e4776088c3e77531ef61b973a1a59dd8e6a4548a58996da9a4f70
    fetch $JIEBA/jieba/dict.txt $OUT/zh/jieba-dict.txt 7197c3211ddd98962b036cdf40324d1ea2bfaa12bd028e68faa70111a88e12a8
    fetch $JIEBA/LICENSE $OUT/zh/jieba-LICENSE 18ba0984839f85853b29fadaf992f7dba8fd0ca0fbeae34de2b8735222dc7a37
esac
case ",$LANGS," in *,ja,*)
    fetch $MOZC/README.txt $OUT/ja/README.txt 6b1de66bc6fa30e0b45dc45b8c8f6c57bd78aff923c261a3efffac8eb86f7bac
    fetch $MOZC_SRC/data/single_kanji/single_kanji.tsv $OUT/ja/single_kanji.tsv bfa6a4be1319a144f770ba281dfc04091a05320e334357f949b293dc5f9c3d0c
    fetch $MOZC_SRC/../LICENSE $OUT/ja/mozc-LICENSE 44cdd923b91ea9199293abecc2762c70c87dbf1e581c027a94c416368d1a648c
    i=0
    for sum in $MOZC_SUMS; do
        fetch $MOZC/dictionary0$i.txt $OUT/ja/dictionary0$i.txt $sum
        i=$((i + 1))
    done
esac
case ",$LANGS," in *,en,*)
    fetch $SCOWL $OUT/en/scowl.tar.gz 5587667caa20c4891390c2d42dbb4d5c4c3f41bee77af1457ece3ba23fb859cc
    if [ ! -d $OUT/en/scowl ]; then
        mkdir -p $OUT/en/scowl
        tar -xzf $OUT/en/scowl.tar.gz -C $OUT/en/scowl --strip-components 1 scowl-2020.12.07/final scowl-2020.12.07/Copyright
    fi
esac
case ",$LANGS," in *,es,*)
    fetch $VOICE/LICENSE $OUT/es/common-voice-LICENSE $VOICE_LICENSE
    fetch $VOICE/es/wiki.es.txt $OUT/es/wiki.es.txt 26dfe9d9993cf7279ebf7cdffb2b086b4995982200415110903ba5530d1fc47d
    fetch $VOICE/es/sentence-collector.txt $OUT/es/sentence-collector.txt 0a125f0d1cd892c5d727abb8006f5fb964ef9fe1e41bdf4afd3c4b845c47286b
esac
echo "Sources ready in $OUT"
