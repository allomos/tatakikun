#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Character-class helpers and kana conversions shared by the engine and the dictionary generator.
public enum Kana {
    public static func isHiragana(_ s: Unicode.Scalar) -> Bool { (0x3041...0x3096).contains(s.value) || s.value == 0x30FC }
    public static func isKatakana(_ s: Unicode.Scalar) -> Bool { (0x30A1...0x30FA).contains(s.value) || s.value == 0x30FC }
    public static func isHan(_ s: Unicode.Scalar) -> Bool {
        (0x4E00...0x9FFF).contains(s.value) || (0x3400...0x4DBF).contains(s.value) || s.value == 0x3005 || s.value == 0x3007
    }

    public static func toKatakana(_ hiragana: String) -> String {
        String(String.UnicodeScalarView(hiragana.unicodeScalars.map { s in
            (0x3041...0x3096).contains(s.value) ? Unicode.Scalar(s.value + 0x60)! : s
        }))
    }

    public static func toHiragana(_ katakana: String) -> String {
        String(String.UnicodeScalarView(katakana.unicodeScalars.map { s in
            (0x30A1...0x30F6).contains(s.value) ? Unicode.Scalar(s.value - 0x60)! : s
        }))
    }
}
