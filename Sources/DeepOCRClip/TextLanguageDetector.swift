import Foundation

enum TextLanguageDetector {
    static func containsForeignLetters(in text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            scalar.properties.isAlphabetic && !isHan(scalar)
        }
    }

    private static func isHan(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x3400...0x4DBF,
             0x4E00...0x9FFF,
             0xF900...0xFAFF,
             0x20000...0x2A6DF,
             0x2A700...0x2B73F,
             0x2B740...0x2B81F,
             0x2B820...0x2CEAF,
             0x2CEB0...0x2EBEF,
             0x30000...0x3134F:
            return true
        default:
            return false
        }
    }
}
